/// Supported input types a [DynamicFormRenderer] knows how to draw.
///
/// Deliberately small and closed: every case here maps to one widget in
/// `presentation/widgets/`, and every widget maps back to one column shape
/// from the ERD (`backend/src/main/resources/db/migration`) — a NOT NULL
/// boolean, a `varchar` restricted by a `CHECK ... IN (...)`, or a `text[]`
/// restricted by a `CHECK (col <@ ARRAY[...])`. Adding a case means adding
/// both a widget and a real column shape it represents.
enum FormFieldType {
  /// A single boolean column, e.g. `patient_profile.pregnant_breastfeeding`.
  boolean,

  /// A varchar column restricted to a fixed set of values,
  /// e.g. `patient_profile.skin_type`.
  singleSelect,

  /// A `text[]` column restricted to a fixed set of values,
  /// e.g. `patient_profile.allergies`.
  multiSelect,
}

extension FormFieldTypeWire on FormFieldType {
  String get wireName => switch (this) {
    FormFieldType.boolean => 'BOOLEAN',
    FormFieldType.singleSelect => 'SINGLE_SELECT',
    FormFieldType.multiSelect => 'MULTI_SELECT',
  };
  static FormFieldType fromWire(String value) => switch (value) {
    'BOOLEAN' => FormFieldType.boolean,
    'SINGLE_SELECT' => FormFieldType.singleSelect,
    'MULTI_SELECT' => FormFieldType.multiSelect,
    _ => throw ArgumentError('Unsupported form field type: $value'),
  };
}

/// One selectable value for a [FormFieldType.singleSelect] or
/// [FormFieldType.multiSelect] field.
///
/// [value] is the wire value the backend enum serializes to (its Java
/// `name()`); [label] is what the form displays for it.
class FormOption {
  const FormOption({required this.value, required this.label});

  final String value;
  final String label;

  /// Builds options from raw backend enum constants, humanizing each into a
  /// label — e.g. `HORMONAL_CONTRACEPTIVES` -> `Hormonal contraceptives`.
  static List<FormOption> fromValues(List<String> values) {
    return values.map((v) => FormOption(value: v, label: humanize(v))).toList();
  }

  static String humanize(String value) {
    final words = value.split('_');
    final first = words.first;
    final head = first.isEmpty
        ? ''
        : '${first[0]}${first.substring(1).toLowerCase()}';
    final rest = words.skip(1).map((w) => w.toLowerCase());
    return [head, ...rest].join(' ');
  }
}

/// Describes one field of a [FormSchema], independent of any Flutter widget.
///
/// [id] must match the JSON key the backend DTO expects (e.g. `skinType` on
/// `EditClinicalProfileRequest`) — [DynamicFormRenderer] and the API layer
/// round-trip values under this key with no further mapping.
class FormFieldSchema {
  const FormFieldSchema({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.helpText,
    this.options = const [],
    this.maxSelections,
  });

  final String id;
  final String label;
  final FormFieldType type;

  /// Mirrors a `@NotNull` constraint (or a NOT NULL column) on the backend
  /// DTO. For [FormFieldType.multiSelect], "required" means the *list*
  /// itself must be non-null — an empty selection still satisfies it,
  /// exactly as `@NotNull List<Allergy> allergies` accepts `[]`.
  final bool required;

  final String? helpText;

  /// Valid choices for select types. Empty for [FormFieldType.boolean].
  final List<FormOption> options;

  /// Mirrors a `@Size(max = ...)` constraint on a multi-select's backing
  /// list. Null means uncapped.
  final int? maxSelections;

  Set<String> get optionValues => options.map((o) => o.value).toSet();
}
