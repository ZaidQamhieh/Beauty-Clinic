import '../utils/password_strength.dart';

final _emailPattern = RegExp(
  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$',
);
final _namePattern = RegExp(r"^\p{L}[\p{L}\p{M}'\- .]*$", unicode: true);
final _digitsOnly = RegExp(r'^\d+$');
final _repeatedDigit = RegExp(r'^(\d)\1+$');

/// Shared field rules for every frontend form.
abstract final class FieldRules {
  /// Age in whole years, null when birth unknown.
  static int? ageOn(DateTime? birth, [DateTime? asOf]) {
    if (birth == null) return null;
    final now = dayOf(asOf ?? DateTime.now());
    var age = now.year - birth.year;
    final hadBirthday =
        now.month > birth.month ||
        (now.month == birth.month && now.day >= birth.day);
    if (!hadBirthday) age--;
    return age;
  }

  /// Strips the time part off a date.
  static DateTime dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String? requiredText(String? value, String label) =>
      (value?.trim().isEmpty ?? true) ? '$label is required.' : null;

  /// Rejects digits and symbols inside a person name.
  static String? personName(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required.';
    if (text.length < 2) return '$label is too short.';
    if (text.length > 60) return '$label is too long.';
    if (!_namePattern.hasMatch(text)) {
      return '$label cannot contain digits or symbols.';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required.';
    if (text.length > 254) return 'Email is too long.';
    if (!_emailPattern.hasMatch(text)) return 'Enter a valid email address.';
    return null;
  }

  /// Digits after the dial prefix, fixed length.
  static String? phoneDigits(String? value, {int length = 7}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Phone number is required.';
    if (!_digitsOnly.hasMatch(text)) return 'Phone number must be digits only.';
    if (text.length != length) {
      return 'A phone number is $length digits after the prefix.';
    }
    if (_repeatedDigit.hasMatch(text)) return 'Enter a real phone number.';
    return null;
  }

  static String? httpUrl(
    String? value, {
    bool required = false,
    String label = 'Address',
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? '$label is required.' : null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.isAbsolute || !uri.hasAuthority) {
      return 'Enter a full web address.';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Address must start with http or https.';
    }
    return null;
  }

  /// Rejects weak passwords and ones echoing identity.
  static String? password(
    String? value, {
    String? email,
    String? firstName,
    String? lastName,
  }) {
    final text = value ?? '';
    if (text.length < 8) return 'Use at least 8 characters.';
    if (text.length > 72) return 'Use at most 72 characters.';
    if (text.trim().isEmpty) return 'Password cannot be only spaces.';
    final lower = text.toLowerCase();
    final local = (email ?? '').split('@').first.trim().toLowerCase();
    if (local.length >= 3 && lower.contains(local)) {
      return 'Password cannot contain your email.';
    }
    for (final part in [firstName, lastName]) {
      final name = part?.trim().toLowerCase() ?? '';
      if (name.length >= 3 && lower.contains(name)) {
        return 'Password cannot contain your name.';
      }
    }
    if (scorePasswordStrength(text).level == PasswordStrength.weak) {
      return 'Password is too weak; mix cases, digits, symbols.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) =>
      value != password ? 'Passwords do not match.' : null;

  static String? nonNegativeInt(String? value, String label, {int? max}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required.';
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) {
      return '$label must be a non-negative number.';
    }
    if (max != null && parsed > max) return '$label is not plausible.';
    return null;
  }

  /// Bounds a birth date by plausible living age.
  static String? dateOfBirth(
    DateTime? value, {
    int minAge = 16,
    int maxAge = 120,
  }) {
    if (value == null) return 'Date of birth is required.';
    final today = dayOf(DateTime.now());
    final birth = dayOf(value);
    if (birth.isAfter(today)) return 'Date of birth cannot be in the future.';
    final age = ageOn(birth, today)!;
    if (age > maxAge) return 'Date of birth is not plausible.';
    if (age < minAge) return 'Must be at least $minAge years old.';
    return null;
  }

  /// Caps experience by years lived since working age.
  static String? yearsOfExperience(
    String? value, {
    DateTime? dateOfBirth,
    int workingAge = 18,
  }) {
    final basic = nonNegativeInt(value, 'Years of experience', max: 70);
    if (basic != null) return basic;
    final years = int.parse(value!.trim());
    final age = ageOn(dateOfBirth);
    if (age != null && years > age - workingAge) {
      return 'Experience exceeds years worked since age $workingAge.';
    }
    return null;
  }

  /// Keeps a follow-up on or after its session.
  static String? followUpDate(
    DateTime? value, {
    DateTime? notBefore,
    int maxYearsAhead = 5,
  }) {
    if (value == null) return null;
    final date = dayOf(value);
    final floor = dayOf(notBefore ?? DateTime.now());
    if (date.isBefore(floor)) {
      return 'Follow-up cannot be before the session date.';
    }
    final ceiling = DateTime(
      floor.year + maxYearsAhead,
      floor.month,
      floor.day,
    );
    if (date.isAfter(ceiling)) return 'Follow-up is too far in the future.';
    return null;
  }
}
