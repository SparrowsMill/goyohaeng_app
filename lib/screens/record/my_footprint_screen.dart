import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/loading_overlay.dart';
import 'footprint_write_screen.dart';

/// `<기록 플랫폼>` "나의 발자국" (user_flow §8) — 하단 네비게이션 기록 탭 화면.
/// 날짜별 여행 기록을 최근순으로 보여준다. 상단에 기록이 있는 날을 발자국으로
/// 표시하는 달력, 그 아래로 날짜별 기록 카드(사진 캐러셀 + 짧은 글). 우하단
/// 연필 버튼으로 새 `<기록 플랫폼 글쓰기>`(`FootprintWriteScreen`), 기록을
/// 누르면(또는 "⋯" 메뉴) 같은 화면을 수정 모드로 연다.
///
/// `RecordService`(`GET /records`, `GET /records/calendar`, `DELETE /records/
/// {id}`)로 실제 백엔드와 연동한다 — 목록은 최근순으로 [_pageLimit]건씩
/// 점진 로드(스크롤이 바닥에 가까워지면 다음 페이지 요청)하며, 한 번에
/// 전체를 끌어오지 않는다. 달력은 표시 중인 달만 별도 조회한다. 특정 날짜를
/// 고르면 아직 로드되지 않은 과거 기록을 찾기 위해 추가 페이지를 더 불러올
/// 수 있다(`_ensureDayLoaded`). 로그인하지 않은 상태면 안내만 보여준다.
class MyFootprintScreen extends StatefulWidget {
  const MyFootprintScreen({super.key});

  @override
  State<MyFootprintScreen> createState() => _MyFootprintScreenState();
}

class _MyFootprintScreenState extends State<MyFootprintScreen> {
  /// 한 번에 불러오는 기록 수 — 전체를 한 번에 끌어오지 않고 이 단위로
  /// 점진 로드한다.
  static const _pageLimit = 30;

  /// 특정 날짜를 골랐을 때 아직 로드되지 않은 과거 기록을 찾기 위해 추가로
  /// 불러올 수 있는 최대 페이지 수(안전장치).
  static const _maxLookupPages = 20;

  bool _loading = true;
  String? _error;
  List<RecordDetail> _entries = [];
  int _loadedPage = 1;
  bool _hasMoreEntries = false;
  bool _loadingMore = false;
  RecordCalendar? _calendar;
  DateTime? _selectedDay;

  /// "전체 기록"(`_selectedDay == null`) 모드의 조회 기간 — 화면 목업.
  /// 프리셋을 고르면 [_periodPreset]이 채워지고, 날짜를 직접 입력하면 null
  /// (직접 설정)이 된다. 여기서 고르는 값은 "입력 중인 기간"일 뿐이고, 결과는
  /// "적용"을 눌러 [_appliedStart]/[_appliedEnd]로 확정해야 나온다.
  _PeriodPreset? _periodPreset = _PeriodPreset.month;
  late DateTime _periodStart = _PeriodPreset.month.startFrom(
    DateUtils.dateOnly(DateTime.now()),
  );
  DateTime _periodEnd = DateUtils.dateOnly(DateTime.now());

  /// "적용"으로 확정된 조회 기간. null이면 아직 적용 전이라 안내 문구만
  /// 보여준다. 지금은 이미 로드된 기록만 이 기간으로 걸러 보여주며, 서버에
  /// `from`/`to`가 생기면 [_applyPeriod]에서 이 값으로 요청하면 된다.
  DateTime? _appliedStart;
  DateTime? _appliedEnd;

  /// 시작일/종료일 칸이 채워지다 만 상태이거나 오류가 있는지 — 참이면 "적용"을
  /// 막는다(화면의 기간은 마지막 유효값이라 입력 중인 글자와 다를 수 있다).
  bool _startInvalid = false;
  bool _endInvalid = false;

