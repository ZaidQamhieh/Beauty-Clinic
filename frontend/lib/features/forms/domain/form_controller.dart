import 'package:flutter/foundation.dart';

import 'form_schema.dart';
import 'form_validator.dart';

/// Holds one in-progress form's values and validation state, and notifies
/// the widgets a `DynamicFormRenderer` builds when either changes.
///
/// Owned by whatever screen hosts the form (a plain `ChangeNotifier`, not
/// tied to any `BuildContext`), so the same controller can back a submit
/// button, a "dirty" indicator, or — as in `FormBuilderAdminScreen` — a live
/// preview driven by schema edits instead of user input.
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

  /// True once [validate] has run at least once. Field widgets use this so
  /// they don't show a red border before the user has done anything.
  bool touched = false;

  void setValue(String fieldId, dynamic value) {
    values = {...values, fieldId: value};
    if (touched) {
      // Re-validate live once the user has attempted a submit, so an error
      // clears the moment it's fixed instead of sitting until the next one.
      errors = FormValidator.validate(_schema, values);
    }
    notifyListeners();
  }

  /// Re-points the controller at a new schema (e.g. after a form-builder
  /// edit) while keeping any values the new schema still has fields for.
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
}
