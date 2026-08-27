/// How badly a form answer combination reads.
enum FormIssueSeverity {
  /// Blocks saving.
  error,

  /// Shown inline, saving still allowed.
  warning,
}

/// One problem found against a whole answer map.
class FormIssue {
  const FormIssue({
    required this.fieldId,
    required this.message,
    this.severity = FormIssueSeverity.error,
  });

  const FormIssue.warning({required this.fieldId, required this.message})
    : severity = FormIssueSeverity.warning;

  final String fieldId;
  final String message;
  final FormIssueSeverity severity;
}

/// Checks answers that only make sense together.
typedef CrossFieldRule = List<FormIssue> Function(Map<String, dynamic> values);
