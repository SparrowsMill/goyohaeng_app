import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../data/mock_sparrow.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/fading_scene_background.dart';
import '../account/account_center_screen.dart';
import '../food/food_dex_screen.dart';
import '../record/footprint_write_screen.dart';

/// `<참새>` (user_flow §3) — 본인 프로필 페이지. 방앗간 홈의 참새 캐릭터를 눌러
/// 진입한다. 참새 캐릭터·닉네임·레벨, 활동 요약(방문 장소/방문 인증/완성 음식/
/// 모은 재료), 최근 일기 미리보기, 계정 센터 연결을 제공한다.
///
/// 뼈대만 구현 — 레벨/경험치/함께한 날수/일기는 여전히 `mock_sparrow`
/// placeholder(신규 백엔드 필드 필요). 닉네임은 별도 필드 없이 계정 센터의
/// `Me.realName`을 그대로 표시하고(`_ProfileCard._displayName()`), 연필
/// 아이콘은 그 값을 고치는 계정 센터 화면으로 이동한다.
///
/// * TODO(asset): 이 화면 배경 scene 미납품 —
///   `assets/illustrations/scenes/sparrow_bg.png` (§9, 참새 + 방앗간 헤더 밴드).
///   그 전까지 `sparrow/sparrow_default.png` 만 코드로 얹는다.
class SparrowScreen extends StatefulWidget {
  const SparrowScreen({super.key});

  @override
  State<SparrowScreen> createState() => _SparrowScreenState();
}

class _SparrowScreenState extends State<SparrowScreen> {
  /// 실 최근 발자국(§8 `<기록 플랫폼>`, 이미 연동된 `GET /records`) — 못
  /// 불러왔거나 하나도 없으면 mock 미리보기로 대체.
  RecordDetail? _latestRecord;

  @override
  void initState() {
    super.initState();
    DashboardStore.instance.ensureLoaded();
    SparrowStore.instance.ensureLoaded();
    _loadLatestDiary();
  }

  /// mock 프로필에 실 레벨/경험치/함께한 날수만 덮어써서 넘긴다 — 닉네임·활동
  /// 요약·최근 일기는 계속 별도 소스([[_ActivitySummary]]는 `DashboardStore`,
  /// 닉네임은 `Me.realName`, 일기는 `_latestRecord`).
  SparrowProfile _effectiveProfile() {
    final base = mockSparrowProfile;
    final live = SparrowStore.instance.data;
    if (live == null) return base;
    return SparrowProfile(
      name: base.name,
      level: live.level,
      xp: live.xp,
      xpForNextLevel: live.xpForNextLevel,
      daysTogether: live.daysTogether,
      visitedPlaceCount: base.visitedPlaceCount,
      verifiedStampCount: base.verifiedStampCount,
      completedFoodCount: base.completedFoodCount,
      collectedIngredientCount: base.collectedIngredientCount,
      latestDiary: base.latestDiary,
    );
  }

  Future<void> _loadLatestDiary() async {
    try {
      final page = await RecordService().list(limit: 1);
      if (!mounted) return;
      setState(() {
        _latestRecord = page.records.isEmpty ? null : page.records.first;
      });
    } on ApiException {
      // 조용히 mock 미리보기로 남겨둔다.
    }
  }

