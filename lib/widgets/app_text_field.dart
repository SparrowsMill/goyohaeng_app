import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Standard text input — CLAUDE.md §7 Input Field. Pulls border/radius/fill
/// from [AppTheme.light]'s `inputDecorationTheme`; only supply the parts that
/// vary per field. Wraps [TextFormField] so it participates in an ancestor
/// [Form]'s validation.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.controller,
    this.validator,
    this.inputFormatters,
    this.onChanged,
  });

  final String hintText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 20, color: AppColors.iconInactive),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 20),
      ),
    );
  }
}
