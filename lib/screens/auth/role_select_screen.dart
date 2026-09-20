import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/leaf_section_header.dart';
import '../account/admin_webview_screen.dart';
import 'auth_page_background.dart';
import 'login_screen.dart';

/// 로그인 화면 진입 전 갈림길 — 일반 소비자로 로그인할지, 가맹점 관리자
/// 모드(웹뷰로 띄우는 관리자 웹)로 들어갈지 고른다(`_Bootstrap`이 세션 없을 때
/// `LoginScreen` 대신 이 화면을 첫 화면으로 띄운다).
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthPageBackground(
      showBackButton: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: AppDecorations.elevatedCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LeafSectionHeader(label: '고요행 시작하기'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '이용하실 방식을 선택해주세요.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _RoleCard(
                icon: Symbols.person_rounded,
                title: '사용자로 시작하기',
                description: '장소를 둘러보고 방문을 기록해요.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _RoleCard(
                icon: Symbols.admin_panel_settings_rounded,
                title: '관리자로 로그인',
                description: '가맹점 관리 화면으로 이동해요.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminWebViewScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: AppDecorations.card(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSelected,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Symbols.chevron_right_rounded,
              size: 20,
              color: AppColors.iconInactive,
            ),
          ],
        ),
      ),
    );
  }
}
