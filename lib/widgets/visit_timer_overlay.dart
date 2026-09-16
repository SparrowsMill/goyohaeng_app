import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/visit_verification_overlay.dart';
import '../navigation/root_navigator.dart';
import '../screens/place/visit_fail_screen.dart';
import '../screens/place/visit_reward_screen.dart';
import '../screens/place/visit_verification_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// 방문 인증 타이머가 진행 중인 동안 `<방문 인증 확인 페이지>`를 벗어나도(탭
/// 전환 등) 앱 전역에 작은 떠 있는 타이머 배지를 계속 보여준다.
/// `main.dart`에서 `MaterialApp.builder`로 한 번만 wiring — 이 레벨은 앱의
/// `Navigator`보다 바깥이라 탭을 얼마든지 옮겨 다녀도 항상 최상단에 그려진다.
class VisitTimerOverlay extends StatelessWidget {
  const VisitTimerOverlay({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ?child,
        AnimatedBuilder(
          animation: VisitVerificationOverlay.instance,
          builder: (context, _) {
            final overlay = VisitVerificationOverlay.instance;
            if (!overlay.hasActive || overlay.screenOpen) {
              return const SizedBox.shrink();
            }
            return _TimerBadge(overlay: overlay);
          },
        ),
      ],
    );
  }
}

class _TimerBadge extends StatefulWidget {
  const _TimerBadge({required this.overlay});

  final VisitVerificationOverlay overlay;

  @override
  State<_TimerBadge> createState() => _TimerBadgeState();
}

/// 배지를 드래그로 옮긴 위치. 배지가 사라졌다 다시 뜨는 동안(다른 화면 갔다가
/// 방문 인증 시도가 다시 활성화되는 경우 등)에도 같은 세션 안에서는 마지막
/// 위치를 기억하도록 State 밖(정적)에 둔다.
Offset? _savedBadgePosition;

class _TimerBadgeState extends State<_TimerBadge> {
  final _boxKey = GlobalKey();

  Offset? _position;
  Size _size = const Size(140, 44);

  // 드래그 시작 시점의 포인터 위치/배지 위치 — GestureDetector의
  // onPanUpdate(내부적으로 PanGestureRecognizer가 kTouchSlop만큼 움직여야
  // 인식을 시작함, InkWell의 Tap 인식기와 같은 제스처 아레나에서 경합)
  // 대신 Listener로 포인터를 직접 추적해 첫 픽셀부터 지연 없이 그대로
  // 따라오게 한다. Listener는 제스처 아레나에 참여하지 않아 하위 InkWell의
  // 탭 인식과 충돌하지 않는다 — 실제로 드래그된 경우 InkWell 자체의 슬롭
  // 판정으로 탭이 자동으로 취소된다.
  Offset? _dragPointerOrigin;
  Offset? _dragBadgeOrigin;

  VisitVerificationOverlay get overlay => widget.overlay;