  /// 프리셋 선택처럼 밖에서 날짜를 바꿨을 때 입력 칸 글자를 다시 맞추라는 신호.
  int _periodSyncToken = 0;
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 100;
    if (show != _showScrollToTop) setState(() => _showScrollToTop = show);
    if (_signedIn &&
        !_loading &&
        !_loadingMore &&
        _hasMoreEntries &&
        // 기간 모드에서 "적용" 전에는 목록을 보여주지 않으므로 더 불러오지 않는다.
        (_selectedDay != null || _appliedStart != null) &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < 400) {
      _loadMoreEntries();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 달력이 보여주는 달 (1일로 정규화).
  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  bool get _signedIn => AuthStore.instance.isSignedIn;

  Set<DateTime> get _entryDays {
    final cal = _calendar;
    if (cal == null) return {};
    return {
      for (final d in cal.recordDays)
        if (DateTime.tryParse(d.date) case final parsed?)
          DateTime(parsed.year, parsed.month, parsed.day),
    };
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = DateUtils.dateOnly(DateTime.now());
    _scrollController.addListener(_onScroll);
    if (_signedIn) {
      _loadAll();
    } else {
      _loading = false;
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isOn(RecordDetail entry, DateTime day) {
    final d = DateTime.tryParse(entry.date);
    return d != null &&
        d.year == day.year &&
        d.month == day.month &&
        d.day == day.day;
  }

  /// 적용된 기간([_appliedStart]~[_appliedEnd])에 드는 기록인지.
  bool _isInPeriod(RecordDetail entry) {
    final start = _appliedStart;
    final end = _appliedEnd;
    final d = DateTime.tryParse(entry.date);
    if (start == null || end == null || d == null) return false;
    final day = DateUtils.dateOnly(d);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// "전체 기록" — 달력 대신 기간 설정 카드를 보여주는 모드로 들어간다. 들어
  /// 올 때마다 적용 상태를 비워, 필터를 적용하기 전에는 안내 문구만 보이게 한다.
  void _openPeriodMode() {
    setState(() {
      _selectedDay = null;
      _appliedStart = null;
      _appliedEnd = null;
    });
    _selectPreset(_PeriodPreset.month);
  }

  /// 프리셋은 입력 칸만 채운다 — 결과는 "적용"을 눌러야 나온다.
  void _selectPreset(_PeriodPreset preset) {
    final end = DateUtils.dateOnly(DateTime.now());
    // 날짜 칸에 입력 중이었다면 키보드를 내린다.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _periodPreset = preset;
      _periodEnd = end;
      _periodStart = preset.startFrom(end);
      _startInvalid = false;
      _endInvalid = false;
      _periodSyncToken++;
    });
  }

  /// "적용" — 입력한 기간을 확정하고 그 기간의 기록을 보여준다. 서버에
  /// `from`/`to`가 생기면 여기서 [_periodStart]~[_periodEnd]로 목록을 요청한다.
  void _applyPeriod() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _appliedStart = _periodStart;
      _appliedEnd = _periodEnd;
    });
  }

  void _setDateInvalid({required bool isStart, required bool invalid}) {
    final current = isStart ? _startInvalid : _endInvalid;
    if (current == invalid) return;
    setState(() {
      if (isStart) {
        _startInvalid = invalid;
      } else {
        _endInvalid = invalid;
      }
    });
  }

  /// 텍스트로 입력된 시작일/종료일을 반영한다. 받아들였으면 null, 기간이
  /// 성립하지 않으면(오늘 이후·5년 이전·시작일과 종료일이 뒤집힘) 입력 칸에
  /// 보여줄 안내 문구를 돌려준다.
  String? _setPeriodDate({required bool isStart, required DateTime date}) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (date.isAfter(today)) return '오늘 이후는 고를 수 없어요.';
    if (date.isBefore(DateTime(today.year - 5))) {
      return '최대 5년 전까지 볼 수 있어요.';
    }
    if (isStart && date.isAfter(_periodEnd)) {
      return '시작일이 종료일보다 늦어요.';
    }
    if (!isStart && date.isBefore(_periodStart)) {
      return '종료일이 시작일보다 빨라요.';
    }
    setState(() {
      if (isStart) {
        _periodStart = date;
      } else {
        _periodEnd = date;
      }
      _periodPreset = null;
    });
    return null;
  }

  /// 기간 모드에서 다시 달력(날짜별 보기)으로 돌아간다.
  void _backToDayMode() {
    final today = DateUtils.dateOnly(DateTime.now());
    final inThisMonth =
        _visibleMonth.year == today.year && _visibleMonth.month == today.month;
    _onSelectDay(inThisMonth ? today : _visibleMonth);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await RecordService().list(page: 1, limit: _pageLimit);
      final cal = await RecordService().calendar(
        year: _visibleMonth.year,
        month: _visibleMonth.month,
      );
      if (!mounted) return;
      setState(() {
        _entries = list.records..sort((a, b) => b.date.compareTo(a.date));
        _loadedPage = 1;
        _hasMoreEntries = list.hasMore;
        _calendar = cal;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  /// 스크롤이 바닥에 가까워지면 다음 페이지를 이어붙인다.
  Future<void> _loadMoreEntries() async {
    setState(() => _loadingMore = true);
    try {
      final list = await RecordService().list(
        page: _loadedPage + 1,
        limit: _pageLimit,
      );
      if (!mounted) return;
      setState(() {
        _entries = [..._entries, ...list.records]
          ..sort((a, b) => b.date.compareTo(a.date));
        _loadedPage = list.page;
        _hasMoreEntries = list.hasMore;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _snack(e.message);
    }
  }

  /// 고른 날짜의 기록이 아직 로드된 페이지 안에 없으면, 더 오래된 페이지를
  /// 찾을 때까지(또는 안전 한도까지) 추가로 불러온다.
  Future<void> _ensureDayLoaded(DateTime day) async {
    var lookups = 0;
    while (_hasMoreEntries &&
        lookups < _maxLookupPages &&
        !_entries.any((e) => _isOn(e, day)) &&
        mounted &&
        _selectedDay == day) {
      await _loadMoreEntries();
      lookups++;
    }
  }

  Future<void> _shiftMonth(int delta) async {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _visibleMonth = next;
      _selectedDay = (next.year == today.year && next.month == today.month)
          ? today
          : DateTime(next.year, next.month);
      _calendar = null;
    });
    if (!_entries.any((e) => _isOn(e, _selectedDay!))) {
      _ensureDayLoaded(_selectedDay!);
    }
    if (!_signedIn) return;
    try {
      final cal = await RecordService().calendar(
        year: next.year,
        month: next.month,
      );
      if (!mounted) return;
      if (_visibleMonth != next) return;
      setState(() => _calendar = cal);
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    }
  }

  /// 달력 아래에 선택한 날짜의 기록을 표시한다.
  void _onSelectDay(DateTime day) {
    setState(() => _selectedDay = day);
    if (!_entries.any((e) => _isOn(e, day))) _ensureDayLoaded(day);
  }

  /// 우하단 연필 버튼 — 새 기록 작성.
  Future<void> _writeNew() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FootprintWriteScreen(initialDate: _selectedDay),
      ),
    );
    if (saved == true && mounted) _loadAll();
  }

  /// 기록을 눌러 수정 — 채워진 상태로 작성 화면을 열고, 저장되면 목록을 새로고침한다.
  Future<void> _editEntry(RecordDetail entry) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FootprintWriteScreen(
          editing: true,
          recordId: entry.id,
          initialDate: DateTime.tryParse(entry.date) ?? DateTime.now(),
          initialPlaceId: entry.place?.id,
          initialPlace: entry.place?.name,
          initialManualPlaceName: entry.manualPlaceName,
          initialTitle: entry.title,
          initialText: entry.body,
          initialImageUrls: entry.images.map((i) => i.imageUrl).toList(),
          initialUserFoodId: entry.food?.userFoodId,
          initialUserFoodName: entry.food?.name,
        ),
      ),
    );
    if (saved == true && mounted) _loadAll();
  }

  Future<void> _openEntryMenu(RecordDetail entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Symbols.edit_rounded,
                color: AppColors.iconPrimary,
              ),
              title: const Text('수정'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: const Icon(
                Symbols.delete_rounded,
                color: AppColors.error,
              ),
              title: Text('삭제', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      _editEntry(entry);
    } else if (action == 'delete') {
      _confirmDelete(entry);
    }
  }

  Future<void> _confirmDelete(RecordDetail entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 기록을 삭제할까요? 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await RecordService().delete(entry.id);
      if (!mounted) return;
      _snack('기록을 삭제했어요.');
      _loadAll();
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // "발자국 남기기"(`FootprintWriteScreen`)와 같은 diary_bg 배너 — 화면
    // 너비에 원본 비율(1587/991)을 적용한 고정 높이로 상단에 깔고, 그 아래
    // 30%를 `AppColors.appBackground`로 그라데이션 페이드해 스크롤되는
    // 콘텐츠와 자연스럽게 이어지게 한다.
    final bgHeight = MediaQuery.sizeOf(context).width / (1587 / 991);
    final fadeHeight = bgHeight * 0.3;
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('나의 발자국'),
      ),
      body: LoadingOverlay(
        loading: _loading,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Image.asset(
                'assets/illustrations/scenes/diary_bg.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox(),
              ),
            ),
            Positioned(
              top: bgHeight - fadeHeight,
              left: 0,
              right: 0,
              height: fadeHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.appBackground.withValues(alpha: 0),
                        AppColors.appBackground,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: ListView(
                controller: _scrollController,
                padding: AppBottomNavBar.scrollPadding(
                  context,
                  const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.huge,
                  ),
                ),
                children: [
                  const _Header(),
                  SizedBox(height: (bgHeight * 0.65).clamp(96.0, 200.0)),
                  ..._buildContent(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showScrollToTop) ...[
            FloatingActionButton.small(
              heroTag: 'footprint-scroll-top',
              tooltip: '맨 위로',
              onPressed: () => _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
              child: const Icon(Icons.arrow_upward_rounded),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          _WriteButton(onTap: _writeNew),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }

  /// 로그인/로딩/에러/빈 상태에 맞춰 달력 + 피드 위젯 목록을 만든다.
  List<Widget> _buildContent() {
    if (!_signedIn) {
      return const [
        _StatusMessage(
          icon: Symbols.lock_rounded,
          text: '로그인하면 나의 발자국을 볼 수 있어요.',
        ),
      ];
    }
    if (_loading) {
      // The Scaffold-level LoadingOverlay already shows the loading pill.
      return const [SizedBox(height: AppSpacing.massive)];
    }
    if (_error != null) {
      return [
        _StatusMessage(
          icon: Symbols.error_outline_rounded,
          text: _error!,
          onRetry: _loadAll,
        ),
      ];
    }
    final periodMode = _selectedDay == null;
    // 기간 모드에서 "적용"을 누르기 전에는 결과 대신 안내만 보여준다.
    final periodApplied = _appliedStart != null && _appliedEnd != null;
    if (periodMode && !periodApplied) {
      return [
        _PeriodCard(
          preset: _periodPreset,
          start: _periodStart,
          end: _periodEnd,
          syncToken: _periodSyncToken,
          canApply: !_startInvalid && !_endInvalid,
          onSelectPreset: _selectPreset,
          onChangeStart: (d) => _setPeriodDate(isStart: true, date: d),
          onChangeEnd: (d) => _setPeriodDate(isStart: false, date: d),
          onStartInvalid: (v) => _setDateInvalid(isStart: true, invalid: v),
          onEndInvalid: (v) => _setDateInvalid(isStart: false, invalid: v),
          onApply: _applyPeriod,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(child: Text('기간 내 기록', style: AppTextStyles.title)),
            _SmallOutlinedButton(label: '캘린더로 돌아가기', onPressed: _backToDayMode),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const _StatusMessage(
          icon: Symbols.filter_alt_rounded,
          text: '기간을 설정하고 "적용"을 눌러 주세요.\n선택한 기간의 기록을 보여드려요.',
        ),
      ];
    }
    final entries = periodMode
        ? _entries.where(_isInPeriod).toList()
        : _entries.where((entry) => _isOn(entry, _selectedDay!)).toList();
    return [
      if (periodMode)
        _PeriodCard(
          preset: _periodPreset,
          start: _periodStart,
          end: _periodEnd,
          syncToken: _periodSyncToken,
          canApply: !_startInvalid && !_endInvalid,
          onSelectPreset: _selectPreset,
          onChangeStart: (d) => _setPeriodDate(isStart: true, date: d),
          onChangeEnd: (d) => _setPeriodDate(isStart: false, date: d),
          onStartInvalid: (v) => _setDateInvalid(isStart: true, invalid: v),
          onEndInvalid: (v) => _setDateInvalid(isStart: false, invalid: v),
          onApply: _applyPeriod,
        )
      else
        _CalendarCard(
          month: _visibleMonth,
          entryDays: _entryDays,
          today: DateTime.now(),
          selectedDay: _selectedDay,
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
          onSelectDay: _onSelectDay,
        ),
      const SizedBox(height: AppSpacing.xxl),
      if (periodMode)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                // 입력 중인 기간과 달라질 수 있어, 적용된 기간을 함께 보여준다.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('기간 내 기록', style: AppTextStyles.title),
                    Text(
                      '${_dotDate(_appliedStart!)} ~ ${_dotDate(_appliedEnd!)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${entries.length}건',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _SmallOutlinedButton(label: '날짜별 보기', onPressed: _backToDayMode),
            ],
          ),
        )
      else
        // 기간 모드의 헤더 줄과 같은 12px 아래 간격을 둔다.
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedDay!.month}월 ${_selectedDay!.day}일의 기록',
                  style: AppTextStyles.title,
                ),
              ),
              _SmallOutlinedButton(label: '전체 기록', onPressed: _openPeriodMode),
            ],
          ),
        ),
      if (entries.isEmpty)
        _StatusMessage(
          icon: Symbols.footprint_rounded,
          imageAsset: 'assets/illustrations/icon/footprint.png',
          text: !periodMode
              ? '이날은 아직 기록이 없어요.'
              : _entries.isEmpty
              ? '아직 남긴 발자국이 없어요.\n여행의 순간을 첫 기록으로 남겨보세요.'
              : '이 기간에는 기록이 없어요.',
        )
      else
        for (var i = 0; i < entries.length; i++) ...[
          if (i != 0) const SizedBox(height: AppSpacing.lg),
          _FeedEntryCard(
            key: ValueKey(entries[i].id),
            entry: entries[i],
            onEditText: () => _editEntry(entries[i]),
            onMenu: () => _openEntryMenu(entries[i]),
          ),
        ],
      if (_loadingMore)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
    ];
  }
}

