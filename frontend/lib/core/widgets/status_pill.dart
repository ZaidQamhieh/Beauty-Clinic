import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Status badge for appointments, records, tags.
class StatusPill extends StatelessWidget {
  final String status;

  const StatusPill({super.key, required this.status});

  /// Status hue, for dots and rules elsewhere.
  static Color accentFor(String status) => _styleFor(status).text;

  static _StatusStyle _styleFor(String status) =>
      _styles[status] ??
      _StatusStyle(
        bg: AppColors.textMuted.withValues(alpha: 0.14),
        text: AppColors.textSub,
      );

  // Tints deep enough for white or bgAlt.
  static final Map<String, _StatusStyle> _styles = {
    'Confirmed': _StatusStyle(
      bg: AppColors.sage.withValues(alpha: 0.18),
      text: AppColors.sageDark,
    ),
    'Pending': _StatusStyle(
      bg: AppColors.gold.withValues(alpha: 0.20),
      text: AppColors.gold,
    ),
    'In Room': _StatusStyle(
      bg: const Color(0xFF2563EB).withValues(alpha: 0.16),
      text: const Color(0xFF1D4ED8),
    ),
    'Cancelled': _StatusStyle(
      bg: AppColors.rose.withValues(alpha: 0.22),
      text: AppColors.roseDark,
    ),
    'Suggested': _StatusStyle(
      bg: AppColors.lav.withValues(alpha: 0.16),
      text: AppColors.lavDark,
    ),
    'Completed': _StatusStyle(
      bg: AppColors.lav.withValues(alpha: 0.20),
      text: AppColors.lavDark,
    ),
    'Missed': _StatusStyle(
      bg: AppColors.textMuted.withValues(alpha: 0.18),
      text: AppColors.textSub,
    ),
    'Waiting': _StatusStyle(
      bg: AppColors.gold.withValues(alpha: 0.20),
      text: AppColors.gold,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final _StatusStyle style = _styleFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: AppTypography.labelSmall(
          color: style.text,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusStyle {
  final Color bg;
  final Color text;

  const _StatusStyle({required this.bg, required this.text});
}
