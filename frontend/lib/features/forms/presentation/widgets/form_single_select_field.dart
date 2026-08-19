import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/form_field_schema.dart';

const _kErrorColor = Color(0xFFB3261E);

/// Renders a [FormFieldType.singleSelect] field as a row of [ChoiceChip]s,
/// matching the selection style already used for appointment time slots
/// (see `doctor_profile_screen.dart`).
class FormSingleSelectField extends StatelessWidget {
  const FormSingleSelectField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final FormFieldSchema field;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(field: field),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: field.options.map((option) {
            final isSelected = option.value == value;
            return ChoiceChip(
              label: Text(option.label),
              selected: isSelected,
              selectedColor: AppColors.rose,
              backgroundColor: AppColors.bgAlt,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.white : AppColors.text,
                fontWeight: FontWeight.w600,
              ),
              side: hasError ? const BorderSide(color: _kErrorColor) : null,
              // Tapping the already-selected chip clears it — the field may
              // be optional (e.g. smokingStatus) and there's otherwise no
              // way back to "unanswered".
              onSelected: (_) => onChanged(isSelected ? null : option.value),
            );
          }).toList(),
        ),
        _FieldFooter(field: field, errorText: errorText),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.field});

  final FormFieldSchema field;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTypography.labelLarge(),
        children: [
          TextSpan(text: field.label),
          if (field.required)
            TextSpan(
              text: ' *',
              style: AppTypography.labelLarge(color: AppColors.rose),
            ),
        ],
      ),
    );
  }
}

class _FieldFooter extends StatelessWidget {
  const _FieldFooter({required this.field, required this.errorText});

  final FormFieldSchema field;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final text = errorText ?? field.helpText;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: AppTypography.bodySmall(
          color: errorText != null ? _kErrorColor : AppColors.textMuted,
        ),
      ),
    );
  }
}
