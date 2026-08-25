import 'package:beauty_clinic_app/features/forms/data/clinical_intake_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Clinical Intake Schema isComplete', () {
    test('returns false when data is null or empty', () {
      expect(ClinicalIntakeSchema.isComplete(null), isFalse);
      expect(ClinicalIntakeSchema.isComplete({}), isFalse);
    });

    test('returns false when skinType is missing or empty', () {
      expect(
        ClinicalIntakeSchema.isComplete({
          'pregnantBreastfeeding': false,
          'skinType': null,
        }),
        isFalse,
      );
      expect(
        ClinicalIntakeSchema.isComplete({
          'pregnantBreastfeeding': false,
          'skinType': '',
        }),
        isFalse,
      );
    });

    test('returns true when skinType is specified', () {
      expect(
        ClinicalIntakeSchema.isComplete({
          'pregnantBreastfeeding': false,
          'skinType': 'NORMAL',
          'allergies': ['LATEX'],
        }),
        isTrue,
      );
    });
  });
}
