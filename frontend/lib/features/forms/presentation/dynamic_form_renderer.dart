import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/form_controller.dart';
import '../domain/form_field_schema.dart';
import 'widgets/form_boolean_field.dart';
import 'widgets/form_multi_select_field.dart';
import 'widgets/form_single_select_field.dart';

/// Renders whatever [FormSchema] its [controller] holds.
class DynamicFormRenderer extends StatelessWidget {
  const DynamicFormRenderer({
    super.key,
    required this.controller,
    this.readOnly = false,
  });

  final DynamicFormController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: readOnly,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final field in controller.schema.fields) ...[
                _FieldCard(child: _buildField(field)),
                const SizedBox(height: 20),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildField(FormFieldSchema field) {
    final value = controller.values[field.id];
    final error = controller.touched ? controller.errors[field.id] : null;

    switch (field.type) {
      case FormFieldType.boolean:
        return FormBooleanField(
          field: field,
          value: value as bool? ?? false,
          errorText: error,
          onChanged: (v) => controller.setValue(field.id, v),
        );
      case FormFieldType.singleSelect:
        return FormSingleSelectField(
          field: field,
          value: value as String?,
          errorText: error,
          onChanged: (v) => controller.setValue(field.id, v),
        );
      case FormFieldType.multiSelect:
        return FormMultiSelectField(
          field: field,
          value: List<String>.from(value as List? ?? const []),
          errorText: error,
          onChanged: (v) => controller.setValue(field.id, v),
        );
    }
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
