enum PasswordStrength { weak, fair, good, strong }

class PasswordStrengthResult {
  const PasswordStrengthResult(this.level, this.label);

  final PasswordStrength level;
  final String label;
}

final _hasLower = RegExp(r'[a-z]');
final _hasUpper = RegExp(r'[A-Z]');
final _hasDigit = RegExp(r'[0-9]');
final _hasSymbol = RegExp(r'[^a-zA-Z0-9]');

// Common breached passwords, not exhaustive.
const _commonPasswords = {
  '12345678',
  '123456789',
  'password',
  'password1',
  'qwerty123',
  '11111111',
  'letmein',
  'welcome1',
  'admin123',
  'iloveyou',
  'monkey123',
  'football',
  'abc12345',
  'password123',
  'qwertyui',
};

/// UX-only guidance; backend length check is authoritative.
PasswordStrengthResult scorePasswordStrength(String password) {
  if (password.isEmpty) {
    return const PasswordStrengthResult(PasswordStrength.weak, '');
  }

  if (_commonPasswords.contains(password.toLowerCase())) {
    return const PasswordStrengthResult(
      PasswordStrength.weak,
      'Weak — too common',
    );
  }

  var score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (_hasLower.hasMatch(password) && _hasUpper.hasMatch(password)) score++;
  if (_hasDigit.hasMatch(password)) score++;
  if (_hasSymbol.hasMatch(password)) score++;

  return switch (score) {
    0 || 1 => const PasswordStrengthResult(PasswordStrength.weak, 'Weak'),
    2 => const PasswordStrengthResult(PasswordStrength.fair, 'Fair'),
    3 || 4 => const PasswordStrengthResult(PasswordStrength.good, 'Good'),
    _ => const PasswordStrengthResult(PasswordStrength.strong, 'Strong'),
  };
}
