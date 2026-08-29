import 'package:beauty_clinic_app/core/validation/field_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FieldRules.requiredText', () {
    test('returns null for non-empty text', () {
      expect(FieldRules.requiredText('valid text', 'Field'), isNull);
      expect(FieldRules.requiredText('  valid  ', 'Field'), isNull);
    });

    test('returns error for empty text', () {
      expect(FieldRules.requiredText('', 'Field'), 'Field is required.');
      expect(FieldRules.requiredText('   ', 'Field'), 'Field is required.');
      expect(FieldRules.requiredText(null, 'Field'), 'Field is required.');
    });
  });

  group('FieldRules.personName', () {
    test('accepts valid names', () {
      expect(FieldRules.personName('John', 'First name'), isNull);
      expect(FieldRules.personName("O'Brien", 'Last name'), isNull);
      expect(FieldRules.personName('Mary-Jane', 'Name'), isNull);
      expect(FieldRules.personName('José', 'Name'), isNull);
    });

    test('rejects empty names', () {
      expect(FieldRules.personName('', 'Name'), 'Name is required.');
      expect(FieldRules.personName(null, 'Name'), 'Name is required.');
    });

    test('rejects short names', () {
      expect(FieldRules.personName('J', 'Name'), 'Name is too short.');
      expect(FieldRules.personName('A', 'Name'), 'Name is too short.');
    });

    test('rejects long names', () {
      final longName = 'A' * 101;
      expect(FieldRules.personName(longName, 'Name'), 'Name is too long.');
    });

    test('rejects names with digits', () {
      expect(
        FieldRules.personName('John123', 'Name'),
        'Name cannot contain digits or symbols.',
      );
    });

    test('rejects names with symbols', () {
      expect(
        FieldRules.personName('John@', 'Name'),
        'Name cannot contain digits or symbols.',
      );
    });
  });

  group('FieldRules.email', () {
    test('accepts valid emails', () {
      expect(FieldRules.email('user@example.com'), isNull);
      expect(FieldRules.email('john.doe+tag@example.co.uk'), isNull);
      expect(FieldRules.email('test_email@sub.example.com'), isNull);
    });

    test('rejects empty email', () {
      expect(FieldRules.email(''), 'Email is required.');
      expect(FieldRules.email(null), 'Email is required.');
    });

    test('rejects invalid email format', () {
      expect(FieldRules.email('not-an-email'), 'Enter a valid email address.');
      expect(FieldRules.email('user@'), 'Enter a valid email address.');
      expect(FieldRules.email('@example.com'), 'Enter a valid email address.');
    });

    test('rejects very long emails', () {
      final longEmail = '${'a' * 255}@example.com';
      expect(FieldRules.email(longEmail), 'Email is too long.');
    });
  });

  group('FieldRules.phoneDigits', () {
    test('accepts valid phone numbers', () {
      expect(FieldRules.phoneDigits('5551234'), isNull);
      expect(FieldRules.phoneDigits('1234567'), isNull);
    });

    test('rejects empty phone', () {
      expect(FieldRules.phoneDigits(''), 'Phone number is required.');
      expect(FieldRules.phoneDigits(null), 'Phone number is required.');
    });

    test('rejects non-digit input', () {
      expect(
        FieldRules.phoneDigits('555-123-4567'),
        'Phone number must be digits only.',
      );
      expect(
        FieldRules.phoneDigits('555 123 4567'),
        'Phone number must be digits only.',
      );
    });

    test('rejects wrong length', () {
      expect(
        FieldRules.phoneDigits('12345'),
        'A phone number is 7 digits after the prefix.',
      );
    });

    test('rejects repeated digits', () {
      expect(FieldRules.phoneDigits('1111111'), 'Enter a real phone number.');
      expect(FieldRules.phoneDigits('5555555'), 'Enter a real phone number.');
    });

    test('accepts custom length', () {
      expect(FieldRules.phoneDigits('123456789', length: 9), isNull);
      expect(
        FieldRules.phoneDigits('12345678', length: 9),
        'A phone number is 9 digits after the prefix.',
      );
    });
  });

  group('FieldRules.httpUrl', () {
    test('accepts valid URLs', () {
      expect(FieldRules.httpUrl('https://example.com'), isNull);
      expect(FieldRules.httpUrl('http://sub.example.co.uk/path'), isNull);
    });

    test('allows empty when not required', () {
      expect(FieldRules.httpUrl('', required: false), isNull);
      expect(FieldRules.httpUrl(null, required: false), isNull);
    });

    test('rejects empty when required', () {
      expect(FieldRules.httpUrl('', required: true), 'Address is required.');
    });

    test('rejects invalid URLs', () {
      expect(FieldRules.httpUrl('not a url'), 'Enter a full web address.');
      expect(FieldRules.httpUrl('example.com'), 'Enter a full web address.');
    });

    test('rejects non-http schemes', () {
      expect(
        FieldRules.httpUrl('ftp://example.com'),
        'Address must start with http or https.',
      );
    });
  });

  group('FieldRules.boundedText', () {
    test('accepts text within bounds', () {
      expect(FieldRules.boundedText('Hello', 'Message', max: 100), isNull);
    });

    test('rejects text exceeding max', () {
      expect(
        FieldRules.boundedText('A' * 101, 'Message', max: 100),
        'Message is over 100 characters.',
      );
    });

    test('requires text when required: true', () {
      expect(
        FieldRules.boundedText('', 'Message', max: 100, required: true),
        'Message is required.',
      );
    });

    test('allows empty when required: false', () {
      expect(
        FieldRules.boundedText('', 'Message', max: 100, required: false),
        isNull,
      );
    });
  });

  group('FieldRules.ageOn', () {
    test('calculates age correctly', () {
      final now = DateTime(2026, 8, 29);
      final birth = DateTime(2000, 8, 29);
      expect(FieldRules.ageOn(birth, now), 26);
    });

    test('calculates age before birthday', () {
      final now = DateTime(2026, 8, 28);
      final birth = DateTime(2000, 8, 29);
      expect(FieldRules.ageOn(birth, now), 25);
    });

    test('returns null for null birth date', () {
      expect(FieldRules.ageOn(null), isNull);
    });
  });

  group('FieldRules.dayOf', () {
    test('strips time part', () {
      final dt = DateTime(2026, 8, 29, 15, 30, 45);
      final day = FieldRules.dayOf(dt);
      expect(day.year, 2026);
      expect(day.month, 8);
      expect(day.day, 29);
      expect(day.hour, 0);
      expect(day.minute, 0);
      expect(day.second, 0);
    });
  });

  group('FieldRules.identifierKey', () {
    test('accepts valid identifiers', () {
      expect(FieldRules.identifierKey('fieldName', 'Key'), isNull);
      expect(FieldRules.identifierKey('field_123', 'Key'), isNull);
    });

    test('rejects empty identifiers', () {
      expect(FieldRules.identifierKey('', 'Key'), 'Key is required.');
    });

    test('rejects long identifiers', () {
      final longId = 'a' * 101;
      expect(
        FieldRules.identifierKey(longId, 'Key'),
        'Key is over 100 characters.',
      );
    });

    test('rejects identifiers starting with digit', () {
      expect(FieldRules.identifierKey('123field', 'Key'), isNotNull);
    });

    test('rejects identifiers with invalid characters', () {
      expect(FieldRules.identifierKey('field-name', 'Key'), isNotNull);
    });
  });

  group('FieldRules.password', () {
    test('accepts strong passwords', () {
      expect(FieldRules.password('StrongPass123!'), isNull);
    });

    test('rejects short passwords', () {
      expect(FieldRules.password('Short1!'), isNotNull);
    });

    test('rejects password matching email', () {
      expect(
        FieldRules.password('TestEmail123!', email: 'testemail@example.com'),
        isNotNull,
      );
    });

    test('rejects password matching name', () {
      expect(FieldRules.password('JohnDoe123!', firstName: 'John'), isNotNull);
    });
  });

  group('FieldRules.dateOfBirth', () {
    test('accepts valid dates', () {
      final validDate = DateTime(2000, 8, 29);
      expect(FieldRules.dateOfBirth(validDate, minAge: 18), isNull);
    });

    test('rejects null date when required', () {
      expect(FieldRules.dateOfBirth(null, minAge: 18), isNotNull);
    });

    test('rejects dates in the future', () {
      final future = DateTime(2030, 8, 29);
      expect(
        FieldRules.dateOfBirth(future, minAge: 18),
        'Date of birth cannot be in the future.',
      );
    });

    test('rejects underage dates', () {
      final tooYoung = DateTime(2024, 8, 29);
      expect(FieldRules.dateOfBirth(tooYoung, minAge: 18), isNotNull);
    });
  });

  group('FieldRules.yearsOfExperience', () {
    test('accepts valid experience', () {
      expect(FieldRules.yearsOfExperience('10'), isNull);
      expect(FieldRules.yearsOfExperience('0'), isNull);
    });

    test('rejects empty experience', () {
      expect(
        FieldRules.yearsOfExperience(''),
        'Years of experience is required.',
      );
    });

    test('rejects non-numeric experience', () {
      expect(FieldRules.yearsOfExperience('ten'), isNotNull);
    });

    test('rejects negative experience', () {
      expect(FieldRules.yearsOfExperience('-5'), isNotNull);
    });
  });
}