/// 로그인 필요 / 로딩 실패 / 빈 목록 안내 — 아이콘 + 문구 (+선택적 재시도 버튼).
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.text,
    this.onRetry,
    this.imageAsset,
  });

  final IconData icon;
  final String? imageAsset;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          if (imageAsset != null)
            Image.asset(imageAsset!, width: 32, height: 32, fit: BoxFit.contain)
          else
            Icon(icon, size: 32, color: AppColors.iconInactive),
          const SizedBox(height: AppSpacing.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ],
      ),
    );
  }
}

/// "나의 발자국" 제목 + 참새 + 안내 문구.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '여행의 순간을 차곡차곡 남겨보세요.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 기간 설정 ("전체 기록" 모드)
// ---------------------------------------------------------------------------

/// [date]의 [months]개월 전 같은 날 — 그 달에 없는 날짜(예: 3/31의 한 달 전)는
/// 말일로 맞춘다.
DateTime _monthsBefore(DateTime date, int months) {
  final first = DateTime(date.year, date.month - months);
  final lastDay = DateUtils.getDaysInMonth(first.year, first.month);
  return DateTime(first.year, first.month, math.min(date.day, lastDay));
}

/// 기간 빠른 선택 — 오늘을 마지막 날로 하는 최근 N.
enum _PeriodPreset {
  week('1주일'),
  month('한 달'),
  threeMonths('3개월'),
  sixMonths('6개월');

