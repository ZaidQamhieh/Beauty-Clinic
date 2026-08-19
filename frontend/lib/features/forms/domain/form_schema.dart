import 'form_field_schema.dart';

/// A named, ordered set of [FormFieldSchema]s that together describe one
/// backend request/response shape (one DTO).
///
/// This is the object a form-builder UI edits and a
/// [DynamicFormRenderer]/`FormValidator` consumes — the same schema drives
/// both, so a field added to [fields] appears in the rendered UI and is
/// validated without touching either of those.
class FormSchema {
  const FormSchema({
    required this.id,
    required this.title,
    this.description,
    required this.fields,
  });

  final String id;
  final String title;
  final String? description;
  final List<FormFieldSchema> fields;

  FormFieldSchema? fieldById(String id) {
    for (final field in fields) {
      if (field.id == id) return field;
    }
    return null;
  }

  /// Starting values for a fresh form: `false` for a boolean, `null` for a
  /// single-select, `[]` for a multi-select — matching what an unfilled row
  /// under the ERD's own defaults/nullability would hold.
  Map<String, dynamic> defaultValues() {
    return {
      for (final field in fields)
        field.id: switch (field.type) {
          FormFieldType.boolean => false,
          FormFieldType.singleSelect => null,
          FormFieldType.multiSelect => <String>[],
        },
    };
  }

  /// Returns a copy of this schema with one field replaced — the primitive
  /// a form-builder UI uses to edit a schema without mutating shared state.
  FormSchema withField(FormFieldSchema replacement) {
    return FormSchema(
      id: id,
      title: title,
      description: description,
      fields: [
        for (final field in fields)
          field.id == replacement.id ? replacement : field,
      ],
    );
  }
}
