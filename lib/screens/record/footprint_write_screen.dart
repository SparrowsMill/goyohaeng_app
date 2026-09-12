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
import '../../widgets/app_text_field.dart';
import '../map/map_screen.dart';

const _titleMaxLength = 50;
const _bodyMaxLength = 200;
const _maxPhotos = 5;

/// `<기록 플랫폼 글쓰기>` "발자국 남기기" (user_flow §8) — 마이 페이지의
/// "일기 쓰기" 버튼과 나의 발자국 화면의 연필 버튼에서 진입한다. 날짜·장소,
/// 제목(50자 이내), 짧은 글(200자 이내), 갤러리 사진 최대 5장을 입력한다.
///
/// "기록용 플랫폼에 공유"(방문 인증 보상 / 셰프의 주방)로 진입한 경우 날짜·
/// 장소·획득 일러스트가 미리 채워진 채로 열린다 — 그래서 [initialDate] /
/// [initialPlace] / [initialPhotoAssets] (첨부 이미지 에셋 경로) 를 받는다.
///
/// 나의 발자국에서 기록을 눌러 들어오면 [editing] 이 `true`, [recordId] 가
/// 그 기록의 ID로 채워진 채 열린다. 저장은 `RecordService().create(...)` /
/// `.update(...)`로 실제 백엔드에 반영되고, 성공하면 `Navigator.pop(true)`로
/// 호출한 화면에 알려 목록을 다시 불러오게 한다.
///
/// * 장소는 자유 텍스트가 아니라 실제 `Place` 중에서 고른다([_pickPlace] —
///   `PlaceService().list()`로 가져온 페이지를 이름으로 클라이언트 검색).
///   서버 검증을 통과하려면 실제 `placeId`가 필요하기 때문. 완전히 선택
///   사항이라 고르지 않아도 저장할 수 있다.
/// * 만든 음식도 선택적으로 붙일 수 있다([_pickUserFood] —
///   `UserService().getFoods()`).
/// * 사진 첨부는 앱 안에서만 보이는 미리보기다 — 백엔드에 이미지 업로드
///   엔드포인트가 아직 없어 실제 저장 시에는 `imageUrls: []`로 보낸다
///   (아래 "사진 첨부" 섹션 캡션 참고).
/// * TODO: 갤러리 사진 선택 — image_picker 연동. 지금은 "+" 누르면 스낵바.
/// * TODO(asset): 이 화면 배경 `assets/illustrations/scenes/footprint_bg.png`
///   (§9, 나의 발자국과 공유) 미납품 — 그 전까지 평면 #FAE7C0.
class FootprintWriteScreen extends StatefulWidget {
  const FootprintWriteScreen({
    super.key,
    this.editing = false,
    this.recordId,
    this.initialDate,
    this.initialPlaceId,
    this.initialPlace,
    this.initialTitle,
    this.initialText,
    this.initialPhotoAssets = const [],
    this.initialUserFoodId,
    this.initialUserFoodName,
    this.initialVisitVerificationId,
  });

  /// 기존 기록을 여는 수정 모드 (헤더·버튼 문구가 바뀐다).
  final bool editing;

  /// 수정 대상 기록 ID — [editing]이 `true`일 때 채워진다.
  final int? recordId;

  final DateTime? initialDate;

  /// 미리 선택된 장소의 실제 `Place.id` (알고 있을 때만).
  final int? initialPlaceId;

  /// 장소 표시 이름 — [initialPlaceId]가 없어도(목업 스팟 이름 등) 화면에는
  /// 보여준다. 실제 `placeId`가 없으면 저장 시 장소는 전송되지 않는다.
  final String? initialPlace;
  final String? initialTitle;
  final String? initialText;

  /// 미리 첨부되는 이미지 — 전체 에셋 경로(`assets/...png`). 앱 내 미리보기
  /// 전용이며 저장되지 않는다.
  final List<String> initialPhotoAssets;