  const _PeriodPreset(this.label);

  final String label;

  /// [end]를 마지막 날로 하는 이 기간의 시작일(양 끝 날짜 포함).
  DateTime startFrom(DateTime end) => switch (this) {
    _PeriodPreset.week => DateTime(end.year, end.month, end.day - 6),
    _PeriodPreset.month => _monthsBefore(end, 1),
    _PeriodPreset.threeMonths => _monthsBefore(end, 3),
    _PeriodPreset.sixMonths => _monthsBefore(end, 6),
  };
}

/// Small Button(CLAUDE.md §7) — 높이 36, 좌우 12, 모서리 12의 외곽선 버튼.
/// 모드를 오가는 "전체 기록"/"날짜별 보기"처럼 눌러야 한다는 게 보여야 하는
/// 보조 동작에 쓴다.
class _SmallOutlinedButton extends StatelessWidget {
  const _SmallOutlinedButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.smallButton),
          ),
          textStyle: AppTextStyles.buttonMedium,
        ),
        child: Text(label),
      ),
    );
  }
}

String _dotDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.'
    '${d.day.toString().padLeft(2, '0')}';

/// "전체 기록" 모드 상단 카드 — 빠른 기간 선택 4개 + 시작일/종료일 직접 설정.
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.preset,
    required this.start,
    required this.end,
    required this.syncToken,
    required this.canApply,
    required this.onSelectPreset,
    required this.onChangeStart,
    required this.onChangeEnd,
    required this.onStartInvalid,
    required this.onEndInvalid,
    required this.onApply,
  });

  /// 선택된 빠른 기간. null이면 날짜를 직접 설정한 상태.
  final _PeriodPreset? preset;
  final DateTime start;
  final DateTime end;

  /// 값이 바뀌면 입력 칸 글자를 [start]/[end]로 다시 맞춘다.
  final int syncToken;

  /// 두 입력 칸이 모두 유효할 때만 "적용"을 누를 수 있다.
  final bool canApply;
  final ValueChanged<_PeriodPreset> onSelectPreset;

  /// 올바른 날짜가 입력되면 호출된다. 반영했으면 null, 거절했으면 입력 칸
  /// 아래에 보여줄 안내 문구를 돌려준다.
  final String? Function(DateTime) onChangeStart;
  final String? Function(DateTime) onChangeEnd;

  /// 입력 칸이 채워지다 만 상태이거나 오류인지가 바뀔 때 호출된다.
  final ValueChanged<bool> onStartInvalid;
  final ValueChanged<bool> onEndInvalid;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.date_range_rounded,
                size: 20,
                color: AppColors.iconActive,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '기록 기간',
                  style: AppTextStyles.title.copyWith(color: AppColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final p in _PeriodPreset.values) ...[
                if (p != _PeriodPreset.values.first)
                  const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _PeriodPill(
                    label: p.label,
                    selected: p == preset,
                    onTap: () => onSelectPreset(p),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DateField(
                  label: '시작일',
                  date: start,
                  syncToken: syncToken,
                  onChanged: onChangeStart,
                  onInvalidChanged: onStartInvalid,
                ),
              ),
              // 라벨(18) + 간격(4) 아래의 36px 입력 칸 높이에 맞춰 세로 중앙 정렬.
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  top: 22,
                ),
                child: SizedBox(
                  height: 36,
                  child: Center(
                    child: Text(
                      '~',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _DateField(
                  label: '종료일',
                  date: end,
                  syncToken: syncToken,
                  onChanged: onChangeEnd,
                  onInvalidChanged: onEndInvalid,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Small Button(높이 36, 모서리 12)의 Primary 변형 — 폭은 카드에 꽉
          // 채우고 높이만 표준 56px 대신 36px로 낮춘다.
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: canApply ? onApply : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.smallButton),
                ),
                textStyle: AppTextStyles.buttonMedium,
              ),
              child: const Text('적용'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        // 좁은 화면(19.5:9 등)에서도 4개가 한 줄에 들어가도록 표준 태그(36)보다
        // 작게 쓴다. 그래도 넘치면 글자가 줄어들어 항상 한 줄을 유지한다.
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: AppTextStyles.buttonMedium.copyWith(
              fontSize: 12,
              height: 18 / 12,
              color: selected
                  ? AppColors.textOnPrimaryButton
                  : AppColors.primaryPressed,
            ),
          ),
        ),
      ),
    );
  }
}

