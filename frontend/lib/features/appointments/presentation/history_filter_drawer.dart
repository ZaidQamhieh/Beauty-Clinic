import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/appointment.dart';
import 'booking_format.dart';
import 'mini_calendar.dart';

/// Date, preview and status filters, one panel.
class HistoryFilterDrawer extends StatelessWidget {
  const HistoryFilterDrawer({
    super.key,
    required this.markedDates,
    required this.selectedDay,
    required this.previewDay,
    required this.previewAppointments,
    required this.statuses,
    required this.selectedStatuses,
    required this.statusCounts,
    required this.shown,
    required this.total,
    required this.onDaySelected,
    required this.onDayHovered,
    required this.onStatusToggled,
    required this.onClose,
  });

  final Set<DateTime> markedDates;
  final DateTime? selectedDay;

  /// Hovered day, else the picked one.
  final DateTime? previewDay;
  final List<Appointment> previewAppointments;

  final List<String> statuses;
  final Set<String> selectedStatuses;

  /// Count per status, ignoring that status filter.
  final Map<String, int> statusCounts;

  final int shown;
  final int total;

  final ValueChanged<DateTime?> onDaySelected;
  final ValueChanged<DateTime?> onDayHovered;
  final ValueChanged<String> onStatusToggled;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // Control surface, recessed under the cards.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 14),
            Text('DATE', style: AppTypography.labelSmall()),
            const SizedBox(height: 8),
            MiniCalendar(
              markedDates: markedDates,
              selectedDate: selectedDay,
              onDaySelected: onDaySelected,
              onDayHovered: onDayHovered,
              showFrame: false,
            ),
            const SizedBox(height: 16),
            Text('PREVIEW', style: AppTypography.labelSmall()),
            const SizedBox(height: 8),
            _preview(),
            const SizedBox(height: 16),
            Text('STATUS', style: AppTypography.labelSmall()),
            const SizedBox(height: 8),
            for (final status in statuses) _statusRow(status),
          ],
        ),
      ),
    );
  }

  // Rose only once a filter bites.
  Widget _header() {
    final narrowed = shown != total;
    return Row(
      children: [
        Expanded(
          child: Text(
            narrowed ? '$shown of $total visits' : 'All $total visits',
            style: AppTypography.labelMedium(
              color: narrowed ? AppColors.roseDark : AppColors.textSub,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close filters',
          onPressed: onClose,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
        ),
      ],
    );
  }

  // Hovering surveys a day without filtering.
  Widget _preview() {
    final day = previewDay;
    if (day == null) {
      return Text(
        'Point at a day to see it.',
        style: AppTypography.bodySmall(),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BookingFormat.calendarDay(day),
            style: AppTypography.labelMedium(),
          ),
          const SizedBox(height: 4),
          if (previewAppointments.isEmpty)
            Text('No past visits.', style: AppTypography.bodySmall())
          else
            for (final appointment in previewAppointments)
              for (final session in appointment.sessions)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.treatmentLabel,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: AppTypography.bodySmall(
                            color: AppColors.textSub,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        BookingFormat.time12(session.startTime),
                        style: AppTypography.bodySmall(),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  // Small saturated dot beats pale wash.
  Widget _statusRow(String status) {
    final count = statusCounts[status] ?? 0;
    final selected = selectedStatuses.contains(status);
    // Picking a zero would only empty things.
    final enabled = selected || count > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.rosePale : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? () => onStatusToggled(status) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    // Hue kept but drained, still readable.
                    color: enabled
                        ? StatusPill.accentFor(status)
                        : StatusPill.accentFor(status).withValues(alpha: 0.30),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style:
                        AppTypography.bodyMedium(
                          color: !enabled
                              ? AppColors.textMuted
                              : (selected
                                    ? AppColors.roseDark
                                    : AppColors.textSub),
                        ).copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style:
                      AppTypography.labelLarge(
                        color: enabled ? AppColors.text : AppColors.textMuted,
                      ).copyWith(
                        fontWeight: enabled ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
