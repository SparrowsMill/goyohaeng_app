import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

const _titleMaxLength = 50;
const _bodyMaxLength = 200;
const _maxPhotos = 5;

/// `<기록 플랫폼 글쓰기>` "발자국 남기기" (user_flow §8) — 마이 페이지의
/// "일기 쓰기" 버튼과 나의 발자국 화면의 연필 버튼에서 진입한다. 날짜·장소,
/// 제목(50자 이내), 짧은 글(200자 이내), 갤러리 사진 최대 5장을 입력한다.
///
/// "기록용 플랫폼에 공유"(방문 인증 보상 / 셰프의 주방)로 진입한 경우 날짜·
/// 장소·획득 일러스트가 미리 채워진 채로 열린다 — 그래서 [initialDate] /
/// [initialPlace] / [initialPhotoAssets] (첨부 이미지 에셋 경로, 다른 사진과
/// 동일하게 실제 업로드·저장된다) 를 받는다.
///
/// 나의 발자국에서 기록을 눌러 들어오면 [editing] 이 `true`, [recordId] 가
/// 그 기록의 ID로 채워진 채 열린다. 저장은 `RecordService().create(...)` /
/// `.update(...)`로 실제 백엔드에 반영되고, 성공하면 `Navigator.pop(true)`로
/// 호출한 화면에 알려 목록을 다시 불러오게 한다.
///
/// * 장소는 입력칸 하나뿐이다 — [initialPlace]/[initialManualPlaceName]으로
///   자동 채워지고(방문 인증 보상 화면 등), 그대로 두면 등록 장소([placeId])로
///   저장되고 사용자가 글자를 고치는 순간부터는 수동 장소명으로 취급한다
///   (전체 장소 175,000여 개를 훑어 방문 여부를 하나씩 조회하던 기존 검색
///   팝업은 그 규모에서 사실상 로딩이 끝나지 않아 제거했다). 수정 시 장소
///   변경·해제도 지원하며, 기존에 연결된 방문 인증이 있었다면 서버가 그
///   연결을 해제한다(인증 기록 자체는 유지).
/// * 만든 음식 선택 UI는 제공하지 않는다. 음식 화면에서 전달된 기존 연결은 유지한다.
/// * 갤러리에서 고른 사진과 [initialPhotoAssets]로 미리 채워진 번들 에셋(보상
///   일러스트 등)은 모두 저장 시 `POST /uploads/images`로 업로드하고 받은
///   URL을 기록의 `imageUrls`로 저장한다(스펙 2026-09-15) — 번들 에셋은
///   `initState`에서 바이트를 미리 읽어와 갤러리 사진과 동일하게 취급한다.
///   수정 화면에서는 기존 사진([initialImageUrls])도 처음부터 [_PhotoStrip]에
///   함께 표시돼 수정 대상에 포함된다 — 다른 사진과 똑같이 ✕ 배지로 개별
///   삭제할 수 있고, 저장 시 지우지 않은 것만 그대로 유지된다.
class FootprintWriteScreen extends StatefulWidget {
  const FootprintWriteScreen({
    super.key,
    this.editing = false,
    this.recordId,
    this.initialDate,
    this.initialPlaceId,
    this.initialPlace,
    this.initialManualPlaceName,
    this.initialTitle,
    this.initialText,
    this.initialPhotoAssets = const [],
    this.initialImageUrls = const [],
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

  /// 기존 기록에 저장된 수동 장소명(`record.manualPlaceName`) — [editing]일
  /// 때만 채워진다. [initialPlaceId]와 동시에 채워지지 않는다.
  final String? initialManualPlaceName;
  final String? initialTitle;
  final String? initialText;

  /// 미리 첨부되는 이미지 — 전체 에셋 경로(`assets/...png`). 갤러리에서 고른
  /// 사진과 동일하게 실제 업로드되어 기록에 저장된다.
  final List<String> initialPhotoAssets;

  /// 기존 기록에 이미 업로드된 사진들(`record.images[].imageUrl`) — [editing]일
  /// 때만 채워진다. 화면에는 표시하지 않지만, 새 사진을 추가로 골라 저장할 때
  /// 이 목록과 합쳐 보내 기존 사진이 지워지지 않게 한다.
  final List<String> initialImageUrls;

  /// 미리 선택된 만든 음식 (`UserFood.id`) — 이름과 함께 알고 있을 때만.
  final int? initialUserFoodId;
  final String? initialUserFoodName;

  /// 방문 인증 보상 화면 등, 이미 발급된 `VERIFIED` 인증이 있을 때만 채운다.
  final int? initialVisitVerificationId;

  @override
  State<FootprintWriteScreen> createState() => _FootprintWriteScreenState();
}

class _FootprintWriteScreenState extends State<FootprintWriteScreen> {
  late final _titleController = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  late final _bodyController = TextEditingController(
    text: widget.initialText ?? '',
  );

  /// 방문 인증 보상 화면 등에서 넘어온 장소명, 또는 수정 시 기존 수동
  /// 장소명으로 미리 채워진다. 그대로 두면 [_placeId]가 살아 있어 등록
  /// 장소로 저장되고, 사용자가 고치는 순간 [_placeId]가 풀리며 수동
  /// 장소명으로 취급된다.
  late final _placeController = TextEditingController(
    text: widget.initialPlace ?? widget.initialManualPlaceName ?? '',
  );
  late DateTime _date = widget.initialDate ?? DateTime.now();
  int? _placeId;
  late final List<String> _photoAssets = [
    ...widget.initialImageUrls,
    ...widget.initialPhotoAssets,
  ];
  final Map<String, MemoryImage> _selectedPhotos = {};
  bool _pickingPhotos = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _placeId = widget.initialPlaceId;
    // 자동 채워진 장소명을 사용자가 직접 고치면 더 이상 등록 장소(실제
    // Place.id)와 연결됐다고 볼 수 없다 — 그 순간부터 수동 장소명으로
    // 취급한다.
    _placeController.addListener(() {
      if (_placeId != null) setState(() => _placeId = null);
    });
    _bodyController.addListener(() => setState(() {}));
    _loadInitialAssetPhotos();
  }

  /// [widget.initialPhotoAssets]로 미리 채워진 번들 에셋의 바이트를 읽어와
  /// 갤러리에서 고른 사진과 동일하게 `_selectedPhotos`에 담는다 — 저장 시
  /// 업로드 대상 판별(`_submit`)이 이 맵에 있는지만 보기 때문에, 여기 담아야
  /// 실제로 `POST /uploads/images`에 올라가 기록에 저장된다.
  Future<void> _loadInitialAssetPhotos() async {
    for (final path in widget.initialPhotoAssets) {
      try {
        final data = await rootBundle.load(path);
        if (!mounted) return;
        setState(() {
          _selectedPhotos[path] = MemoryImage(data.buffer.asUint8List());
        });
      } catch (_) {
        // 에셋을 못 읽으면 미리보기(AssetImage)로만 남고 업로드에서는 빠진다.
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _placeController.dispose();
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

  void _removePhoto(int index) {
    if (_submitting || _pickingPhotos) return;
    setState(() {
      _selectedPhotos.remove(_photoAssets.removeAt(index));
    });
  }

  Future<void> _addPhoto() async {
    if (_pickingPhotos || _submitting) return;
    if (_photoAssets.length >= _maxPhotos) {
      _snack('사진은 최대 $_maxPhotos장까지 첨부할 수 있어요.');
      return;
    }
    setState(() => _pickingPhotos = true);
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (!mounted) return;
      final remaining = _maxPhotos - _photoAssets.length;
      final images = <String, MemoryImage>{};
      for (final file in files.take(remaining)) {
        images[file.path] = MemoryImage(await file.readAsBytes());
      }
      if (!mounted) return;
      setState(() {
        for (final entry in images.entries) {
          if (!_photoAssets.contains(entry.key)) _photoAssets.add(entry.key);
          _selectedPhotos[entry.key] = entry.value;
        }
      });
      if (files.length > remaining) {
        _snack('사진은 최대 $_maxPhotos장까지 첨부할 수 있어요.');
      }
    } catch (_) {
      if (mounted) _snack('사진을 불러오지 못했어요. 사진 접근 권한을 확인해주세요.');
    } finally {
      if (mounted) setState(() => _pickingPhotos = false);
    }
  }

  Future<void> _submit() async {
    if (_pickingPhotos || _submitting) return;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      _snack('짧은 글을 남겨주세요.');
      return;
    }
    setState(() => _submitting = true);

    final dateStr =
        '${_date.year.toString().padLeft(4, '0')}-'
        '${_date.month.toString().padLeft(2, '0')}-'
        '${_date.day.toString().padLeft(2, '0')}';
    // _placeId가 살아 있으면(자동 채워진 뒤 손대지 않았으면) 등록 장소로
    // 보내고, 그렇지 않으면(비어 있었거나 사용자가 고쳤으면) 입력칸 글자를
    // 수동 장소명으로 보낸다 — 둘은 상호 배타적이다.
    final manualPlaceName = _placeId == null
        ? _placeController.text.trim()
        : '';

    try {
      // `_photoAssets` 순서대로 최종 `imageUrls`를 만든다 — 이미 올라가 있던
      // 기존 사진(원격 URL)은 그대로 두고, 갤러리에서 고른 사진과
      // `_loadInitialAssetPhotos`가 읽어둔 번들 에셋(둘 다 `_selectedPhotos`에
      // 바이트가 있음)만 새로 업로드한다. 사용자가 [_removePhoto]로 기존
      // 사진을 지웠으면 `_photoAssets`에서 이미 빠져 있어 자연히 반영된다.
      final finalImageUrls = <String>[];
      for (final key in _photoAssets) {
        if (key.startsWith('http://') || key.startsWith('https://')) {
          finalImageUrls.add(key);
          continue;
        }
        final photo = _selectedPhotos[key];
        if (photo == null) continue;
        finalImageUrls.add(await UploadService().uploadImage(photo.bytes));
      }

      final recordId = widget.recordId;
      String message;
      if (widget.editing && recordId != null) {
        // placeId/manualPlaceName은 상호 배타적이라 항상 함께 반영한다 —
        // 둘 다 바뀌지 않았으면 생략해 기존 장소 연결(및 방문 인증 연결)을
        // 그대로 유지한다(스펙 2026-09-15).
        final placeChanged = _placeId != widget.initialPlaceId;
        final manualChanged =
            manualPlaceName != (widget.initialManualPlaceName?.trim() ?? '');
        await RecordService().update(
          recordId,
          date: dateStr,
          title: title.isEmpty ? '' : title,
          body: body,
          placeId: placeChanged || manualChanged
              ? _placeId
              : recordFieldUnset,
          manualPlaceName: placeChanged || manualChanged
              ? (manualPlaceName.isEmpty ? null : manualPlaceName)
              : recordFieldUnset,
          // PATCH의 imageUrls는 전체 교체라, 새로 고른 사진 유무와 무관하게
          // 항상 현재 상태(`finalImageUrls`)를 그대로 보낸다 — 그래야 기존
          // 사진을 지운 경우(새로 고른 사진 없이 삭제만 한 경우)도 반영된다.
          imageUrls: finalImageUrls,
        );
        // PATCH /records/{id} 응답엔 message가 없다(스펙 §12.5) — 고정 문구.
        message = '기록을 수정했어요.';
      } else {
        final result = await RecordService().create(
          placeId: _placeId,
          manualPlaceName: manualPlaceName.isEmpty ? null : manualPlaceName,
          userFoodId: widget.initialUserFoodId,
          visitVerificationId:
              _placeId != null && _placeId == widget.initialPlaceId
              ? widget.initialVisitVerificationId
              : null,
          date: dateStr,
          title: title.isEmpty ? null : title,
          body: body,
          imageUrls: finalImageUrls,
        );
        message = result.message;
      }
      if (!mounted) return;
      _snack(message);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgHeight = MediaQuery.sizeOf(context).width / (1587 / 991);
    final fadeHeight = bgHeight * 0.3;
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: Text(widget.editing ? '발자국 수정하기' : '발자국 남기기'),
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Image.asset(
              'assets/illustrations/scenes/diary_bg.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
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
                _Header(editing: widget.editing),
                SizedBox(height: (bgHeight * 0.65).clamp(96.0, 200.0)),
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
                      TextField(
                        controller: _placeController,
                        enabled: !_submitting,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          hintText: '장소 이름을 입력해주세요',
                          prefixIcon: Icon(Symbols.edit_location_alt_rounded),
                        ),
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
                          Text('최대 $_maxPhotos장', style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _PhotoStrip(
                        photoAssets: _photoAssets,
                        selectedPhotos: _selectedPhotos,
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
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
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
        Text(
          editing ? '그날의 기록을 다시 들여다볼까요.' : '여행의 순간을 차근차근 기록해보세요.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
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

/// 값 + 우측 펼침 표시(∨) 형태의 탭 가능한 상자 — 날짜 선택에 쓴다.
class _PickerBox extends StatelessWidget {
  const _PickerBox({
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final VoidCallback onTap;

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
                  color: AppColors.textPrimary,
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
/// [photoAssets]는 세 종류의 키를 섞어서 담는다: 이미 서버에 올라간 기존
/// 사진(원격 URL, 수정 화면 진입 시 채워짐 — [selectedPhotos]엔 없다),
/// 갤러리에서 새로 고른 사진과 번들 에셋(둘 다 [selectedPhotos]에 바이트로
/// 있음, 로컬 파일 경로/에셋 경로가 키), 아직 안 읽힌 번들 에셋(로딩 중이라
/// [selectedPhotos]엔 아직 없음 — 자기 자신을 [AssetImage]로 보여준다).
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photoAssets,
    required this.selectedPhotos,
    required this.onRemove,
    required this.onAdd,
  });

  final List<String> photoAssets;
  final Map<String, MemoryImage> selectedPhotos;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  ImageProvider _resolveImage(String key) {
    final bytes = selectedPhotos[key];
    if (bytes != null) return bytes;
    if (key.startsWith('http://') || key.startsWith('https://')) {
      return NetworkImage(key);
    }
    return AssetImage(key);
  }

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
            return _AddTile(width: tileWidth, height: tileHeight, onTap: onAdd);
          }
          return SizedBox(
            width: tileWidth,
            height: tileHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.inputField),
                  child: Image(
                    image: _resolveImage(photoAssets[i]),
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
                        border: Border.all(
                          color: AppColors.surface,
                          width: 1.5,
                        ),
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
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
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