/// `YYYY.MM.DD`를 숫자만 치면 점이 자동으로 붙는 날짜 텍스트 입력 칸.
///
/// 8자리가 다 채워지면 [onChanged]로 올린다. 존재하지 않는 날짜(예: 2월 31일)
/// 이거나 [onChanged]가 안내 문구를 돌려주면 그 문구를 칸 아래에 빨간 테두리와
/// 함께 보여주고, 그동안 화면의 기간은 마지막으로 유효했던 값을 유지한다.
/// [syncToken]이 바뀌면(프리셋 선택 등) 입력 내용을 [date]로 다시 맞춘다.
/// 칸이 채워지다 만 상태이거나 오류인지는 [onInvalidChanged]로 알린다.
class _DateField extends StatefulWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.syncToken,
    required this.onChanged,
    required this.onInvalidChanged,
  });

  final String label;
  final DateTime date;
  final int syncToken;
  final String? Function(DateTime) onChanged;
  final ValueChanged<bool> onInvalidChanged;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final _controller = TextEditingController(text: _dotDate(widget.date));
  final _focusNode = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncToken != oldWidget.syncToken) {
      _controller.text = _dotDate(widget.date);
      _error = null;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 입력을 마치고 칸을 벗어났는데 8자리가 안 채워져 있으면 알려준다.
  void _onFocusChange() {
    if (_focusNode.hasFocus || _controller.text.length == 10) return;
    setState(() => _error = '2026.09.20처럼 입력해 주세요.');
  }

  void _handleChanged(String text) {
    // 치는 중에는 조용히 두고, 8자리가 다 채워졌을 때만 검사한다.
    final incomplete = text.length < 10;
    String? error;
    if (!incomplete) {
      final parsed = _parseDotDate(text);
      error = parsed == null ? '존재하지 않는 날짜예요.' : widget.onChanged(parsed);
    }
    setState(() => _error = error);
    // 채워지다 만 글자는 화면의 기간(마지막 유효값)과 다르므로 "적용"을 막는다.
    widget.onInvalidChanged(incomplete || error != null);
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.inputField),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;
    final idle = hasError ? _border(AppColors.error, 2) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [_DotDateFormatter()],
          onChanged: _handleChanged,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'YYYY.MM.DD',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textDisabled,
            ),
            // 22px 줄 높이 + 위아래 7px = 36px — 날짜만 넣는 칸이라 표준 입력
            // 칸(52px)보다 낮게 잡았다.
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 7,
            ),
            border: idle ?? _border(AppColors.border, 1),
            enabledBorder: idle ?? _border(AppColors.border, 1),
            focusedBorder: idle ?? _border(AppColors.focusBorder, 2),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _error!,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

