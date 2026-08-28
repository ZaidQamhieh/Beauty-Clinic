import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_dialog.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../forms/data/clinical_intake_api.dart';
import '../../../forms/data/clinical_intake_schema.dart';
import '../../../forms/data/dynamic_form_api.dart';
import '../../../forms/domain/form_controller.dart';
import '../../../forms/presentation/dynamic_form_renderer.dart';

/// Renders a patient's clinical intake form.
class ClinicalIntakeTab extends StatefulWidget {
  final ClinicalIntakeApi? clinicalApi;
  final DynamicFormApi? dynamicApi;
  final String? patientId;
  final bool readOnly;
  final VoidCallback? onBackToAppointments;
  final VoidCallback? onSaved;

  const ClinicalIntakeTab({
    super.key,
    this.clinicalApi,
    this.dynamicApi,
    this.patientId,
    this.readOnly = false,
    this.onBackToAppointments,
    this.onSaved,
  }) : assert(
         patientId == null ? dynamicApi != null : clinicalApi != null,
         'Own intake needs dynamicApi; staff editing needs clinicalApi',
       );

  @override
  State<ClinicalIntakeTab> createState() => _ClinicalIntakeTabState();
}

class _ClinicalIntakeTabState extends State<ClinicalIntakeTab> {
  late final DynamicFormController _controller;
  bool _isLoading = true;
  String? _error;
  bool _isSaving = false;
  bool _controllerInitialized = false;
  Map<String, dynamic> _initialValues = {};

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    if (_controllerInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadForm() async {
    try {
      if (widget.patientId == null) {
        final schema = widget.dynamicApi != null
            ? await widget.dynamicApi!.fetchPublishedSchema()
            : ClinicalIntakeSchema.schema;
        Map<String, dynamic> answers = {};
        if (widget.clinicalApi != null) {
          try {
            answers = await widget.clinicalApi!.fetchOwn();
          } catch (_) {}
        }
        if (widget.dynamicApi != null) {
          try {
            final dynamicAnswers = await widget.dynamicApi!.fetchOwnAnswers();
            answers = {...answers, ...dynamicAnswers};
          } catch (_) {}
        }
        final initialValues = {...schema.defaultValues(), ...answers};

        if (!mounted) return;

        _initialValues = initialValues;
        _controller = DynamicFormController(
          schema: schema,
          initialValues: initialValues,
        );
      } else {
        Map<String, dynamic> values;
        try {
          values = await widget.clinicalApi!.fetchForPatient(widget.patientId!);
        } catch (_) {
          // No prior record: use schema defaults.
          values = ClinicalIntakeSchema.schema.defaultValues();
        }

        if (!mounted) return;

        _initialValues = values;
        _controller = DynamicFormController(
          schema: ClinicalIntakeSchema.schema,
          initialValues: values,
        );
      }

      _controllerInitialized = true;

      setState(() {
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load clinic forms: $e';
      });
    }
  }

  void _handleCancel() {
    _controller.reset(_initialValues);
  }

  Future<void> _handleSave() async {
    if (!_controller.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Drops answers to unseen questions.
      final pruned = _controller.schema.pruneHidden(_controller.values);
      final fieldKeys = _controller.schema.fields.map((f) => f.id).toSet();
      final cleanValues = Map<String, dynamic>.fromEntries(
        pruned.entries.where((e) => fieldKeys.contains(e.key)),
      );

      if (widget.patientId == null) {
        if (widget.dynamicApi != null) {
          await widget.dynamicApi!.saveOwnAnswers(cleanValues);
        } else if (widget.clinicalApi != null) {
          await widget.clinicalApi!.saveOwn(cleanValues);
        }
      } else {
        await widget.clinicalApi!.saveForPatient(
          widget.patientId!,
          cleanValues,
        );
      }

      if (!mounted) return;

      _initialValues = {..._controller.values};
      _controller.markSaved();
      widget.onSaved?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Clinical intake form saved successfully!'),
          backgroundColor: AppColors.sage,
          action: widget.onBackToAppointments != null
              ? SnackBarAction(
                  label: 'Back to Appointments',
                  textColor: Colors.white,
                  onPressed: widget.onBackToAppointments!,
                )
              : null,
        ),
      );

      setState(() => _isSaving = false);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      showErrorDialog(context, 'Failed to save clinic forms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SkeletonList();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.rose),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTypography.bodySmall(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadForm();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final isReadOnly = widget.readOnly || widget.patientId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            children: [
              DynamicFormRenderer(
                controller: _controller,
                readOnly: isReadOnly,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!isReadOnly)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _buildActions(),
          ),
      ],
    );
  }

  Widget _buildActions() {
    final dirty = _controller.isDirty;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving || !dirty ? null : _handleCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSub,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel edits'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSaving || !dirty ? null : _handleSave,
            icon: _isSaving ? null : const Icon(Icons.check, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.textMuted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            label: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Save Clinical Form',
                    style: AppTypography.labelLarge(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}
