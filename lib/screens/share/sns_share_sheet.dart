import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// `<SNS에 공유>` (user_flow §7) — 셰프의 주방 / 방문 인증 보상 화면의 "SNS 공유"
/// 에서 공통으로 쓰는 공유 대상 선택 모달. 대상을 고르면 해당 SNS 앱의 글쓰기
/// 화면으로 이동하고 완성 일러스트가 자동 첨부된다.
///
/// 뼈대만 구현 — 실제 SNS 앱 딥링크 / 공유 인텐트는 미구현이라 스낵바로 안내
/// 한다. "링크 복사"만 placeholder 링크를 클립보드에 복사한다.
///
/// * TODO: 각 SNS 앱 공유 인텐트 / 딥링크 연동 (일러스트·문구 자동 첨부).
/// * TODO(backend): 공유용 딥링크/URL 발급.
/// * TODO(asset): SNS 브랜드 로고 `assets/illustrations/icon/sns_{key}.png`
///   미납품 — 그 전까지 Material Symbol placeholder.
Future<void> showSnsShareSheet(BuildContext context) async {
  final choice = await showDialog<String>(
    context: context,
    barrierColor: const Color(0x8C1E160E),
    builder: (_) => const _SnsShareDialog(),
  );
  if (choice == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  if (choice == 'copy') {
    await Clipboard.setData(
      // * TODO(backend): 실제 공유 링크로 교체.
      const ClipboardData(text: 'https://goyohaeng.app/share'),
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('공유 링크가 복사되었어요.')),
    );
  } else {
    messenger.showSnackBar(
      SnackBar(content: Text('$choice 공유는 앱 연동 후 이용할 수 있어요.')),
    );
  }
}

class _SnsTarget {
  const _SnsTarget({required this.key, required this.label, required this.icon});

  final String key;
  final String label;
  final IconData icon;

  String get iconPath => 'assets/illustrations/icon/sns_$key.png';
}

const _targets = <_SnsTarget>[
  _SnsTarget(
    key: 'instagram',
    label: '인스타그램',
    icon: Symbols.photo_camera_rounded,
  ),
  _SnsTarget(key: 'kakaotalk', label: '카카오톡', icon: Symbols.chat_rounded),
  _SnsTarget(key: 'x', label: 'X', icon: Symbols.tag_rounded),
  _SnsTarget(key: 'blog', label: '블로그', icon: Symbols.article_rounded),
];

class _SnsShareDialog extends StatelessWidget {
  const _SnsShareDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.huge,
      ),
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.modal),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LeafLabel(label: '공유할 SNS를 선택하세요'),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(child: _SnsTile(target: _targets[0])),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _SnsTile(target: _targets[1])),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: _SnsTile(target: _targets[2])),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _SnsTile(target: _targets[3])),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _SnsTile(
              icon: Symbols.link_rounded,
              label: '링크 복사',
              onTap: () => Navigator.of(context).pop('copy'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Leaf(flip: false),
          ],
        ),
      ),
    );
  }
}

/// 공유 대상 한 칸 — 아이콘 + 이름. [target] 을 주면 그 대상으로 pop.
class _SnsTile extends StatelessWidget {
  const _SnsTile({this.target, this.icon, this.label, this.onTap})
      : assert(target != null || (icon != null && label != null && onTap != null));

  final _SnsTarget? target;
  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = target;
    final effectiveLabel = t?.label ?? label!;
    final effectiveTap =
        onTap ?? () => Navigator.of(context).pop(t!.label);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.listRow),
        onTap: effectiveTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.listRow),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: t == null
                    ? Icon(icon, size: 22, color: AppColors.primary)
                    : Image.asset(
                        t.iconPath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(t.icon, size: 22, color: AppColors.primary),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  effectiveLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 잎 장식 양옆 가운데 라벨.
class _LeafLabel extends StatelessWidget {
  const _LeafLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Leaf(flip: true),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.title,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _Leaf(flip: false),
      ],
    );
  }
}

/// 브랜드 잎 장식(작게). 아직 파일이 없을 때를 대비해 errorBuilder 로 대체.
class _Leaf extends StatelessWidget {
  const _Leaf({required this.flip});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/branding/leaf_ornament.png',
      width: 18,
      height: 18,
      errorBuilder: (context, error, stackTrace) => const SizedBox(width: 18),
    );
    return flip ? Transform.flip(flipX: true, child: img) : img;
  }
}
