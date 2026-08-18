import 'form_field_schema.dart';
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
  static Map<String, String> validate(
    FormSchema schema,
    Map<String, dynamic> values,
  ) {
    final errors = <String, String>{};
    for (final field in schema.fields) {
      final error = _validateField(field, values[field.id]);
      if (error != null) errors[field.id] = error;
    }
    return errors;
  }

  static String? _validateField(FormFieldSchema field, dynamic value) {
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
        if (value is! String || !field.optionValues.contains(value)) {
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
        final unknown = selected.where((v) => !field.optionValues.contains(v));
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
