import '../domain/form_field_schema.dart';
import '../domain/form_schema.dart';

/// The one dynamic form the ERD actually supports today: the patient
/// clinical intake — `patient_profile` plus the enums Flyway `V1__baseline_schema.sql`
/// defines as `CHECK` constraints (`SkinType`, `SmokingStatus`, `Allergy`,
/// `Medication`, `ChronicCondition`) and the backend's
/// `EditClinicalProfileRequest` / `PatientRecordResponse` DTOs that carry them.
///
/// Field ids below are the exact JSON keys those DTOs use. Do not rename a
/// field here without renaming it on the backend DTO too, or the request
/// body [toRequestJson] produces will silently drop the value.
abstract final class ClinicalIntakeSchema {
  static const schema = FormSchema(
    id: 'patient-clinical-intake',
    title: 'Clinic Forms',
    description:
        'The clinic health form. Skin type is the one answer that marks it '
        'filled — everything else may truthfully be left empty.',
    fields: [
      FormFieldSchema(
        id: 'pregnantBreastfeeding',
        label: 'Pregnant or breastfeeding',
        type: FormFieldType.boolean,
        required: true,
      ),
      FormFieldSchema(
        id: 'skinType',
        label: 'Skin type',
        type: FormFieldType.singleSelect,
        required: true,
        options: [
          FormOption(value: 'NORMAL', label: 'Normal'),
          FormOption(value: 'DRY', label: 'Dry'),
          FormOption(value: 'OILY', label: 'Oily'),
          FormOption(value: 'COMBINATION', label: 'Combination'),
          FormOption(value: 'SENSITIVE', label: 'Sensitive'),
        ],
      ),
      FormFieldSchema(
        id: 'smokingStatus',
        label: 'Smoking status',
        type: FormFieldType.singleSelect,
        // patient_profile.smoking_status is a nullable column: absent
        // legitimately means unknown, not unanswered.
        required: false,
        options: [
          FormOption(value: 'NEVER', label: 'Never'),
          FormOption(value: 'FORMER', label: 'Former'),
          FormOption(value: 'CURRENT', label: 'Current'),
        ],
      ),
      FormFieldSchema(
        id: 'allergies',
        label: 'Allergies',
        type: FormFieldType.multiSelect,
        required: true,
        maxSelections: 20,
        options: [
          FormOption(value: 'NUTS', label: 'Nuts'),
          FormOption(value: 'LATEX', label: 'Latex'),
          FormOption(value: 'PENICILLIN', label: 'Penicillin'),
          FormOption(value: 'SULFA', label: 'Sulfa'),
          FormOption(value: 'LIDOCAINE', label: 'Lidocaine'),
          FormOption(value: 'FRAGRANCE', label: 'Fragrance'),
          FormOption(value: 'NICKEL', label: 'Nickel'),
          FormOption(value: 'IODINE', label: 'Iodine'),
        ],
      ),
      FormFieldSchema(
        id: 'medications',
        label: 'Current medications',
        type: FormFieldType.multiSelect,
        required: true,
        maxSelections: 20,
        options: [
          FormOption(value: 'ISOTRETINOIN', label: 'Isotretinoin'),
          FormOption(value: 'ANTICOAGULANTS', label: 'Anticoagulants'),
          FormOption(value: 'IMMUNOSUPPRESSANTS', label: 'Immunosuppressants'),
          FormOption(value: 'ORAL_STEROIDS', label: 'Oral steroids'),
          FormOption(
            value: 'HORMONAL_CONTRACEPTIVES',
            label: 'Hormonal contraceptives',
          ),
          FormOption(value: 'ANTIBIOTICS', label: 'Antibiotics'),
        ],
      ),
      FormFieldSchema(
        id: 'chronicConditions',
        label: 'Chronic conditions',
        type: FormFieldType.multiSelect,
        required: true,
        maxSelections: 20,
        options: [
          FormOption(value: 'DIABETES', label: 'Diabetes'),
          FormOption(value: 'HYPERTENSION', label: 'Hypertension'),
          FormOption(value: 'ECZEMA', label: 'Eczema'),
          FormOption(value: 'PSORIASIS', label: 'Psoriasis'),
          FormOption(value: 'ROSACEA', label: 'Rosacea'),
          FormOption(value: 'THYROID_DISORDER', label: 'Thyroid disorder'),
          FormOption(value: 'AUTOIMMUNE', label: 'Autoimmune'),
        ],
      ),
    ],
  );

  /// Reads the clinical subset out of a `PatientRecordResponse` JSON body
  /// into the flat value map `DynamicFormRenderer` expects.
  static Map<String, dynamic> fromResponseJson(Map<String, dynamic> json) {
    return {
      ...json,
      'pregnantBreastfeeding': json['pregnantBreastfeeding'] as bool? ?? false,
      'skinType': json['skinType'] as String?,
      'smokingStatus': json['smokingStatus'] as String?,
      'allergies': List<String>.from(json['allergies'] as List? ?? const []),
      'medications': List<String>.from(
        json['medications'] as List? ?? const [],
      ),
      'chronicConditions': List<String>.from(
        json['chronicConditions'] as List? ?? const [],
      ),
    };
  }

  /// Builds the exact body `EditClinicalProfileRequest` expects. Call this
  /// only after `FormValidator.validate` returns no errors — it does not
  /// re-check required fields itself.
  static Map<String, dynamic> toRequestJson(Map<String, dynamic> values) {
    return {
      'pregnantBreastfeeding':
          values['pregnantBreastfeeding'] as bool? ?? false,
      'skinType': values['skinType'],
      'smokingStatus': values['smokingStatus'],
      'allergies': values['allergies'] ?? <String>[],
      'medications': values['medications'] ?? <String>[],
      'chronicConditions': values['chronicConditions'] ?? <String>[],
    };
  }

  /// Checks whether all required clinical intake fields are answered.
  /// Skin type is the mandatory answer that marks the clinical record complete.
  static bool isComplete(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return false;
    final skinType = data['skinType'];
    return skinType != null && skinType.toString().trim().isNotEmpty;
  }
}
