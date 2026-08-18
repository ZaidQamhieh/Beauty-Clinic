import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/form_field_schema.dart';

const _kErrorColor = Color(0xFFB3261E);

/// Renders a [FormFieldType.multiSelect] field as a row of [FilterChip]s,
/// matching the product ingredient picker's style
/// (see `product_catalog_screen.dart`).
class FormMultiSelectField extends StatelessWidget {
  const FormMultiSelectField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final FormFieldSchema field;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label, style: AppTypography.labelLarge()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: field.options.map((option) {
            final selected = value.contains(option.value);
            return FilterChip(
              label: Text(option.label),
              selected: selected,
              selectedColor: AppColors.rosePale,
              checkmarkColor: AppColors.roseDark,
              onSelected: (isSelected) {
                final next = [...value];
                isSelected ? next.add(option.value) : next.remove(option.value);
                onChanged(next);
              },
            );
          }).toList(),
        ),
        _Footer(field: field, count: value.length, errorText: errorText),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.field,
    required this.count,
    required this.errorText,
  });

  final FormFieldSchema field;
  final int count;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    if (errorText != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          errorText!,
          style: AppTypography.bodySmall(color: _kErrorColor),
        ),
      );
    }
    final cap = field.maxSelections;
    final helpText = field.helpText;
    final capNote = cap != null ? '$count / $cap selected' : null;
    final text = [
      ?helpText,
      ?capNote,
    ].join(' · ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: AppTypography.bodySmall()),
    );
  }
}
