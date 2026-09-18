import 'dart:math' as math;

import 'package:flutter/material.dart';
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
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 100;
    if (show != _showScrollToTop) setState(() => _showScrollToTop = show);
    if (_signedIn &&
        !_loading &&
        !_loadingMore &&
        _hasMoreEntries &&
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
    final entries = _selectedDay == null
        ? _entries
        : _entries.where((entry) => _isOn(entry, _selectedDay!)).toList();
    return [
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
      if (_selectedDay != null)
        Row(
          children: [
            Expanded(
              child: Text(
                '${_selectedDay!.month}월 ${_selectedDay!.day}일의 기록',
                style: AppTextStyles.title,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedDay = null),
              child: const Text('전체 기록'),
            ),
          ],
        ),
      if (entries.isEmpty)
        _StatusMessage(
          icon: Symbols.footprint_rounded,
          imageAsset: 'assets/illustrations/icon/footprint.png',
          text: _selectedDay != null
              ? '이날은 아직 기록이 없어요.'
              : '아직 남긴 발자국이 없어요.\n여행의 순간을 첫 기록으로 남겨보세요.',
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
