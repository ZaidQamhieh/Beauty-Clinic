import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/form_field_schema.dart';

// Local until a shared state color exists.
const _kErrorColor = Color(0xFFB3261E);

/// Renders boolean fields as a switch row.
class FormBooleanField extends StatelessWidget {
  const FormBooleanField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final FormFieldSchema field;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      activeThumbColor: AppColors.rose,
      onChanged: onChanged,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.rose,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(field.label, style: AppTypography.labelLarge()),
        ],
      ),
      subtitle: _subtitle(),
    );
  }

  Widget? _subtitle() {
    if (errorText != null) {
      return Text(
        errorText!,
        style: AppTypography.bodySmall(color: _kErrorColor),
      );
    }
    if (field.helpText != null) {
      return Text(field.helpText!, style: AppTypography.bodySmall());
    }
    return null;
  }
}
