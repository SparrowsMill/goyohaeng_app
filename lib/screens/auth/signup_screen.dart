import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_password_field.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/leaf_section_header.dart';
import 'auth_page_background.dart';
import 'terms_content.dart';
import 'terms_detail_screen.dart';

final _idPattern = RegExp(r'^[a-zA-Z0-9]{4,20}$');
final _passwordPattern = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,20}$');
final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
final _phoneDigitsPattern = RegExp(r'^01[016789]\d{7,8}$');

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _gender;
  DateTime? _birthDate;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;

  bool _idChecking = false;
  String? _idCheckedValue;
  bool _submitting = false;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _idController.addListener(_resetIdCheckIfChanged);
    // Re-validate the confirm-password field whenever the password changes,
    // since its validator reads the password field's current value.
    _passwordController.addListener(() {
      _formKey.currentState?.validate();
    });
  }

  @override
  void dispose() {
    _idController.removeListener(_resetIdCheckIfChanged);
    _idController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _resetIdCheckIfChanged() {
    if (_idCheckedValue != null && _idController.text != _idCheckedValue) {
      setState(() => _idCheckedValue = null);
    }
  }

  String? _validateId(String? value) {
    final id = value?.trim() ?? '';
    if (id.isEmpty) return '아이디를 입력해주세요';
    if (!_idPattern.hasMatch(id)) return '영문, 숫자 4~20자로 입력해주세요';
    if (_idCheckedValue != id) return '중복확인을 진행해주세요';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '비밀번호를 입력해주세요';
    if (!_passwordPattern.hasMatch(password)) {
      return '영문, 숫자를 포함해 8~20자로 입력해주세요';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final confirm = value ?? '';
    if (confirm.isEmpty) return '비밀번호를 다시 입력해주세요';
    if (confirm != _passwordController.text) return '비밀번호가 일치하지 않습니다';
    return null;
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return '이름을 입력해주세요';
    if (name.length < 2) return '이름을 정확히 입력해주세요';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일을 입력해주세요';
    if (!_emailPattern.hasMatch(email)) return '올바른 이메일 형식으로 입력해주세요';
    return null;
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll('-', '');
    if (digits.isEmpty) return '전화번호를 입력해주세요';
    if (!_phoneDigitsPattern.hasMatch(digits)) return '올바른 휴대폰 번호를 입력해주세요';
    return null;
  }

  Future<void> _checkIdDuplicate() async {
    final id = _idController.text.trim();
    if (!_idPattern.hasMatch(id)) {
      _formKey.currentState?.validate();
      return;
    }
    setState(() => _idChecking = true);
    bool? available;
    String message;
    try {
      available = await _authService.isUsernameAvailable(id);
      message = available ? '사용 가능한 아이디입니다.' : '이미 사용 중인 아이디입니다.';
    } on ApiException catch (e) {
      message = e.isConflict ? '이미 사용 중인 아이디입니다.' : e.message;
      if (e.isConflict) available = false;
    }
    if (!mounted) return;
    setState(() {
      _idChecking = false;
      _idCheckedValue = available == true ? id : null;
    });
    _formKey.currentState?.validate();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  String get _birthDateText {
    final date = _birthDate;
    if (date == null) return '생년월일';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _handleSignup() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (_birthDate == null) {
      _snack('생년월일을 선택해주세요');
      return;
    }
    if (_gender == null) {
      _snack('성별을 선택해주세요');
      return;
    }
    if (!_agreeTerms || !_agreePrivacy) {
      _snack('필수 약관에 동의해주세요');
      return;
    }

    final username = _idController.text.trim();
    final password = _passwordController.text;

    setState(() => _submitting = true);
    try {
      final result = await _authService.signup(
        username: username,
        password: password,
        realName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        birthDate: _formatDate(_birthDate!),
        gender: _gender == 'male' ? 'MALE' : 'FEMALE',
      );
      // 가입 성공 → 자동 로그인하지 않고 로그인 화면으로 돌아가 직접 입력하게 한다.
      // 방금 만든 아이디 + 서버 안내 메시지를 채워서 넘긴다.
      if (!mounted) return;
      Navigator.of(context).pop((username: username, message: result.message));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        setState(() => _idCheckedValue = null);
        _formKey.currentState?.validate();
      }
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageBackground(
      showLogo: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: AppDecorations.elevatedCard(),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LeafSectionHeader(label: '회원가입'),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _idController,
                        hintText: '아이디',
                        prefixIcon: Symbols.person_rounded,
                        validator: _validateId,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.smallButton),
                          ),
                          textStyle: AppTextStyles.buttonMedium,
                        ),
                        onPressed: _idChecking ? null : _checkIdDuplicate,
                        child: _idChecking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('중복확인'),
                      ),
                    ),
                  ],
                ),
                if (_idCheckedValue != null && _idCheckedValue == _idController.text)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '사용 가능한 아이디입니다.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.success),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                AppPasswordField(
                  controller: _passwordController,
                  hintText: '비밀번호',
                  validator: _validatePassword,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppPasswordField(
                  controller: _confirmPasswordController,
                  hintText: '비밀번호 확인',
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _nameController,
                  hintText: '이름',
                  prefixIcon: Symbols.person_rounded,
                  validator: _validateName,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _emailController,
                  hintText: '이메일',
                  prefixIcon: Symbols.mail_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _phoneController,
                  hintText: '전화번호',
                  prefixIcon: Symbols.call_rounded,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_PhoneNumberFormatter()],
                  validator: _validatePhone,
                ),
                const SizedBox(height: AppSpacing.lg),
                _BirthDateField(
                  label: _birthDateText,
                  isSet: _birthDate != null,
                  onTap: _pickBirthDate,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Icon(
                      Symbols.wc_rounded,
                      size: 20,
                      color: AppColors.iconInactive,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '성별',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
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
                const SizedBox(height: AppSpacing.xxl),
                _ConsentRow(
                  label: '이용약관에 동의합니다.',
                  requiredTag: true,
                  value: _agreeTerms,
                  onChanged: (value) => setState(() => _agreeTerms = value),
                  onViewPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TermsDetailScreen(
                        title: '이용약관',
                        body: termsOfServiceText,
                      ),
                    ),
                  ),
                ),
                _ConsentRow(
                  label: '개인정보 수집 및 이용에 동의합니다.',
                  requiredTag: true,
                  value: _agreePrivacy,
                  onChanged: (value) => setState(() => _agreePrivacy = value),
                  onViewPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TermsDetailScreen(
                        title: '개인정보 수집 및 이용 동의',
                        body: privacyConsentText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: (_submitting || !_agreeTerms || !_agreePrivacy)
                      ? null
                      : _handleSignup,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimaryButton,
                          ),
                        )
                      : const Text('회원가입'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Formats digits into the `010-1234-5678` grouping as the user types, and
/// discards any non-digit input (e.g. pasted formatting).
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      final isGroupBoundary = i == 2 || i == 6;
      if (isGroupBoundary && i != limited.length - 1) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _BirthDateField extends StatelessWidget {
  const _BirthDateField({
    required this.label,
    required this.isSet,
    required this.onTap,
  });

  final String label;
  final bool isSet;
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
            const Icon(
              Symbols.calendar_month_rounded,
              size: 20,
              color: AppColors.iconInactive,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isSet ? AppColors.textPrimary : AppColors.textDisabled,
                ),
              ),
            ),
            const Icon(
              Symbols.calendar_month_rounded,
              size: 20,
              color: AppColors.iconInactive,
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

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.label,
    required this.requiredTag,
    required this.value,
    required this.onChanged,
    required this.onViewPressed,
  });

  final String label;
  final bool requiredTag;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onViewPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: value,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodySmall,
                children: [
                  TextSpan(text: label),
                  TextSpan(
                    text: requiredTag ? ' (필수)' : ' (선택)',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onViewPressed,
            child: Text(
              '보기',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
