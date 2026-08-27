import '../../../core/validation/field_rules.dart';
import 'form_issue.dart';

/// Cross-field rules for the clinical intake form.
abstract final class ClinicalRules {
  static const pregnancyField = 'pregnantBreastfeeding';
  static const medicationsField = 'medications';

  /// Every rule the clinical intake schema installs.
  static const List<CrossFieldRule> all = [contraindications, implausibleAge];

  /// Hides questions a male record cannot answer.
  static bool notMale(Map<String, dynamic> values) =>
      values['gender']?.toString().trim().toUpperCase() != 'MALE';

  /// Blocks drugs that must never meet a pregnancy.
  static List<FormIssue> contraindications(Map<String, dynamic> values) {
    if (!_isPregnant(values)) return const [];
    final medications = _list(values[medicationsField]);
    if (!medications.contains('ISOTRETINOIN')) return const [];
    return const [
      FormIssue(
        fieldId: medicationsField,
        message:
            'Isotretinoin cannot be recorded alongside pregnancy or breastfeeding.',
      ),
    ];
  }

  /// Flags a pregnancy outside plausible childbearing years.
  static List<FormIssue> implausibleAge(Map<String, dynamic> values) {
    if (!_isPregnant(values)) return const [];
    final age = FieldRules.ageOn(_birthDate(values));
    if (age == null || (age >= 10 && age <= 60)) return const [];
    return const [
      FormIssue.warning(
        fieldId: pregnancyField,
        message: 'Unusual for this age — confirm before saving.',
      ),
    ];
  }

  static bool _isPregnant(Map<String, dynamic> values) =>
      values[pregnancyField] == true;

  static List<String> _list(dynamic value) =>
      value is List ? value.cast<String>() : const [];

  static DateTime? _birthDate(Map<String, dynamic> values) {
    final raw = values['dateOfBirth'];
    if (raw is DateTime) return raw;
    return raw == null ? null : DateTime.tryParse(raw.toString());
  }
}
