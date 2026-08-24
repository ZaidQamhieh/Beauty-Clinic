import 'package:flutter/foundation.dart';

import 'form_schema.dart';
import 'form_validator.dart';

/// One in-progress form's values and validation state.
class DynamicFormController extends ChangeNotifier {
  DynamicFormController({
    required FormSchema schema,
    Map<String, dynamic>? initialValues,
  }) : _schema = schema,
       values = {...schema.defaultValues(), ...?initialValues};

  FormSchema _schema;
  FormSchema get schema => _schema;

  Map<String, dynamic> values;
  Map<String, String> errors = {};

  /// True once submit has been attempted.
  bool touched = false;

  void setValue(String fieldId, dynamic value) {
    values = {...values, fieldId: value};
    if (touched) {
      // Live re-validate after a submit attempt.
      errors = FormValidator.validate(_schema, values);
    }
    notifyListeners();
  }

  /// Switches schema, keeping values it still has.
  void updateSchema(FormSchema newSchema) {
    _schema = newSchema;
    final allowedIds = newSchema.fields.map((f) => f.id).toSet();
    values = {
      ...newSchema.defaultValues(),
      for (final entry in values.entries)
        if (allowedIds.contains(entry.key)) entry.key: entry.value,
    };
    if (touched) errors = FormValidator.validate(_schema, values);
    notifyListeners();
  }

  bool validate() {
    touched = true;
    errors = FormValidator.validate(_schema, values);
    notifyListeners();
    return errors.isEmpty;
  }

  /// Discards edits, restoring the given snapshot.
  void reset(Map<String, dynamic> initialValues) {
    values = {...schema.defaultValues(), ...initialValues};
    errors = {};
    touched = false;
    notifyListeners();
  }
}