/// `YYYY.MM.DD` 형식이면 그 날짜, 아니거나 없는 날짜(2월 31일 등)면 null.
DateTime? _parseDotDate(String text) {
  final m = RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})$').firstMatch(text);
  if (m == null) return null;
  final year = int.parse(m[1]!);
  final month = int.parse(m[2]!);
  final day = int.parse(m[3]!);
  final date = DateTime(year, month, day);
  // DateTime은 2월 31일을 3월 3일로 넘겨버리므로 되돌려 비교한다.
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

/// 숫자만 남기고 `YYYY.MM.DD`로 점을 붙여준다 — 회원가입의 생년월일 칸
/// (`_BirthDateFormatter`)과 같은 방식이고 구분자만 `.`이다.
class _DotDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      if ((i == 3 || i == 5) && i != limited.length - 1) buffer.write('.');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ---------------------------------------------------------------------------
// 달력
// ---------------------------------------------------------------------------

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.entryDays,
    required this.today,
    required this.selectedDay,
    required this.onPrev,
    required this.onNext,
    required this.onSelectDay,
  });

  final DateTime month;
  final Set<DateTime> entryDays;
  final DateTime today;
  final DateTime? selectedDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday: 월=1..일=7 → 일요일 시작 그리드에서의 앞쪽 빈 칸 수.
    final leadingBlanks = firstOfMonth.weekday % 7;

    // 6줄(최대) × 7칸을 채운다.
    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      cells.add(
        _DayCell(
          day: day,
          hasEntry: entryDays.contains(date),
          selected: date == selectedDay,
          isToday:
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day,
          onTap: () => onSelectDay(date),
        ),
      );
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          Row(
            children: [
              _MonthArrow(icon: Symbols.chevron_left_rounded, onTap: onPrev),
              Expanded(
                child: Text(
                  '${month.year}년 ${month.month}월',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(color: AppColors.success),
                ),
              ),
              _MonthArrow(icon: Symbols.chevron_right_rounded, onTap: onNext),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            childAspectRatio: 0.82,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(icon, size: 24, color: AppColors.iconPrimary),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasEntry,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool hasEntry;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: selected
                ? const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  )
                : isToday
                ? const BoxDecoration(
                    color: AppColors.surfaceSelected,
                    shape: BoxShape.circle,
                  )
                : null,
            child: Text(
              '$day',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: selected || hasEntry || isToday
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: selected
                    ? Colors.white
                    : isToday
                    ? AppColors.primaryPressed
                    : AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 14,
            child: hasEntry
                ? Image.asset(
                    'assets/illustrations/icon/footprint.png',
                    width: 14,
                    height: 14,
                    fit: BoxFit.contain,
                    semanticLabel: '기록 있음',
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 기록 카드
// ---------------------------------------------------------------------------

class _FeedEntryCard extends StatelessWidget {
  const _FeedEntryCard({
    super.key,
    required this.entry,
    required this.onEditText,
    required this.onMenu,
  });

  final RecordDetail entry;
  final VoidCallback onEditText;
  final VoidCallback onMenu;

  String get _dateLabel {
    final d = DateTime.tryParse(entry.date) ?? DateTime.now();
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}월 ${d.day}일 ${wd[d.weekday - 1]}요일';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.calendar_today_rounded,
                size: 16,
                color: AppColors.iconInactive,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _dateLabel,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              InkResponse(
                onTap: onMenu,
                radius: 18,
                child: const Icon(
                  Symbols.more_horiz_rounded,
                  size: 20,
                  color: AppColors.iconInactive,
                ),
              ),
            ],
          ),
          if (entry.place != null || entry.manualPlaceName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(
                  Symbols.location_on_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  entry.place?.name ?? entry.manualPlaceName!,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (entry.food != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(
                  Symbols.restaurant_rounded,
                  size: 14,
                  color: AppColors.secondaryAccent,
                ),
                const SizedBox(width: 2),
                Text(
                  entry.food!.name,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (entry.images.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _PhotoCarousel(images: entry.images),
          ],
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: onEditText,
            borderRadius: BorderRadius.circular(AppRadius.smallButton),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.title != null && entry.title!.isNotEmpty) ...[
                    Text(entry.title!, style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(
                    entry.body,
                    style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Symbols.edit_rounded,
                        size: 14,
                        color: AppColors.iconInactive,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text('글을 눌러 수정', style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 사진 여러 장을 옆으로 넘겨보는 캐러셀 — 우상단 "n/총" 배지 + 하단 점 표시.
/// 서버가 내려준 실제 이미지 URL(`RecordImage.imageUrl`)을 `Image.network`로
/// 그린다 — 발자국 작성 화면은 새 사진을 저장하지 않지만(백엔드에 업로드
/// 엔드포인트 없음), 이미 저장된 기록에 이미지가 있으면 그대로 보여준다.
class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.images});

  final List<RecordImage> images;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  List<RecordImage> get _sorted =>
      [...widget.images]
        ..sort((a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _sorted;
    final count = images.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return Image.network(
                  images[i].imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _PhotoPlaceholder(),
                );
              },
            ),
            if (count > 1)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${_index + 1}/$count',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textOnPrimaryButton,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (count > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.sm,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < count; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? AppColors.primary
                              : AppColors.surface.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceSelected,
      alignment: Alignment.center,
      child: const Icon(
        Symbols.image_rounded,
        size: 32,
        color: AppColors.iconInactive,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 글쓰기 버튼 (스티치 링)
// ---------------------------------------------------------------------------

class _WriteButton extends StatelessWidget {
  const _WriteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      tooltip: '발자국 남기기',
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimaryButton,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 3,
      highlightElevation: 2,
      shape: const CircleBorder(),
      child: const SizedBox(
        width: 56,
        height: 56,
        child: CustomPaint(
          foregroundPainter: _StitchRingPainter(),
          child: Icon(Symbols.edit_rounded, size: 26),
        ),
      ),
    );
  }
}

/// 올리브 원반 안쪽을 도는 크림색 점선 링 — 손바느질 느낌의 장식.
class _StitchRingPainter extends CustomPainter {
  const _StitchRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final paint = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const dashes = 26;
    final sweep = 2 * math.pi / dashes;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StitchRingPainter oldDelegate) => false;
}
