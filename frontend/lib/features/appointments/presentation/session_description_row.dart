import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/appointment.dart';

/// Same four-color palette used across the list, the calendar, and this
/// row, so a session reads the same status color everywhere it appears.
({String label, Color color}) sessionStatusInfo(String status) {
  return switch (status) {
    'COMPLETED' => (label: 'Completed', color: AppColors.lavDark),
    'CANCELLED' => (label: 'Cancelled', color: AppColors.roseDark),
    'NO_SHOW' => (label: 'Missed', color: AppColors.gold),
    _ => (label: 'Planned', color: AppColors.sageDark),
  };
}

/// One session's own description among the others on the same visit - its
/// treatment, time, practitioner and status - used wherever tapping a
/// calendar session opens a breakdown of everything on that visit (staff
/// and patient calendars alike). [selected] marks the one actually tapped,
/// so it reads as visibly distinct from its siblings rather than blending
/// into the rest of the list.
class SessionDescriptionRow extends StatelessWidget {
  const SessionDescriptionRow({
    super.key,
    required this.session,
    this.selected = false,
    this.showPractitioner = true,
    this.trailing,
    this.onTap,
  });

  final AppointmentSession session;
  final bool selected;

  /// False for a doctor looking at their own sessions - their own name on
  /// every row would just be noise.
  final bool showPractitioner;

  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusInfo = sessionStatusInfo(session.status);
    final period =
        '${DateFormat('HH:mm').format(session.startTime.toLocal())}–'
        '${DateFormat('HH:mm').format(session.endTime.toLocal())}';

    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.rosePale : AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: AppColors.borderRose, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.spa_outlined,
            size: 16,
            color: selected ? AppColors.roseDark : AppColors.rose,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.treatmentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium(),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: showPractitioner
                            ? '$period · ${session.practitionerName} · '
                            : '$period · ',
                        style: AppTypography.bodySmall(
                          color: AppColors.textMuted,
                        ),
                      ),
                      TextSpan(
                        text: statusInfo.label,
                        style: AppTypography.bodySmall(
                          color: statusInfo.color,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: row,
    );
  }
}
