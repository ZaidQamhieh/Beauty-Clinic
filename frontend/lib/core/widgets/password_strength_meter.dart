import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/password_strength.dart';

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  static const _steps = {
    PasswordStrength.weak: 0.25,
    PasswordStrength.fair: 0.5,
    PasswordStrength.good: 0.75,
    PasswordStrength.strong: 1.0,
  };

  static const _colors = {
    PasswordStrength.weak: Colors.redAccent,
    PasswordStrength.fair: AppColors.gold,
    PasswordStrength.good: AppColors.sage,
    PasswordStrength.strong: AppColors.sageDark,
  };

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final result = scorePasswordStrength(password);
    final color = _colors[result.level]!;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _steps[result.level],
              minHeight: 4,
              backgroundColor: AppColors.hairline,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
