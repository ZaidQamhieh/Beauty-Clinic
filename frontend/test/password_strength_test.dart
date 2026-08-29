import 'package:beauty_clinic_app/core/utils/password_strength.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordStrength', () {
    test('weak password is correctly identified', () {
      final weak = scorePasswordStrength('password');
      expect(weak.level, PasswordStrength.weak);
    });

    test('fair password is correctly identified', () {
      final fair = scorePasswordStrength('Pass123');
      expect(fair.level, PasswordStrength.fair);
    });

    test('good password is correctly identified', () {
      final good = scorePasswordStrength('Pass@123');
      expect(good.level, PasswordStrength.good);
    });

    test('strong password is correctly identified', () {
      final strong = scorePasswordStrength('StrongP@ss123!');
      expect(strong.level, PasswordStrength.strong);
    });

    test('empty password is weak', () {
      final empty = scorePasswordStrength('');
      expect(empty.level, PasswordStrength.weak);
    });

    test('password with only lowercase rates lower', () {
      final lower = scorePasswordStrength('verylongpassword');
      final mixed = scorePasswordStrength('VeryLongPassword');
      expect(lower.level.index, lessThanOrEqualTo(mixed.level.index));
    });

    test('password with only uppercase rates lower', () {
      final upper = scorePasswordStrength('VERYLONGPASSWORD');
      final mixed = scorePasswordStrength('VeryLongPassword');
      expect(upper.level.index, lessThanOrEqualTo(mixed.level.index));
    });

    test('password with only digits is weak', () {
      final digits = scorePasswordStrength('12345678');
      expect(digits.level, PasswordStrength.weak);
    });

    test('common password is weak', () {
      final common = scorePasswordStrength('password123');
      expect(common.level, PasswordStrength.weak);
      expect(common.label, contains('common'));
    });

    test('password with mixed case rates better', () {
      final singleCase = scorePasswordStrength('password12345');
      final mixedCase = scorePasswordStrength('PassWord12345');
      expect(mixedCase.level, greaterThanOrEqualTo(singleCase.level));
    });

    test('short password rates worse', () {
      final short = scorePasswordStrength('Pass1');
      expect(short.level.index, lessThanOrEqualTo(1));
    });

    test('long password with variety rates well', () {
      final strong = scorePasswordStrength('VeryStrongPass123!');
      expect(strong.level.index, greaterThanOrEqualTo(2));
    });

    test('password result includes label', () {
      final result = scorePasswordStrength('StrongPass123!');
      expect(result.label, isNotEmpty);
    });
  });
}