  /// 미리 선택된 만든 음식 (`UserFood.id`) — 이름과 함께 알고 있을 때만.
  final int? initialUserFoodId;
  final String? initialUserFoodName;

  /// 방문 인증 보상 화면 등, 이미 발급된 `VERIFIED` 인증이 있을 때만 채운다.
  final int? initialVisitVerificationId;

  @override
  State<FootprintWriteScreen> createState() => _FootprintWriteScreenState();
}

class _FootprintWriteScreenState extends State<FootprintWriteScreen> {
  late final _titleController =
      TextEditingController(text: widget.initialTitle ?? '');
  late final _bodyController =
      TextEditingController(text: widget.initialText ?? '');

  late DateTime _date = widget.initialDate ?? DateTime.now();
  late int? _placeId = widget.initialPlaceId;
  late String? _placeName = widget.initialPlace;
  late int? _userFoodId = widget.initialUserFoodId;
  late String? _userFoodName = widget.initialUserFoodName;
  late final List<String> _photoAssets = [...widget.initialPhotoAssets];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _bodyController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _dateLabel {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${_date.year}년 ${_date.month}월 ${_date.day}일 '
        '${wd[_date.weekday - 1]}요일';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: '기록한 날짜',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPlace() async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(
        title: '장소 선택',
        hintText: '장소 이름으로 검색',
        emptyText: '조건에 맞는 장소가 없어요.',
        icon: Symbols.location_on_rounded,
        loader: () async {
          final page = await PlaceService().list(limit: 100);
          return [
            for (final p in page.items)
              _PickerItem(id: p.id, title: p.name, subtitle: p.address),
          ];
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.cleared) {
        _placeId = null;
        _placeName = null;
      } else {
        _placeId = result.item!.id;
        _placeName = result.item!.title;
      }
    });
  }

  Future<void> _pickUserFood() async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(
        title: '만든 음식 선택',
        hintText: '음식 이름으로 검색',
        emptyText: '아직 만든 음식이 없어요.',
        icon: Symbols.restaurant_rounded,
        loader: () async {
          final page = await UserService().getFoods(limit: 100);
          return [
            for (final f in page.items)
              _PickerItem(
                id: f.id,
                title: f.name,
                subtitle: f.madeAt == null
                    ? null
                    : '${f.madeAt!.year}.${f.madeAt!.month}.${f.madeAt!.day} 제작',
              ),
          ];
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.cleared) {
        _userFoodId = null;
        _userFoodName = null;
      } else {
        _userFoodId = result.item!.id;
        _userFoodName = result.item!.title;
      }
    });
  }

  void _removePhoto(int index) {
    setState(() => _photoAssets.removeAt(index));
  }

  void _addPhoto() {
    if (_photoAssets.length >= _maxPhotos) {
      _snack('사진은 최대 $_maxPhotos장까지 첨부할 수 있어요.');
      return;
    }
    _snack('갤러리에서 사진 첨부는 곧 만나요.');
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      _snack('짧은 글을 남겨주세요.');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    final dateStr =
        '${_date.year.toString().padLeft(4, '0')}-'
        '${_date.month.toString().padLeft(2, '0')}-'
        '${_date.day.toString().padLeft(2, '0')}';

    try {
      final recordId = widget.recordId;
      if (widget.editing && recordId != null) {
        await RecordService().update(
          recordId,
          date: dateStr,
          title: title.isEmpty ? '' : title,
          body: body,
        );
      } else {
        await RecordService().create(
          placeId: _placeId,
          userFoodId: _userFoodId,
          visitVerificationId: widget.initialVisitVerificationId,
          date: dateStr,
          title: title.isEmpty ? null : title,
          body: body,
          imageUrls: const [],
        );
      }
      if (!mounted) return;
      _snack(widget.editing ? '기록을 수정했어요.' : '발자국을 남겼어요.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Image.asset(
              'assets/illustrations/scenes/footprint_bg.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.huge,
              ),
              children: [
                _Header(editing: widget.editing),
                const SizedBox(height: AppSpacing.xxl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: AppDecorations.card(radius: AppRadius.largeCard),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('날짜'),
                      _PickerBox(
                        icon: Symbols.calendar_today_rounded,
                        value: _dateLabel,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _FieldLabel('장소 (선택)'),
                      _PickerBox(
                        icon: Symbols.location_on_rounded,
                        value: _placeName ?? '장소를 선택해주세요',
                        muted: _placeName == null,
                        onTap: _pickPlace,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _FieldLabel('만든 음식 (선택)'),
                      _PickerBox(
                        icon: Symbols.restaurant_rounded,
                        value: _userFoodName ?? '만든 음식을 선택해주세요',
                        muted: _userFoodName == null,
                        onTap: _pickUserFood,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _FieldLabel('제목'),
                      AppTextField(
                        controller: _titleController,
                        hintText: '오늘의 여행 제목',
                        prefixIcon: Symbols.menu_book_rounded,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(_titleMaxLength),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _FieldLabel('짧은 글 (200자 이내)'),
                      _BodyField(
                        controller: _bodyController,
                        maxLength: _bodyMaxLength,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const _FieldLabel('사진 첨부', bottomGap: 0),
                          const Spacer(),
                          Text(
                            '최대 $_maxPhotos장',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '사진은 앱 안에서만 보여요. 서버에는 저장되지 않아요.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textDisabled),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _PhotoStrip(
                        photoAssets: _photoAssets,
                        onRemove: _removePhoto,
                        onAdd: _addPhoto,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _SubmitButton(
                        label: widget.editing ? '기록 수정 완료' : '기록 남기기',
                        loading: _submitting,
                        onTap: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                0,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: Icon(
                        Symbols.arrow_back_rounded,
                        size: 24,
                        color: AppColors.iconPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).maybePop();
          }
          // * TODO: 랭킹 탭 — 해당 화면 구현 후 연결.
        },
      ),
    );
  }
}

/// 제목 + 참새 + 안내 문구. (나의 발자국 화면과 같은 형태)
class _Header extends StatelessWidget {
  const _Header({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(editing ? '발자국 다듬기' : '발자국 남기기', style: AppTextStyles.h1),
            const SizedBox(width: AppSpacing.sm),
            Image.asset(
              'assets/illustrations/sparrow/sparrow_happy.png',
              width: 44,
              height: 44,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Symbols.flutter_dash_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          editing
              ? '그날의 기록을 다시 들여다볼까요.'
              : '여행의 순간을 차근차근 기록해보세요.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.bottomGap = AppSpacing.sm});

  final String text;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 값 + 우측 펼침 표시(∨) 형태의 탭 가능한 상자 — 날짜·장소·음식 선택에 쓴다.
class _PickerBox extends StatelessWidget {
  const _PickerBox({
    required this.icon,
    required this.value,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.inputField),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.inputField),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: muted ? AppColors.textDisabled : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Symbols.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.iconInactive,
            ),
          ],
        ),
      ),
    );
  }
}

/// 여러 줄 본문 입력 + 우하단 글자수 카운터.
class _BodyField extends StatelessWidget {
  const _BodyField({required this.controller, required this.maxLength});

  final TextEditingController controller;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.inputField),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 5,
            minLines: 4,
            style: AppTextStyles.bodyLarge.copyWith(height: 1.6),
            inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: '이 순간을 어떻게 기억하고 싶나요?',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${controller.text.length}/$maxLength',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// 첨부 사진 가로 줄 — 각 사진에 삭제(✕) 배지, 마지막에 점선 "+" 추가 칸.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photoAssets,
    required this.onRemove,
    required this.onAdd,
  });

  final List<String> photoAssets;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    const tileWidth = 84.0;
    const tileHeight = 100.0;

    return SizedBox(
      height: tileHeight + 6,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 6),
        itemCount: photoAssets.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == photoAssets.length) {
            return _AddTile(
              width: tileWidth,
              height: tileHeight,
              onTap: onAdd,
            );
          }
          return SizedBox(
            width: tileWidth,
            height: tileHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.inputField),
                  child: Image.asset(
                    photoAssets[i],
                    width: tileWidth,
                    height: tileHeight,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.surfaceSelected,
                      alignment: Alignment.center,
                      child: const Icon(
                        Symbols.image_rounded,
                        size: 26,
                        color: AppColors.iconInactive,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 1.5),
                      ),
                      child: const Icon(
                        Symbols.close_rounded,
                        size: 13,
                        color: AppColors.textOnPrimaryButton,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.width,
    required this.height,
    required this.onTap,
  });

  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const _DashedBorderPainter(),
        child: SizedBox(
          width: width,
          height: height,
          child: const Icon(
            Symbols.add_rounded,
            size: 26,
            color: AppColors.iconInactive,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.inputField),
    );
    final path = Path()..addRRect(rrect);

    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}

