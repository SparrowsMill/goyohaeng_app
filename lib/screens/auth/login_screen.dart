import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_password_field.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/leaf_section_header.dart';
import 'auth_page_background.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _keepSignedIn = false;

  @override
  Widget build(BuildContext context) {
    return AuthPageBackground(
      showBackButton: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: AppDecorations.elevatedCard(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LeafSectionHeader(label: '로그인'),
                  const SizedBox(height: AppSpacing.xxl),
                  const AppTextField(
                    hintText: '이메일 또는 아이디',
                    prefixIcon: Symbols.person_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AppPasswordField(hintText: '비밀번호'),
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
                        // * TODO(backend): 비밀번호 찾기 API 연동 필요
                        onPressed: () {},
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
                    // * TODO(backend): 로그인 API 연동 및 로그인 후 이동할 홈 화면 구현 필요
                    onPressed: () {},
                    child: const Text('로그인'),
                  ),
                ],
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
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  ),
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
