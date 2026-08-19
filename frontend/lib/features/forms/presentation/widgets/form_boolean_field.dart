import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/form_field_schema.dart';

/// Semantic error red. Not in [AppColors] yet — every other token there is
/// a brand color, not a state color — so it's kept local to the forms
/// feature until a shared one exists.
const _kErrorColor = Color(0xFFB3261E);

/// Renders a [FormFieldType.boolean] field as a themed switch row.
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
      title: Text(field.label, style: AppTypography.labelLarge()),
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
