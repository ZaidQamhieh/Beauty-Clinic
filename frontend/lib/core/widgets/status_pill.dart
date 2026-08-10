import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Status pill badge widget used for appointments, records, and tags
class StatusPill extends StatelessWidget {
  final String status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Map<String, _StatusStyle> styles = {
      'Confirmed': const _StatusStyle(bg: AppColors.bgSage, text: AppColors.sage),
      'Pending': const _StatusStyle(bg: AppColors.goldPale, text: AppColors.gold),
      'In Room': const _StatusStyle(bg: Color(0xFFDBEAFE), text: Color(0xFF2563EB)),
      'Cancelled': const _StatusStyle(bg: Color(0xFFFEE2E2), text: Color(0xFFDC2626)),
      'Suggested': const _StatusStyle(bg: AppColors.bgRose, text: AppColors.rose),
      'Completed': const _StatusStyle(bg: AppColors.bgLavender, text: AppColors.lav),
      'Waiting': const _StatusStyle(bg: AppColors.goldPale, text: AppColors.gold),
    };

    final _StatusStyle style = styles[status] ??
        const _StatusStyle(bg: AppColors.bgAlt, text: AppColors.textMuted);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: AppTypography.labelSmall(color: style.text).copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusStyle {
  final Color bg;
  final Color text;

  const _StatusStyle({required this.bg, required this.text});
}
