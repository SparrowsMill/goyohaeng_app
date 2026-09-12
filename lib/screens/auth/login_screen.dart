import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_password_field.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/leaf_section_header.dart';
import '../mill/mill_home_screen.dart';
import 'auth_page_background.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _keepSignedIn = true;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 회원가입 화면으로. 가입에 성공하면 방금 만든 아이디를 받아 채우고,
  /// 비밀번호는 사용자가 직접 입력하도록 둔다.
  Future<void> _openSignup() async {
    final username = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
    if (!mounted || username == null) return;
    setState(() => _usernameController.text = username);
    _passwordController.clear();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('회원가입이 완료됐어요. 비밀번호를 입력해 로그인해 주세요.')),
      );
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await AuthStore.instance.logIn(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        keepSignedIn: _keepSignedIn,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MillHomeScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageBackground(
      showBackButton: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: AppDecorations.elevatedCard(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LeafSectionHeader(label: '로그인'),
                    const SizedBox(height: AppSpacing.xxl),
                    AppTextField(
                      controller: _usernameController,
                      hintText: '이메일 또는 아이디',
                      prefixIcon: Symbols.person_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? '아이디를 입력해주세요'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppPasswordField(
                      controller: _passwordController,
                      hintText: '비밀번호',
                      validator: (v) => (v == null || v.isEmpty)
                          ? '비밀번호를 입력해주세요'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _keepSignedIn,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (value) =>
                                setState(() => _keepSignedIn = value ?? false),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text('로그인 상태 유지', style: AppTextStyles.bodySmall),
                        const Spacer(),
                        TextButton(
                          // * TODO(backend): 비밀번호 찾기 API 미구현 (스펙 §10)
                          onPressed: () => ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(content: Text('비밀번호 찾기는 준비 중이에요.')),
                            ),
                          child: Text(
                            '비밀번호 찾기',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton(
                      onPressed: _submitting ? null : _login,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnPrimaryButton,
                              ),
                            )
                          : const Text('로그인'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(child: Divider(color: AppColors.divider)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    '또는',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.divider)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('계정이 없으신가요? ', style: AppTextStyles.bodyMedium),
                TextButton(
                  onPressed: _openSignup,
                  child: Text(
                    '회원가입',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.secondaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
