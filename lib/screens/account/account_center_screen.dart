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
import '../../widgets/app_password_field.dart';
import '../../widgets/app_text_field.dart';
import '../auth/login_screen.dart';
import '../map/map_screen.dart';
import '../ranking/ranking_screen.dart';
import '../record/my_footprint_screen.dart';

const _labelWidth = 88.0;

/// `<계정 센터>` (user_flow §3) — `/users/me`(스펙 §3)를 조회해 프로필/계정 정보를
/// 보여주고, 각 카드의 저장·변경·탈퇴·로그아웃을 백엔드에 반영한다.
class AccountCenterScreen extends StatefulWidget {
  const AccountCenterScreen({super.key});

  @override
  State<AccountCenterScreen> createState() => _AccountCenterScreenState();
}

class _AccountCenterScreenState extends State<AccountCenterScreen> {
  final _userService = UserService();

  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = true;
  String? _loadError;

  Me? _me;
  String? _gender; // 'MALE' | 'FEMALE'
  DateTime? _birthDate;

  bool _savingProfile = false;
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final me = await _userService.getMe();
      AuthStore.instance.updateMe(me);
      if (!mounted) return;
      setState(() {
        _me = me;
        _nameController.text = me.realName;
        _gender = me.gender;
        _birthDate = me.birthDateTime;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
      if (e.isUnauthorized) _goToLogin();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String get _birthDateText {
    final date = _birthDate;
    if (date == null) return '생년월일';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y. $m. $d';
  }

  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _copyId(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    _snack('아이디가 복사되었습니다.');
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _snack('이름을 정확히 입력해주세요');
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final me = await _userService.updateMe(
        realName: name,
        birthDate: _birthDate == null ? null : _apiDate(_birthDate!),
        gender: _gender,
      );
      AuthStore.instance.updateMe(me);
      if (!mounted) return;
      setState(() => _me = me);
      _snack('프로필을 저장했어요.');
    } on ApiException catch (e) {
      _snack(e.message);
      if (e.isUnauthorized) _goToLogin();
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (current.isEmpty) {
      _snack('현재 비밀번호를 입력해주세요');
      return;
    }
    if (next.length < 8) {
      _snack('새 비밀번호는 8자 이상이어야 해요');
      return;
    }
    if (next != confirm) {
      _snack('새 비밀번호가 일치하지 않아요');
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await _userService.changePassword(
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      FocusScope.of(context).unfocus();
      _snack('비밀번호를 변경했어요.');
    } on ApiException catch (e) {
      _snack(e.message);
      if (e.isUnauthorized) _goToLogin();
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _confirmWithdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('회원 탈퇴 시 모든 데이터가 삭제됩니다.\n정말 탈퇴하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('탈퇴', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _userService.deleteMe();
      await AuthStore.instance.signOut();
      if (!mounted) return;
      _snack('회원 탈퇴가 완료되었습니다.');
      _goToLogin();
    } on ApiException catch (e) {
      _snack(e.message);
      if (e.isUnauthorized) {
        await AuthStore.instance.signOut();
        _goToLogin();
      }
    }
  }

  Future<void> _logout() async {
    await AuthStore.instance.signOut();
    if (!mounted) return;
    _goToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Top-anchored scene band like the other `*_bg` screens (login /
          // 마이페이지): natural aspect via `fitWidth`, `#FAE7C0` shows through
          // below it. Not full-bleed `cover` (which crops the sides).
          Align(
            alignment: Alignment.topCenter,
            child: Image.asset(
              'assets/illustrations/scenes/setting_bg.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _loadError != null
                    ? _ErrorState(message: _loadError!, onRetry: _load)
                    : _buildContent(),
          ),
          // Fixed back button (does not scroll), same circular chip as the
          // auth screens — pinned to the top-left corner.
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
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RankingScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyFootprintScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildContent() {
    final me = _me!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pushes past the watercolor illustration baked into the top of
          // setting_bg.png so the heading + first card start below the band.
          const SizedBox(height: 238),
          Text('계정 센터', style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.md),

          // ---------- 프로필 관리 ----------
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
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 72,
                          height: 72,
                          color: AppColors.surfaceSelected,
                          child: const Icon(
                            Symbols.flutter_dash_rounded,
                            size: 36,
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
                          Text(
                            me.realName.isEmpty ? me.username : me.realName,
                            style: AppTextStyles.h3,
                          ),
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
                        selected: _gender == 'MALE',
                        onTap: () => setState(() => _gender = 'MALE'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _GenderChip(
                        label: '여성',
                        selected: _gender == 'FEMALE',
                        onTap: () => setState(() => _gender = 'FEMALE'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _CardActionButton(
                  label: '프로필 저장',
                  busy: _savingProfile,
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---------- 계정 정보 ----------
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
                    value: me.username,
                    trailingIcon: Symbols.content_copy_rounded,
                    onTrailingTap: () => _copyId(me.username),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _LabeledRow(
                  label: '비밀번호 변경',
                  alignTop: true,
                  child: Column(
                    children: [
                      AppPasswordField(
                        controller: _currentPasswordController,
                        hintText: '현재 비밀번호',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppPasswordField(
                        controller: _newPasswordController,
                        hintText: '새 비밀번호 (8자 이상)',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppPasswordField(
                        controller: _confirmPasswordController,
                        hintText: '새 비밀번호 확인',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CardActionButton(
                        label: '비밀번호 변경',
                        busy: _savingPassword,
                        onPressed: _changePassword,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _LabeledRow(
                  label: '회원 탈퇴',
                  labelColor: AppColors.error,
                  onLabelTap: _confirmWithdraw,
                  child: InkWell(
                    onTap: _confirmWithdraw,
                    borderRadius: BorderRadius.circular(AppRadius.inputField),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: _logout,
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
    );
  }
}

/// 카드 안에서 쓰는 컴팩트한 채움 버튼 (프로필 저장 / 비밀번호 변경).
class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          textStyle: AppTextStyles.buttonMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
          ),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnPrimaryButton,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.cloud_off_rounded,
                size: 40, color: AppColors.iconInactive),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
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