/// 채움 버튼 — 라벨 옆에 잎 장식. 저장 중에는 스피너로 바뀐다.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.textOnPrimaryButton,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: AppTextStyles.buttonLarge),
                  const SizedBox(width: AppSpacing.sm),
                  Image.asset(
                    'assets/branding/leaf_ornament.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Symbols.eco_rounded,
                      size: 18,
                      color: AppColors.textOnPrimaryButton,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 장소 / 만든 음식 선택 바텀시트 — 서버에 이름 검색 API가 없어 한 페이지를
// 가져온 뒤 클라이언트에서 필터링한다 (스펙 §13-1 참고).
// ---------------------------------------------------------------------------

/// [_PickerSheet]가 보여주는 선택지 한 건 — 실제 백엔드 id + 표시 문구.
class _PickerItem {
  const _PickerItem({required this.id, required this.title, this.subtitle});

  final int id;
  final String title;
  final String? subtitle;
}

/// [_PickerSheet]의 결과 — 선택 해제([cleared]) 또는 고른 [item].
typedef _PickerResult = ({bool cleared, _PickerItem? item});

/// 장소/만든 음식 공용 검색·선택 바텀시트.
class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.hintText,
    required this.emptyText,
    required this.icon,
    required this.loader,
  });

  final String title;
  final String hintText;
  final String emptyText;
  final IconData icon;
  final Future<List<_PickerItem>> Function() loader;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _controller = TextEditingController();
  List<_PickerItem>? _items;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.loader();
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = _items;
    final q = _query.trim().toLowerCase();
    final results = all == null
        ? const <_PickerItem>[]
        : (q.isEmpty
            ? all
            : all.where((e) => e.title.toLowerCase().contains(q)).toList());

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(widget.title, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _controller,
              hintText: widget.hintText,
              prefixIcon: Symbols.search_rounded,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.error),
                      ),
                    )
                  : all == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          children: [
                            ListTile(
                              leading: const Icon(
                                Symbols.block_rounded,
                                color: AppColors.iconInactive,
                              ),
                              title: const Text('선택 안 함'),
                              onTap: () => Navigator.of(context)
                                  .pop((cleared: true, item: null)),
                            ),
                            const Divider(height: 1, color: AppColors.divider),
                            if (results.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xxl,
                                ),
                                child: Center(
                                  child: Text(
                                    widget.emptyText,
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            else
                              for (final item in results)
                                ListTile(
                                  leading:
                                      Icon(widget.icon, color: AppColors.primary),
                                  title: Text(item.title),
                                  subtitle: item.subtitle == null
                                      ? null
                                      : Text(
                                          item.subtitle!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  onTap: () => Navigator.of(context)
                                      .pop((cleared: false, item: item)),
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
