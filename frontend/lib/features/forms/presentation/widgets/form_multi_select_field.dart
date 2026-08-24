import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/form_field_schema.dart';

const _kErrorColor = Color(0xFFB3261E);

/// Renders multiSelect as a checkbox grid.
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
    final cap = field.maxSelections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        if (cap != null)
          Padding(
            padding: const EdgeInsets.only(left: 11, top: 2, bottom: 10),
            child: Text(
              '${value.length} / $cap selected',
              style: AppTypography.bodySmall(color: AppColors.textMuted),
            ),
          )
        else
          const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: field.options.map((option) {
            final selected = value.contains(option.value);
            return _CheckCell(
              label: option.label,
              selected: selected,
              onTap: () {
                final next = [...value];
                selected ? next.remove(option.value) : next.add(option.value);
                onChanged(next);
              },
            );
          }).toList(),
        ),
        _Footer(field: field, errorText: errorText),
      ],
    );
  }
}

class _CheckCell extends StatelessWidget {
  const _CheckCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.rosePale : AppColors.bgAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.borderRose : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: selected ? AppColors.rose : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: selected ? AppColors.rose : AppColors.borderRose,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTypography.labelMedium(
                  color: selected ? AppColors.roseDark : AppColors.textSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.field, required this.errorText});

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
