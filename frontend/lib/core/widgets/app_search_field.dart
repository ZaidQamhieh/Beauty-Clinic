import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// One search field for the whole app.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.hintText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 12),
  });

  final String? hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Shows a clear button when given.
  final VoidCallback? onClear;
  final bool autofocus;

  /// Height is the caller's; shape is not.
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    final text = controller?.text ?? '';
    final showClear = onClear != null && text.isNotEmpty;

    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: AppTypography.bodyMedium(),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: AppTypography.bodySmall(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.bgCard,
        contentPadding: contentPadding,
        prefixIcon: const Icon(
          Icons.search,
          size: 18,
          color: AppColors.textMuted,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        suffixIcon: showClear
            ? IconButton(
                tooltip: 'Clear',
                icon: const Icon(
                  Icons.close,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                onPressed: onClear,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 36),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.rose),
      ),
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
      borderSide: BorderSide(color: color),
    );
  }
}
