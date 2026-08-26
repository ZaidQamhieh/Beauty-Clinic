import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/doctor_availability_api.dart';
import 'availability_sessions_view.dart'
    show DayWindow, resolveAvailableWindows;

enum _DayStatus { working, off, vacation, extraDay }

class _StatusStyle {
  const _StatusStyle(this.label, this.bg, this.color, this.icon);

  final String label;
  final Color bg;
  final Color color;
  final IconData icon;
}

const Map<_DayStatus, _StatusStyle> _statusStyles = {
  _DayStatus.working: _StatusStyle(
    'Working',
    AppColors.bgSage,
    AppColors.sage,
    Icons.check_circle_outline,
  ),
  _DayStatus.off: _StatusStyle(
    'Not Available',
    AppColors.bgAlt,
    AppColors.textMuted,
    Icons.remove_circle_outline,
  ),
  _DayStatus.vacation: _StatusStyle(
    'On Leave',
    AppColors.bgLavender,
    AppColors.lav,
    Icons.beach_access_outlined,
  ),
  _DayStatus.extraDay: _StatusStyle(
    'Extra Day',
    AppColors.bgRose,
    AppColors.rose,
    Icons.add_circle_outline,
  ),
};

const List<AvailabilityDay> _weekdaysInOrder = [
  AvailabilityDay.monday,
  AvailabilityDay.tuesday,
  AvailabilityDay.wednesday,
  AvailabilityDay.thursday,
  AvailabilityDay.friday,
  AvailabilityDay.saturday,
  AvailabilityDay.sunday,
];

/// Lets a doctor check their effective availability for any specific date,
/// resolved the same way the backend resolves it for booking.
class DayViewSection extends StatefulWidget {
  const DayViewSection({super.key, required this.availability});

  final List<DoctorAvailability> availability;

  @override
  State<DayViewSection> createState() => _DayViewSectionState();
}

class _DayViewSectionState extends State<DayViewSection> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final windows = resolveAvailableWindows(_date, widget.availability);
    final status = _statusFor(_date, widget.availability, windows);
    final style = _statusStyles[status]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 28, color: AppColors.rose),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day View', style: AppTypography.labelLarge()),
                    Text(
                      'Check effective availability for any specific date',
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(_shortDate(_date)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: style.color.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weekdayLabel(_date),
                  style: AppTypography.labelSmall(color: style.color),
                ),
                Text(_longDate(_date), style: AppTypography.labelLarge()),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: style.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 14, color: style.color),
                      const SizedBox(width: 6),
                      Text(
                        style.label,
                        style: AppTypography.labelSmall(color: style.color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (windows.isEmpty)
                  Text(
                    status == _DayStatus.vacation
                        ? 'Doctor is on leave this day.'
                        : 'No working hours on this day.',
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  )
                else
                  for (final window in windows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${_formatMinutes(window.start)} - ${_formatMinutes(window.end)}',
                          style: AppTypography.labelMedium(),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reuses resolveAvailableWindows's result (the same cascade the backend
  // resolves bookings against) and only asks which case produced it, for
  // the status label.
  _DayStatus _statusFor(
    DateTime date,
    List<DoctorAvailability> availability,
    List<DayWindow> windows,
  ) {
    final onlyDate = DateTime(date.year, date.month, date.day);
    bool covers(DoctorAvailability rule) {
      final from = DateTime(
        rule.effectiveFrom.year,
        rule.effectiveFrom.month,
        rule.effectiveFrom.day,
      );
      // Null effectiveTo means open-ended (the normal case for REGULAR), not
      // "same day as effectiveFrom" - it must cover every date from then on.
      if (rule.effectiveTo == null) return !onlyDate.isBefore(from);
      final to = DateTime(
        rule.effectiveTo!.year,
        rule.effectiveTo!.month,
        rule.effectiveTo!.day,
      );
      return !onlyDate.isBefore(from) && !onlyDate.isAfter(to);
    }

    final onDate = availability.where(covers);
    final vacation = onDate.any(
      (rule) => rule.kind == AvailabilityKind.vacation,
    );
    if (windows.isEmpty) {
      return vacation ? _DayStatus.vacation : _DayStatus.off;
    }

    final weekday = _weekdaysInOrder[date.weekday - 1];
    final hasBaseline = onDate.any(
      (rule) =>
          rule.kind == AvailabilityKind.modified ||
          (rule.kind == AvailabilityKind.regular && rule.dayOfWeek == weekday),
    );
    return hasBaseline ? _DayStatus.working : _DayStatus.extraDay;
  }

  String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  String _weekdayLabel(DateTime date) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][date.weekday - 1];

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];

  String _longDate(DateTime date) =>
      '${date.day} ${_monthName(date.month)} ${date.year}';

  String _shortDate(DateTime date) =>
      '${date.day} ${_monthName(date.month).substring(0, 3)} ${date.year}';
}
