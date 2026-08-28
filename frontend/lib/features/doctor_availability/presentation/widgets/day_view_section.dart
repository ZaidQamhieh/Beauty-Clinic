import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../appointments/data/appointment.dart';
import '../../data/doctor_availability_api.dart';
import 'availability_sessions_view.dart'
    show DayHoursBar, DayWindow, resolveAvailableWindows;

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
  const DayViewSection({
    super.key,
    required this.availability,
    required this.fetchSessions,
  });

  final List<DoctorAvailability> availability;

  /// Booked visits for the picked day, so the hours bar can shade them in
  /// alongside available/unavailable time.
  final Future<List<Appointment>> Function(DateTime date) fetchSessions;

  @override
  State<DayViewSection> createState() => _DayViewSectionState();
}

class _DayViewSectionState extends State<DayViewSection> {
  late DateTime _date;
  late Future<List<Appointment>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _sessionsFuture = widget.fetchSessions(_date);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstSelectable = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(firstSelectable) ? firstSelectable : _date,
      firstDate: firstSelectable,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _sessionsFuture = widget.fetchSessions(_date);
      });
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
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Appointment>>(
            future: _sessionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Skeleton(width: double.infinity, height: 28);
              }
              final sessions = <AppointmentSession>[
                for (final appointment in snapshot.data ?? const [])
                  ...appointment.sessions,
              ];
              return DayHoursBar(
                date: _date,
                availability: widget.availability,
                sessions: sessions,
              );
            },
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