  Future<void> _openWriteDiary(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FootprintWriteScreen()),
    );
    if (saved == true) _loadLatestDiary();
  }

  @override
  Widget build(BuildContext context) {
    final p = _effectiveProfile();
    final diaryText = _latestRecord?.body ?? '아직 작성한 기록이 없어요';
    final diaryImages = _latestRecord?.images ?? const [];
    final diaryImageUrl = diaryImages.isEmpty ? null : diaryImages.first.imageUrl;
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('마이 페이지'),
      ),
      body: ListView(
        padding: AppBottomNavBar.scrollPadding(context, EdgeInsets.zero),
        children: [
          _SceneBand(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListenableBuilder(
                  listenable: SparrowStore.instance,
                  builder: (context, _) => _ProfileCard(
                    profile: _effectiveProfile(),
                    onEditName: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AccountCenterScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const _MiniLabel('참새의 활동 요약'),
                const SizedBox(height: AppSpacing.md),
                _ActivitySummary(
                  profile: p,
                  onTapCompletedFoods: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FoodDexScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const _MiniLabel('발자국 남기기'),
                const SizedBox(height: AppSpacing.md),
                _DiaryCard(
                  text: diaryText,
                  imageUrl: diaryImageUrl,
                  onWrite: () => _openWriteDiary(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                _AccountCenterRow(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountCenterScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }
}

/// 헤더 밴드 — scene + 참새 + 말풍선. 로그인 화면의 `AuthPageBackground` 와
/// 똑같이 `start_bg.png` 를 `BoxFit.fitWidth` 로 원본 비율 그대로(잘림 없이)
/// 깔고, 그 위에 참새와 말풍선을 얹는다. 밴드 높이 = 이미지 자연 높이.
class _SceneBand extends StatelessWidget {
  const _SceneBand();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FadingSceneBackground(
          asset: 'assets/illustrations/scenes/start_bg.png',
          height: MediaQuery.sizeOf(context).width * 627 / 1024,
        ),
        // 말풍선 + 참새를 한 그룹으로 묶어 같이 움직인다. 그룹 위치는 이
        // Positioned 의 left/bottom, 크기는 SizedBox width / Image width 로.
        Positioned(
          left: 70,
          bottom: 0,
          child: SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(12, 2),
                  child: const _SpeechBubble(
                    text: '안녕! 나는 고요행의 참새야.\n너의 여행을 함께 도와줄게!',
                  ),
                ),
                Image.asset(
                  'assets/illustrations/sparrow/sparrow_profile_2.png',
                  width: 148,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 148,
                    height: 148,
                    child: Icon(
                      Symbols.flutter_dash_rounded,
                      size: 120,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.lg),
          child: CustomPaint(size: Size(12, 7), painter: _TailPainter()),
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.surface.withValues(alpha: 0.9);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 아바타 + 닉네임/레벨 + 경험치 바 + 함께한 날수 메시지.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onEditName});

  final SparrowProfile profile;
  final VoidCallback onEditName;

  /// 닉네임은 별도 필드 없이 계정 센터의 `Me.realName`을 재사용한다 — 아직
  /// 못 받았거나 비어 있으면 mock 이름으로 대체.
  String _displayName() {
    final realName = AuthStore.instance.me?.realName;
    return (realName == null || realName.isEmpty) ? profile.name : realName;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: Container(
                  width: 50,
                  height: 50,
                  color: AppColors.surfaceSelected,
                  child: Image.asset(
                    'assets/illustrations/sparrow/sparrow_profile.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Symbols.flutter_dash_rounded,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _displayName(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h3,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        GestureDetector(
                          onTap: onEditName,
                          child: const Icon(
                            Symbols.edit_rounded,
                            size: 16,
                            color: AppColors.iconInactive,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _LevelChip(level: profile.level),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _XpBar(profile: profile),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSelected,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Text.rich(
              TextSpan(
                style: AppTextStyles.bodySmall.copyWith(height: 1.6),
                children: [
                  const TextSpan(text: '참새와 함께한 날이 '),
                  TextSpan(
                    text: '${profile.daysTogether}일째!',
                    style: const TextStyle(
                      color: AppColors.secondaryAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: '\n앞으로도 좋은 여행을 함께 떠나보자구~'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Lv. $level',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textOnPrimaryButton,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.profile});

  final SparrowProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: profile.xpProgress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceSelected,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${profile.xp} / ${profile.xpForNextLevel}',
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// 활동 요약 2×2 그리드.
class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({
    required this.profile,
    required this.onTapCompletedFoods,
  });

  final SparrowProfile profile;
  final VoidCallback onTapCompletedFoods;

  @override
  Widget build(BuildContext context) {
    // 누적 활동 수치는 `/users/me/dashboard`에서 온다. 아직 못 받았으면 mock.
    return ListenableBuilder(
      listenable: DashboardStore.instance,
      builder: (context, _) {
        final d = DashboardStore.instance.data;
        final placeCount = d?.visitedPlaceCount ?? profile.visitedPlaceCount;
        final verified = d?.verifiedVisitCount ?? profile.verifiedStampCount;
        final madeFood = d?.madeFoodCount ?? profile.completedFoodCount;
        final ingredients =
            d?.ingredientCount ?? profile.collectedIngredientCount;

        final items = <_StatData>[
          _StatData(
            asset: 'assets/illustrations/icon/visited.png',
            fallback: Symbols.location_on_rounded,
            label: '방문 장소 수',
            value: '$placeCount곳',
          ),
          _StatData(
            asset: 'assets/illustrations/icon/verified.png',
            fallback: Symbols.verified_rounded,
            label: '방문 인증 횟수',
            value: '$verified회',
          ),
          _StatData(
            asset: 'assets/illustrations/icon/dish_2.png',
            fallback: Symbols.restaurant_rounded,
            label: '완성한 음식 수',
            value: '$madeFood개',
            onTap: onTapCompletedFoods,
          ),
          _StatData(
            asset: 'assets/illustrations/icon/ingredient_3.png',
            fallback: Symbols.shopping_bag_rounded,
            label: '모은 재료',
            value: '$ingredients개',
          ),
        ];

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.9,
          children: [for (final it in items) _StatCard(data: it)],
        );
      },
    );
  }
}

class _StatData {
  _StatData({
    required this.asset,
    required this.fallback,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String asset;
  final IconData fallback;
  final String label;
  final String value;
  final VoidCallback? onTap;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Image.asset(
              data.asset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(data.fallback, size: 28, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      data.value,
                      style: AppTextStyles.title.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    if (data.onTap != null)
                      const Icon(
                        Symbols.chevron_right_rounded,
                        size: 16,
                        color: AppColors.iconInactive,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (data.onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: data.onTap,
        child: card,
      ),
    );
  }
}

/// 최근 일기 미리보기 + "일기 쓰기".
class _DiaryCard extends StatelessWidget {
  const _DiaryCard({required this.text, this.imageUrl, required this.onWrite});

  final String text;

  /// 최근 발자국의 첫 번째 첨부 사진(`record.images[0].imageUrl`) — 사진이
  /// 없는 기록이거나 아직 못 불러왔으면 `null`(아이콘 placeholder로 대체).
  final String? imageUrl;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.smallButton),
                child: Container(
                  width: 84,
                  height: 96,
                  color: AppColors.surfaceSelected,
                  child: imageUrl == null
                      ? const Icon(
                          Symbols.photo_rounded,
                          size: 28,
                          color: AppColors.iconInactive,
                        )
                      : Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Symbols.photo_rounded,
                                size: 28,
                                color: AppColors.iconInactive,
                              ),
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.bodySmall.copyWith(height: 1.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              onPressed: onWrite,
              icon: const Icon(Symbols.edit_rounded, size: 18),
              label: const Text('일기 쓰기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCenterRow extends StatelessWidget {
  const _AccountCenterRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: AppDecorations.card(),
          child: Row(
            children: [
              const Icon(
                Symbols.person_rounded,
                size: 20,
                color: AppColors.iconPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '계정 센터로 이동',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(
                Symbols.chevron_right_rounded,
                size: 20,
                color: AppColors.iconInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 가운데 정렬 잎 장식 라벨.
class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Leaf(flip: true),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.title),
        const SizedBox(width: AppSpacing.sm),
        _Leaf(flip: false),
      ],
    );
  }
}

class _Leaf extends StatelessWidget {
  const _Leaf({required this.flip});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/branding/leaf_ornament_2.png',
      width: 50,
      height: 50,
      errorBuilder: (context, error, stackTrace) => const SizedBox(width: 50),
    );
    return flip ? Transform.flip(flipX: true, child: img) : img;
  }
}
