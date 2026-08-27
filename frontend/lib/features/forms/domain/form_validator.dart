import 'form_field_schema.dart';
import 'form_issue.dart';
import 'form_schema.dart';

/// Re-derives, on the client, the same constraints the backend DTO enforces
/// with `jakarta.validation` (see `EditClinicalProfileRequest`) — so a bad
/// submission is caught before the round trip instead of only being
/// reported after it by a 400.
///
/// Kept independent of any widget: [validate] is a pure function of a
/// schema and a value map, so it is unit-testable without pumping a widget
/// tree.
abstract final class FormValidator {
  /// Returns a map of fieldId -> error message for every field that fails
  /// its schema's constraints. An empty map means the form is valid.
  ///
  /// Fields hidden by their own visibility rule are skipped: a question the
  /// patient was never shown cannot be answered wrongly.
  static Map<String, String> validate(
    FormSchema schema,
    Map<String, dynamic> values,
  ) {
    return _issues(schema, values, FormIssueSeverity.error);
  }

  /// Advisory messages that never block saving.
  static Map<String, String> warnings(
    FormSchema schema,
    Map<String, dynamic> values,
  ) {
    return _issues(schema, values, FormIssueSeverity.warning);
  }

  static Map<String, String> _issues(
    FormSchema schema,
    Map<String, dynamic> values,
    FormIssueSeverity severity,
  ) {
    final found = <String, String>{};
    if (severity == FormIssueSeverity.error) {
      for (final field in schema.visibleFields(values)) {
        final error = _validateField(field, values[field.id], values);
        if (error != null) found[field.id] = error;
      }
    }
    final visibleIds = schema
        .visibleFields(values)
        .map((field) => field.id)
        .toSet();
    for (final rule in schema.crossFieldRules) {
      for (final issue in rule(values)) {
        if (issue.severity != severity) continue;
        if (!visibleIds.contains(issue.fieldId)) continue;
        found.putIfAbsent(issue.fieldId, () => issue.message);
      }
    }
    return found;
  }

  static String? _validateField(
    FormFieldSchema field,
    dynamic value,
    Map<String, dynamic> values,
  ) {
    final allowed = field.visibleOptionValues(values);
    switch (field.type) {
      case FormFieldType.boolean:
        // Mirrors `@NotNull Boolean` — the field is either answered
        // true/false or the form is incomplete, so `null` (never touched)
        // is the only failure state.
        if (field.required && value is! bool) {
          return '${field.label} is required.';
        }
        return null;

      case FormFieldType.singleSelect:
        if (value == null) {
          return field.required ? '${field.label} is required.' : null;
        }
        if (value is! String || !allowed.contains(value)) {
          return '${field.label} must be one of the listed options.';
        }
        return null;

      case FormFieldType.multiSelect:
        if (value == null) {
          // Mirrors `@NotNull List<...>` — the list itself, not its
          // contents, is what's required. `[]` is a valid, complete answer.
          return field.required ? '${field.label} is required.' : null;
        }
        if (value is! List) {
          return '${field.label} is invalid.';
        }
        final selected = value.cast<String>();
        if (selected.toSet().length != selected.length) {
          return '${field.label} has a duplicate selection.';
        }
        final unknown = selected.where((v) => !allowed.contains(v));
        if (unknown.isNotEmpty) {
          return '${field.label} has an unrecognised option: ${unknown.first}.';
        }
        final cap = field.maxSelections;
        if (cap != null && selected.length > cap) {
          return '${field.label} allows at most $cap selections.';
        }
        return null;
    }
  }
}
