import 'package:flutter/foundation.dart';

import 'form_schema.dart';
import 'form_validator.dart';

/// One in-progress form's values and validation state.
class DynamicFormController extends ChangeNotifier {
  DynamicFormController({
    required FormSchema schema,
    Map<String, dynamic>? initialValues,
  }) : _schema = schema,
       values = const {},
       _saved = const {} {
    final initial = schema.pruneHidden({
      ...schema.defaultValues(),
      ...?initialValues,
    });
    values = initial;
    _saved = {...initial};
    warnings = FormValidator.warnings(schema, initial);
  }

  FormSchema _schema;
  FormSchema get schema => _schema;

  Map<String, dynamic> values;
  Map<String, String> errors = {};

  /// Advisory messages that do not block saving.
  Map<String, String> warnings = {};

  /// Last saved snapshot, for the dirty check.
  Map<String, dynamic> _saved;

  /// True once submit has been attempted.
  bool touched = false;

  /// True when values differ from saved.
  bool get isDirty => !_deepEquals(values, _saved);

  void setValue(String fieldId, dynamic value) {
    // Answers to newly hidden questions are dropped.
    values = _schema.pruneHidden({...values, fieldId: value});
    if (touched) {
      // Live re-validate after a submit attempt.
      errors = FormValidator.validate(_schema, values);
    }
    warnings = FormValidator.warnings(_schema, values);
    notifyListeners();
  }

  /// Switches schema, keeping values it still has.
  void updateSchema(FormSchema newSchema) {
    _schema = newSchema;
    final allowedIds = newSchema.fields.map((f) => f.id).toSet();
    values = newSchema.pruneHidden({
      ...newSchema.defaultValues(),
      for (final entry in values.entries)
        if (allowedIds.contains(entry.key)) entry.key: entry.value,
    });
    // Schema switch alone is not an edit.
    _saved = newSchema.pruneHidden({
      ...newSchema.defaultValues(),
      for (final entry in _saved.entries)
        if (allowedIds.contains(entry.key)) entry.key: entry.value,
    });
    if (touched) errors = FormValidator.validate(_schema, values);
    warnings = FormValidator.warnings(_schema, values);
    notifyListeners();
  }

  bool validate() {
    touched = true;
    errors = FormValidator.validate(_schema, values);
    warnings = FormValidator.warnings(_schema, values);
    notifyListeners();
    return errors.isEmpty;
  }

  /// Discards edits, restoring the given snapshot.
  void reset(Map<String, dynamic> initialValues) {
    values = _schema.pruneHidden({...schema.defaultValues(), ...initialValues});
    _saved = {...values};
    errors = {};
    warnings = FormValidator.warnings(_schema, values);
    touched = false;
    notifyListeners();
  }

  /// Makes current values the saved baseline.
  void markSaved() {
    _saved = {...values};
    notifyListeners();
  }
}

// Values are JSON: scalars, lists, maps.
bool _deepEquals(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
