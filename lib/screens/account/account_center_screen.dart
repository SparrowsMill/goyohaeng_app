import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_user.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/app_password_field.dart';
import '../../widgets/app_text_field.dart';

const _labelWidth = 88.0;

class AccountCenterScreen extends StatefulWidget {
  const AccountCenterScreen({super.key});

  @override
  State<AccountCenterScreen> createState() => _AccountCenterScreenState();
}

class _AccountCenterScreenState extends State<AccountCenterScreen> {
  final _nameController = TextEditingController(text: mockUserProfile.name);

  String _gender = mockUserProfile.gender;
  DateTime? _birthDate = mockUserProfile.birthDate;

  bool _promotionAlerts = true;
  bool _nearbyRecommendationAlerts = true;
  bool _activityAlerts = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _birthDateText {
    final date = _birthDate;
    if (date == null) return '생년월일';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y. $m. $d';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _copyId(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('아이디가 복사되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/illustrations/scenes/account_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Symbols.arrow_back_rounded),
                    color: AppColors.textPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text('계정 센터', style: AppTextStyles.h1),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '프로필, 계정 정보, 설정을\n한국에서 편리하게 관리해요.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  // Clears the watercolor illustration baked into the top of
                  // account_bg.png before the first card starts.
                  const SizedBox(height: 150),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: AppDecorations.card(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _CardHeader(
                          icon: Symbols.person_rounded,
                          label: '프로필 관리',
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            ClipOval(
                              child: Image.asset(
                                'assets/illustrations/sparrow/sparrow_default.png',
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mockUserProfile.name, style: AppTextStyles.h3),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '여행을 기록하고 추억을 남겨보세요.',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _LabeledRow(
                          label: '이름',
                          child: AppTextField(
                            controller: _nameController,
                            hintText: '이름',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _LabeledRow(
                          label: '생년월일',
                          child: _ValueBox(
                            value: _birthDateText,
                            trailingIcon: Symbols.calendar_month_rounded,
                            onTrailingTap: _pickBirthDate,
                            onTap: _pickBirthDate,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _LabeledRow(
                          label: '성별',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _GenderChip(
                                label: '남성',
                                selected: _gender == 'male',
                                onTap: () => setState(() => _gender = 'male'),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _GenderChip(
                                label: '여성',
                                selected: _gender == 'female',
                                onTap: () => setState(() => _gender = 'female'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: AppDecorations.card(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _CardHeader(
                          icon: Symbols.shield_rounded,
                          label: '계정 정보',
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _LabeledRow(
                          label: '아이디 확인',
                          child: _ValueBox(
                            value: mockUserProfile.id,
                            trailingIcon: Symbols.content_copy_rounded,
                            onTrailingTap: () => _copyId(mockUserProfile.id),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _LabeledRow(
                          label: '비밀번호 변경',
                          alignTop: true,
                          child: Column(
                            children: const [
                              AppPasswordField(hintText: '새 비밀번호'),
                              SizedBox(height: AppSpacing.sm),
                              AppPasswordField(hintText: '비밀번호 확인'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _LabeledRow(
                          label: '회원 탈퇴',
                          labelColor: AppColors.error,
                          onLabelTap: () {
                            // * TODO(backend): 회원 탈퇴 플로우 연동 필요
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorBackground,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.inputField),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Symbols.warning_rounded,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    '회원 탈퇴 시 모든 데이터가 삭제됩니다.',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: AppDecorations.card(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _CardHeader(
                          icon: Symbols.settings_rounded,
                          label: '설정',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SettingRow(
                          icon: Symbols.campaign_rounded,
                          title: '프로모션 알림',
                          subtitle: '이벤트, 프로모션 소식을 받아봐요.',
                          value: _promotionAlerts,
                          onChanged: (v) => setState(() => _promotionAlerts = v),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SettingRow(
                          icon: Symbols.location_on_rounded,
                          title: '인근 관광 추천 알림',
                          subtitle: '내 주변 인기 관광지를 추천받아요.',
                          value: _nearbyRecommendationAlerts,
                          onChanged: (v) =>
                              setState(() => _nearbyRecommendationAlerts = v),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SettingRow(
                          icon: Symbols.notifications_rounded,
                          title: '기록 글쓰기 알림',
                          subtitle: '댓글, 좋아요 등 활동 알림을 받아봐요.',
                          value: _activityAlerts,
                          onChanged: (v) => setState(() => _activityAlerts = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: () {
                      // * TODO(backend): 로그아웃 처리 및 로그인 화면으로 이동 필요
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                        vertical: AppSpacing.lg,
                      ),
                      decoration: AppDecorations.card(),
                      child: Row(
                        children: [
                          const Icon(
                            Symbols.logout_rounded,
                            size: 20,
                            color: AppColors.iconPrimary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '로그아웃',
                            style: AppTextStyles.bodyLarge
                                .copyWith(fontWeight: FontWeight.w600),
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
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }
}

/// Circular icon badge + title used atop each card ("프로필 관리", "계정 정보", "설정").
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.surfaceSelected,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.title),
      ],
    );
  }
}

/// Fixed-width label to the left of a field/value/control, matching the
/// mockup's two-column row layout used throughout the account center cards.
class _LabeledRow extends StatelessWidget {
  const _LabeledRow({
    required this.label,
    required this.child,
    this.labelColor = AppColors.textPrimary,
    this.alignTop = false,
    this.onLabelTap,
  });

  final String label;
  final Widget child;
  final Color labelColor;
  final bool alignTop;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: AppTextStyles.bodyLarge
          .copyWith(color: labelColor, fontWeight: FontWeight.w600),
    );

    return Row(
      crossAxisAlignment:
          alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(top: alignTop ? 14.0 : 0),
          child: SizedBox(
            width: _labelWidth,
            child: onLabelTap == null
                ? labelText
                : GestureDetector(onTap: onLabelTap, child: labelText),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Read-only bordered field — the same visual language as the app's real
/// input fields, for values that aren't directly editable (e.g. 아이디 확인)
/// or that open a picker instead of a keyboard (e.g. 생년월일).
class _ValueBox extends StatelessWidget {
  const _ValueBox({
    required this.value,
    this.trailingIcon,
    this.onTrailingTap,
    this.onTap,
  });

  final String value;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onTap;

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
            Expanded(
              child: Text(value, style: AppTextStyles.bodyLarge),
            ),
            if (trailingIcon != null)
              InkWell(
                onTap: onTrailingTap,
                child: Icon(
                  trailingIcon,
                  size: 20,
                  color: AppColors.iconInactive,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
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
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppRadius.smallButton),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonMedium.copyWith(
            color: selected
                ? AppColors.textOnPrimaryButton
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: AppColors.iconPrimary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        // Track/thumb colors come from the theme's `colorScheme.primary`
        // (green) / `onPrimary` (white) — matches the design system without
        // per-instance overrides.
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
