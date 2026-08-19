import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/clinic_time.dart';

/// Month view; tap a day to filter.
class MiniCalendar extends StatefulWidget {
  const MiniCalendar({
    super.key,
    required this.markedDates,
    required this.selectedDate,
    required this.onDaySelected,
    this.onDayHovered,
    this.showFrame = true,
  });

  final Set<DateTime> markedDates;

  /// Day being filtered on, null for none.
  final DateTime? selectedDate;

  /// Null clears the filter.
  final ValueChanged<DateTime?> onDaySelected;

  /// Pointer entering a day; null on exit.
  final ValueChanged<DateTime?>? onDayHovered;

  /// False inside a card already framed.
  final bool showFrame;

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

  // Compact so history list keeps room.
  static const _cell = 22.0;

  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final today = ClinicTime.at(DateTime.now());
    _month = DateTime(today.year, today.month);
  }

  // Outside selection pulls grid to its month.
  @override
  void didUpdateWidget(MiniCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedDate;
    if (selected == null || selected == oldWidget.selectedDate) return;
    if (selected.year == _month.year && selected.month == _month.month) return;
    _month = DateTime(selected.year, selected.month);
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
        const SizedBox(width: _cell, height: _cell),
      for (var day = 1; day <= daysInMonth; day++)
        _dayCell(DateTime(_month.year, _month.month, day), today),
    ];

    final weeks = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final end = i + 7 < cells.length ? i + 7 : cells.length;
      final week = cells.sublist(i, end);
      while (week.length < 7) {
        week.add(const SizedBox(width: _cell, height: _cell));
      }
      weeks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: week,
          ),
        ),
      );
    }

    return Container(
      padding: widget.showFrame ? const EdgeInsets.all(10) : EdgeInsets.zero,
      decoration: widget.showFrame
          ? BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            )
          : null,
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in _weekdayLabels)
                SizedBox(
                  width: _cell,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          ...weeks,
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 16, color: AppColors.textMuted),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: EdgeInsets.zero,
    );
  }

  Widget _dayCell(DateTime date, DateTime today) {
    final isToday = date == today;
    final isMarked = widget.markedDates.contains(date);
    final isSelected = date == widget.selectedDate;
    final hover = widget.onDayHovered;
    return MouseRegion(
      // Touch lacks hover; tapping previews and filters.
      onEnter: hover == null ? null : (_) => hover(date),
      onExit: hover == null ? null : (_) => hover(null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // Tapping selected day again clears filter.
        onTap: () => widget.onDaySelected(isSelected ? null : date),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _cell,
          height: _cell,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday
                ? AppColors.rose
                : (isMarked ? AppColors.rosePale : null),
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: AppColors.roseDark, width: 1.5)
                : null,
          ),
          child: Text(
            '${date.day}',
            style:
                AppTypography.bodySmall(
                  color: isToday
                      ? AppColors.white
                      : (isMarked || isSelected
                            ? AppColors.roseDark
                            : AppColors.textSub),
                ).copyWith(
                  fontWeight: isToday || isMarked || isSelected
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
          ),
        ),
      ),
    );
  }
}
