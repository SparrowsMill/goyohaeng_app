import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Password input with a show/hide toggle — CLAUDE.md §7 Input Field, §6 Icons.
/// Wraps [TextFormField] so it participates in an ancestor [Form]'s validation.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.hintText,
    this.controller,
    this.validator,
    this.onChanged,
    this.style,
    this.contentPadding,
  });

  final String hintText;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  /// Defaults to Input Field's spec size (Body Large). Only override at a
  /// call site that deliberately needs a smaller/larger field.
  final TextStyle? style;

  /// Defaults to the app theme's Input Field padding. Only override at a
  /// call site that deliberately needs a more compact field.
  final EdgeInsetsGeometry? contentPadding;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      onChanged: widget.onChanged,
      obscureText: _obscure,
      style: widget.style ?? AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hintText,
        contentPadding: widget.contentPadding,
        prefixIcon: const Icon(
          Symbols.lock_rounded,
          size: 20,
          color: AppColors.iconInactive,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 20),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Symbols.visibility_off_rounded : Symbols.visibility_rounded,
            size: 20,
            color: AppColors.iconInactive,
          ),
        ),
      ),
    );
  }
}
