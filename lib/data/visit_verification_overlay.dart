import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../api/api.dart';
import 'makeable_food_watcher.dart';
import 'mock_region_ranking.dart';

/// 진행 중인 방문 인증 시도의 최종/중간 상태.
enum VisitOverlayStatus { pending, verified, expired, failed }

/// 진행 중인 방문 인증 시도를 앱 전역에서 소유한다 — `<방문 인증 확인 페이지>`
/// (`VisitVerificationScreen`)가 화면에서 사라져도(탭 전환으로 dispose돼도)
/// 카운트다운/폴링이 여기서 계속 돌아가고, `VisitTimerOverlay`
/// (`lib/widgets/visit_timer_overlay.dart`, `main.dart`에 wiring)가 이 상태를
/// 구독해 작은 떠 있는 타이머 배지로 계속 보여준다.
///
/// 한 번에 하나의 시도만 추적한다 — 물리적으로 한 곳만 방문 인증 중일 수
/// 있으므로 동시에 여러 장소를 추적할 필요가 없다.
class VisitVerificationOverlay extends ChangeNotifier {
  VisitVerificationOverlay._();
  static final VisitVerificationOverlay instance =
      VisitVerificationOverlay._();

  final _service = VisitVerificationService();

  MockTouristSpot? _spot;
  VisitVerification? _session;
  String? _benefit;
  Duration _window = const Duration(minutes: 15);
  String _code = '';
  DateTime _expiresAt = DateTime.now();
  VisitOverlayStatus _status = VisitOverlayStatus.pending;
  String? _failReason;
  Timer? _ticker;
  Timer? _poll;

  /// `<방문 인증 확인 페이지>`가 현재 화면에 떠 있는 동안 true — 그동안은
  /// 오버레이 배지를 숨긴다(화면 자체에 이미 큰 타이머가 보이므로).
  bool screenOpen = false;

  MockTouristSpot? get spot => _spot;
  VisitVerification? get session => _session;
  String? get benefit => _benefit;

  /// `VERIFIED` 상태에서 서버가 즉시 함께 내려주는 실제 지급 재료(스펙 §8.2).
  VisitVerificationReward? get reward => _session?.reward;
  Duration get window => _window;
  String get code => _code;
  VisitOverlayStatus get status => _status;
  String? get failReason => _failReason;

  /// `session`이 있으면(서버 발급 세션) 백엔드 연동 경로, null이면 목업 경로.
  bool get live => _session != null;

  bool get hasActive => _spot != null;

  Duration get remaining {
    final left = _expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// `<방문 인증 확인 페이지>` 진입 시 호출. 같은 시도(같은 스팟 + 같은 세션)가
  /// 이미 진행 중이면 그대로 재사용하고(재진입), 아니면 새로 시작한다.
  void start({
    required MockTouristSpot spot,
    VisitVerification? session,
    String? benefit,
    Duration window = const Duration(minutes: 15),
  }) {
    final sameAttempt =
        _spot?.name == spot.name &&
        _status == VisitOverlayStatus.pending &&
        session?.id == _session?.id;
    if (sameAttempt) return;

    _stopTimers();

    final now = DateTime.now();
    _spot = spot;
    _session = session;
    _benefit = benefit;
    _window = window;
    _status = VisitOverlayStatus.pending;
    _failReason = null;

    if (session != null) {
      _code = session.verificationCode;
      _expiresAt = session.expiresAt ?? now.add(window);
    } else {
      _code = (100000 + Random().nextInt(900000)).toString();
      _expiresAt = now.add(window);
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining == Duration.zero &&
          _status == VisitOverlayStatus.pending) {
        _status = VisitOverlayStatus.expired;
        _stopTimers();
      }
      notifyListeners();
    });

    if (session != null) {
      _poll = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _pollStatus(),
      );
    }

    notifyListeners();
  }

  Future<void> _pollStatus() async {
    final session = _session;
    if (session == null || _status != VisitOverlayStatus.pending) return;
    try {
      final latest = await _service.get(session.id);
      _applyLatest(latest);
    } on ApiException {
      // 일시적 네트워크 오류는 다음 폴링에서 재시도.
    }
  }

  void _applyLatest(VisitVerification latest) {
    _session = latest;
    if (latest.isVerified) {
      _status = VisitOverlayStatus.verified;
      _stopTimers();
      DashboardStore.instance.refresh();
      MakeableFoodWatcher.instance.check();
    } else if (latest.isFailed) {
      _status = VisitOverlayStatus.failed;
      _failReason = latest.failReason;
      _stopTimers();
    } else if (latest.isExpired) {
      _status = VisitOverlayStatus.expired;
      _failReason = latest.failReason;
      _stopTimers();
    }
    notifyListeners();
  }

  /// "인증 상태 확인" 버튼 — 매장 관리자가 이미 승인/반려했는지 즉시 다시
  /// 조회한다. 아직 대기 중이면 안내 메시지를 반환하고, 상태가 바뀌었으면
  /// null을 반환한다(리스너가 알아서 새 상태를 읽는다).
  Future<String?> checkNow() async {
    final session = _session;
    if (session == null || _status != VisitOverlayStatus.pending) return null;
    try {
      final latest = await _service.get(session.id);
      if (latest.isVerified || latest.isExpired || latest.isFailed) {
        _applyLatest(latest);
        return null;
      }
      return '아직 매장 직원 확인 전이에요.';
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// "신청 취소" — 대기 중(`ISSUED`)인 인증만 취소 가능. 성공하면 오버레이를
  /// 완전히 지우고 null을 반환한다.
  Future<String?> cancel() async {
    final session = _session;
    if (session == null) return null;
    try {
      await _service.cancel(session.id);
      clear();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// QA 전용(목업 경로) — 실제 대기 없이 성공/실패로 강제 전환한다.
  void forceStatus(VisitOverlayStatus status) {
    _status = status;
    _stopTimers();
    if (status == VisitOverlayStatus.verified) {
      DashboardStore.instance.refresh();
    }
    notifyListeners();
  }

  void _stopTimers() {
    _ticker?.cancel();
    _poll?.cancel();
  }

  /// 성공/실패 화면으로 넘어갔거나 취소됐을 때 호출 — 오버레이를 완전히
  /// 지운다. 그때까지는 `<방문 인증 확인 페이지>`가 없어도 배지가 계속 보인다.
  void clear() {
    _stopTimers();
    _spot = null;
    _session = null;
    _benefit = null;
    _status = VisitOverlayStatus.pending;
    _failReason = null;
    screenOpen = false;
    notifyListeners();
  }
}
