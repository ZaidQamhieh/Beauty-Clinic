import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/clinic_time.dart';

/// Month view; days with visits get tinted.
class MiniCalendar extends StatefulWidget {
  const MiniCalendar({super.key, required this.markedDates});

  final Set<DateTime> markedDates;

  @override
  State<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<MiniCalendar> {
  static const _months = [
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
  ];
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final today = ClinicTime.at(DateTime.now());
    _month = DateTime(today.year, today.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final todayLocal = ClinicTime.at(DateTime.now());
    final today = DateTime(todayLocal.year, todayLocal.month, todayLocal.day);
    final firstOfMonth = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Monday-first grid; Monday's weekday value is 1.
    final leadingBlanks = firstOfMonth.weekday - 1;

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++)
        const SizedBox(width: 26, height: 26),
      for (var day = 1; day <= daysInMonth; day++)
        _dayCell(DateTime(_month.year, _month.month, day), today),
    ];

    final weeks = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final end = i + 7 < cells.length ? i + 7 : cells.length;
      final week = cells.sublist(i, end);
      while (week.length < 7) {
        week.add(const SizedBox(width: 26, height: 26));
      }
      weeks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: week,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_months[_month.month - 1]} ${_month.year}',
                style: AppTypography.labelMedium(),
              ),
              Row(
                children: [
                  _navButton(Icons.chevron_left, () => _shiftMonth(-1)),
                  _navButton(Icons.chevron_right, () => _shiftMonth(1)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in _weekdayLabels)
                SizedBox(
                  width: 26,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ...weeks,
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 18, color: AppColors.textMuted),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: EdgeInsets.zero,
    );
  }

  Widget _dayCell(DateTime date, DateTime today) {
    final isToday = date == today;
    final isMarked = widget.markedDates.contains(date);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.rose
            : (isMarked ? AppColors.rosePale : null),
        shape: BoxShape.circle,
      ),
      child: Text(
        '${date.day}',
        style:
            AppTypography.bodySmall(
              color: isToday
                  ? AppColors.white
                  : (isMarked ? AppColors.roseDark : AppColors.textSub),
            ).copyWith(
              fontWeight: isToday || isMarked
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
      ),
    );
  }
}
