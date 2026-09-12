import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_footprint.dart';
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
/// 나의 발자국에서 기록을 눌러 들어오면 [editing] 이 `true` 로, 모든 필드가
/// 채워진 채 열린다. 저장 시 [FootprintDraft] 를 `Navigator.pop` 결과로
/// 돌려주고, 호출한 화면이 목록에 반영한다.
///
/// * TODO(backend): 기록 저장/수정 API 연동 — 지금은 로컬 목록에만 반영된다.
/// * TODO: 갤러리 사진 선택 — image_picker 연동. 지금은 "+" 누르면 스낵바.
/// * TODO(asset): 이 화면 배경 `assets/illustrations/scenes/footprint_bg.png`
///   (§9, 나의 발자국과 공유) 미납품 — 그 전까지 평면 #FAE7C0.
class FootprintWriteScreen extends StatefulWidget {
  const FootprintWriteScreen({
    super.key,
    this.editing = false,
    this.initialDate,
    this.initialPlace,
    this.initialTitle,
    this.initialText,
    this.initialPhotoAssets = const [],
  });

  /// 기존 기록을 여는 수정 모드 (헤더·버튼 문구가 바뀐다).
  final bool editing;

  final DateTime? initialDate;
  final String? initialPlace;
  final String? initialTitle;
  final String? initialText;

  /// 미리 첨부되는 이미지 — 전체 에셋 경로(`assets/...png`).
  final List<String> initialPhotoAssets;

  @override
  State<FootprintWriteScreen> createState() => _FootprintWriteScreenState();
}

class _FootprintWriteScreenState extends State<FootprintWriteScreen> {
  late final _titleController =
      TextEditingController(text: widget.initialTitle ?? '');
  late final _bodyController =
      TextEditingController(text: widget.initialText ?? '');

  late DateTime _date = widget.initialDate ?? DateTime.now();
  late String? _place = widget.initialPlace;
  late final List<String> _photoAssets = [...widget.initialPhotoAssets];

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
    final controller = TextEditingController(text: _place ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('장소'),
        content: AppTextField(
          controller: controller,
          hintText: '어디에서의 기록인가요?',
          prefixIcon: Symbols.location_on_rounded,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      setState(() => _place = result.isEmpty ? null : result);
    }
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

  void _submit() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty && body.isEmpty) {
      _snack('제목이나 짧은 글을 남겨주세요.');
      return;
    }
    // * TODO(backend): 실제 저장. 지금은 draft 를 돌려주고 호출 화면이 반영.
    final draft = FootprintDraft(
      date: _date,
      title: title.isEmpty ? null : title,
      text: body,
      place: _place,
      photoAssets: List.unmodifiable(_photoAssets),
    );
    _snack(widget.editing ? '기록을 수정했어요.' : '발자국을 남겼어요.');
    Navigator.of(context).pop(draft);
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
                      const _FieldLabel('장소'),
                      _PickerBox(
                        icon: Symbols.location_on_rounded,
                        value: _place ?? '장소를 선택해주세요',
                        muted: _place == null,
                        onTap: _pickPlace,
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
                            '갤러리에서 최대 $_maxPhotos장 첨부',
                            style: AppTextStyles.caption,
                          ),
                        ],
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

/// 값 + 우측 펼침 표시(∨) 형태의 탭 가능한 상자 — 날짜·장소 선택에 쓴다.
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

/// 채움 버튼 — 라벨 옆에 잎 장식.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        child: Row(
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
