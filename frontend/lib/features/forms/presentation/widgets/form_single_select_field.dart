import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/form_field_schema.dart';

const _kErrorColor = Color(0xFFB3261E);

/// Renders singleSelect as a radio-cell grid.
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
        _FieldHeader(field: field, hasError: hasError),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: field.options.map((option) {
            final selected = option.value == value;
            return _RadioCell(
              label: option.label,
              selected: selected,
              hasError: hasError,
              // Tap again to clear an optional field.
              onTap: () => onChanged(selected ? null : option.value),
            );
          }).toList(),
        ),
        _FieldFooter(field: field, errorText: errorText),
      ],
    );
  }
}

class _FieldHeader extends StatelessWidget {
  const _FieldHeader({required this.field, required this.hasError});

  final FormFieldSchema field;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: hasError ? _kErrorColor : AppColors.rose,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        RichText(
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
        ),
      ],
    );
  }
}

class _RadioCell extends StatelessWidget {
  const _RadioCell({
    required this.label,
    required this.selected,
    required this.hasError,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? _kErrorColor
        : selected
        ? AppColors.borderRose
        : AppColors.border;
    return Material(
      color: selected ? AppColors.rosePale : AppColors.bgAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.rose : AppColors.borderRose,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.rose,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium(
                  color: selected ? AppColors.roseDark : AppColors.textSub,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: AppTypography.bodySmall(
          color: errorText != null ? _kErrorColor : AppColors.textMuted,
        ),
      ),
    );
  }
}
