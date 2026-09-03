import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Section title flanked by the branded leaf ornament, mirrored on each side.
/// Used for card headings such as "로그인" / "회원가입".
class LeafSectionHeader extends StatelessWidget {
  const LeafSectionHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const leaf = Image(
      image: AssetImage('assets/branding/leaf_ornament.png'),
      width: 35,
      height: 35,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.flip(flipX: true, child: leaf),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.h3),
        const SizedBox(width: 8),
        leaf,
      ],
    );
  }
}