  void _measureAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox =
          _boxKey.currentContext?.findRenderObject() as RenderBox?;
      final measured = renderBox?.size;
      if (measured != null && measured != _size) {
        setState(() => _size = measured);
      }
    });
  }

  Offset _clamp(Offset position, Size screenSize, double safeTop, double safeBottom) {
    const margin = 8.0;
    final minX = margin;
    final maxX = (screenSize.width - _size.width - margin).clamp(minX, double.infinity);
    final minY = safeTop + margin;
    final maxY = (screenSize.height - safeBottom - _size.height - margin)
        .clamp(minY, double.infinity);
    return Offset(
      position.dx.clamp(minX, maxX),
      position.dy.clamp(minY, maxY),
    );
  }

  String get _label {
    switch (overlay.status) {
      case VisitOverlayStatus.verified:
        return '인증 완료!';
      case VisitOverlayStatus.expired:
        return '인증 만료';
      case VisitOverlayStatus.failed:
        return '인증 실패';
      case VisitOverlayStatus.pending:
        final remaining = overlay.remaining;
        final m = remaining.inMinutes.toString().padLeft(2, '0');
        final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
        return '$m:$s';
    }
  }

  IconData get _icon {
    switch (overlay.status) {
      case VisitOverlayStatus.verified:
        return Symbols.celebration_rounded;
      case VisitOverlayStatus.expired:
      case VisitOverlayStatus.failed:
        return Symbols.error_rounded;
      case VisitOverlayStatus.pending:
        return Symbols.schedule_rounded;
    }
  }

  Color get _tone {
    switch (overlay.status) {
      case VisitOverlayStatus.verified:
        return AppColors.success;
      case VisitOverlayStatus.expired:
      case VisitOverlayStatus.failed:
        return AppColors.error;
      case VisitOverlayStatus.pending:
        return AppColors.secondaryAccent;
    }
  }

  void _open(BuildContext context) {
    final spot = overlay.spot;
    final nav = rootNavigatorKey.currentState;
    if (spot == null || nav == null) return;

    switch (overlay.status) {
      case VisitOverlayStatus.verified:
        final session = overlay.session;
        final benefit = overlay.benefit;
        final reward = overlay.reward;
        overlay.clear();
        nav.push(
          MaterialPageRoute(
            builder: (_) => VisitRewardScreen(
              spot: spot,
              placeId: session?.placeId,
              visitVerificationId: session?.id,
              benefit: benefit,
              reward: reward,
            ),
          ),
        );
        break;
      case VisitOverlayStatus.expired:
      case VisitOverlayStatus.failed:
        final window = overlay.window;
        final status = overlay.status == VisitOverlayStatus.failed
            ? 'FAILED'
            : 'EXPIRED';
        final failReason = overlay.failReason;
        overlay.clear();
        nav.push(
          MaterialPageRoute(
            builder: (_) => VisitFailScreen(
              spot: spot,
              window: window,
              status: status,
              failReason: failReason,
            ),
          ),
        );
        break;
      case VisitOverlayStatus.pending:
        nav.push(
          MaterialPageRoute(
            builder: (_) => VisitVerificationScreen(
              spot: spot,
              window: overlay.window,
              session: overlay.session,
              benefit: overlay.benefit,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    _measureAfterFrame();

    final mq = MediaQuery.of(context);
    final screenSize = mq.size;
    final safeTop = mq.viewPadding.top;
    final safeBottom = mq.viewPadding.bottom;

    final defaultPosition = Offset(
      screenSize.width - AppSpacing.lg - _size.width,
      screenSize.height -
          ((safeBottom > 12 ? safeBottom : 12) + 96) -
          _size.height,
    );
    final current = _clamp(
      _position ?? _savedBadgePosition ?? defaultPosition,
      screenSize,
      safeTop,
      safeBottom,
    );

    return Positioned(
      left: current.dx,
      top: current.dy,
      child: Listener(
        onPointerDown: (event) {
          _dragPointerOrigin = event.position;
          _dragBadgeOrigin = current;
        },
        onPointerMove: (event) {
          final pointerOrigin = _dragPointerOrigin;
          final badgeOrigin = _dragBadgeOrigin;
          if (pointerOrigin == null || badgeOrigin == null) return;
          setState(() {
            _position = _clamp(
              badgeOrigin + (event.position - pointerOrigin),
              screenSize,
              safeTop,
              safeBottom,
            );
            _savedBadgePosition = _position;
          });
        },
        onPointerUp: (_) {
          _dragPointerOrigin = null;
          _dragBadgeOrigin = null;
        },
        onPointerCancel: (_) {
          _dragPointerOrigin = null;
          _dragBadgeOrigin = null;
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => _open(context),
            child: Container(
              key: _boxKey,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: _tone),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: AppShadows.elevatedCard,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon, size: 18, color: _tone),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _tone,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
