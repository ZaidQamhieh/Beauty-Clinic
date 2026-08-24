import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/doctor_availability_api.dart';

class DoctorAvailabilityScreen extends StatefulWidget {
  const DoctorAvailabilityScreen({super.key, required this.api, this.onBack});

  final DoctorAvailabilityApi api;
  final VoidCallback? onBack;

  @override
  State<DoctorAvailabilityScreen> createState() =>
      _DoctorAvailabilityScreenState();
}

class _DoctorAvailabilityScreenState extends State<DoctorAvailabilityScreen> {
  List<DoctorAvailability> _items = const [];
  bool _loading = true;
  String? _loadError;
  DateTime _selectedDate = DateTime.now();
  DateTime _displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  Map<String, DayAvailabilityStatus> _calendarStatus = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadCalendarStatus();
  }

  Future<void> _loadCalendarStatus() async {
    final rangeStart = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    ).subtract(const Duration(days: 6));
    final rangeEnd = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).add(const Duration(days: 6));
    try {
      final rows = await widget.api.calendar(from: rangeStart, to: rangeEnd);
      if (!mounted) return;
      setState(() {
        _calendarStatus = {for (final row in rows) _date(row.date): row.status};
      });
    } catch (_) {
      // Dots are decorative; fail silently.
    }
  }

  Future<void> _pickMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _displayedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select month and year',
    );
    if (selected == null) return;
    setState(() {
      _displayedMonth = DateTime(selected.year, selected.month);
    });
    _loadCalendarStatus();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final items = await widget.api.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on DoctorAvailabilityException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Unable to load availability.';
      });
    }
  }

  Future<void> _edit({
    DoctorAvailability? item,
    AvailabilityDay? lockedDay,
    DateTime? lockedDate,
  }) async {
    final result = await showDialog<_AvailabilityDraft>(
      context: context,
      builder: (context) => _AvailabilityDialog(
        initial: item,
        selectedDate: _selectedDate,
        lockedDay: lockedDay,
        lockedDate: lockedDate,
      ),
    );
    if (result == null) {
      return;
    }
    try {
      if (item == null) {
        final created = await widget.api.create(
          kind: result.kind,
          dayOfWeek: result.day,
          startTime: result.start,
          endTime: result.end,
          available: result.available,
          effectiveFrom: result.from,
          effectiveTo: result.to,
        );
        if (mounted) {
          setState(() => _items = [..._items, created]);
        }
        _loadCalendarStatus();
      } else {
        final updated = await widget.api.update(
          item,
          kind: result.kind,
          dayOfWeek: result.day,
          startTime: result.start,
          endTime: result.end,
          available: result.available,
          effectiveFrom: result.from,
          effectiveTo: result.to,
        );
        if (mounted) {
          setState(() {
            _items = [
              for (final current in _items)
                current.id == updated.id ? updated : current,
            ];
          });
        }
        _loadCalendarStatus();
      }
    } on DoctorAvailabilityException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save availability.')),
        );
      }
    }
  }

  Future<void> _remove(DoctorAvailability item) async {
    try {
      await widget.api.remove(item);
      if (mounted) {
        setState(() {
          _items = _items.where((current) => current.id != item.id).toList();
        });
      }
      _loadCalendarStatus();
    } on DoctorAvailabilityException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete availability.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onBack != null)
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Dashboard'),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 520;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Doctor availability',
                    style: AppTypography.displaySubtitle(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a weekday below for a recurring schedule, or select a '
                    'date to add a one-time override.',
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                ],
              );
              final actions = Tooltip(
                message:
                    'Create a rule manually, with full control over kind, '
                    'day, and dates',
                child: FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add availability'),
                ),
              );
              return narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        const SizedBox(height: 12),
                        actions,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: titleBlock),
                        actions,
                      ],
                    );
            },
          ),
        ),
        _buildCalendar(),
        Expanded(
          child: _loading
              ? const SkeletonList(itemCount: 5)
              : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () {
                            _load();
                            _loadCalendarStatus();
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _itemsForDate(_selectedDate).isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _items.isEmpty
                          ? 'No availability has been added yet. Tap a '
                                'weekday above to set up a recurring schedule.'
                          : 'No rules apply on ${_date(_selectedDate)}. Use '
                                '"Add override" below the calendar to add one.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  itemCount: _itemsForDate(_selectedDate).length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _itemsForDate(_selectedDate)[index];
                    return _buildRuleCard(item);
                  },
                ),
        ),
      ],
    );
  }

  String _title(DoctorAvailability item) {
    final kind = item.kind == AvailabilityKind.recurring
        ? 'Recurring'
        : 'Override';
    final day = item.dayOfWeek == null
        ? 'Dated rule'
        : _pretty(item.dayOfWeek!.name);
    return '$kind · $day';
  }

  Widget _buildRuleCard(DoctorAvailability item) {
    final statusColor = item.available ? AppColors.sage : AppColors.rose;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 58,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(item), style: AppTypography.labelLarge()),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _metaChip(
                      Icons.schedule,
                      '${item.startTime} - ${item.endTime}',
                    ),
                    _metaChip(
                      item.available ? Icons.check_circle_outline : Icons.block,
                      item.available ? 'Available' : 'Unavailable',
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_subtitle(item), style: AppTypography.bodySmall()),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) =>
                action == 'edit' ? _edit(item: item) : _remove(item),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textMuted).withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.labelSmall(color: color ?? AppColors.textSub),
          ),
        ],
      ),
    );
  }

  String _subtitle(DoctorAvailability item) =>
      'Effective ${_date(item.effectiveFrom)}'
      '${item.effectiveTo == null ? '' : ' through ${_date(item.effectiveTo!)}'}';

  String _pretty(String value) =>
      value[0].toUpperCase() + value.substring(1).toLowerCase();

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Widget _buildCalendar() {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final leading = firstDay.weekday - 1;
    final cells = List<DateTime?>.filled(leading, null, growable: true)
      ..addAll(
        List.generate(
          daysInMonth,
          (index) =>
              DateTime(_displayedMonth.year, _displayedMonth.month, index + 1),
        ),
      );
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month - 1,
                      );
                    });
                    _loadCalendarStatus();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Tooltip(
                    message: 'Jump to a month and year',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: _pickMonth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_monthName(_displayedMonth.month)} ${_displayedMonth.year}',
                              style: AppTypography.labelLarge(),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month + 1,
                      );
                    });
                    _loadCalendarStatus();
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: AvailabilityDay.values
                  .map(
                    (day) => Expanded(
                      child: Tooltip(
                        message:
                            'Add a recurring schedule for ${_pretty(day.name)}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _edit(lockedDay: day),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Center(
                              child: Text(
                                _shortDayLabel(day),
                                style: AppTypography.labelSmall(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 30,
              ),
              itemBuilder: (context, index) {
                final date = cells[index];
                if (date == null) return const SizedBox.shrink();
                final selected = _sameDate(date, _selectedDate);
                final status = _calendarStatus[_date(date)];
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.rose.withValues(alpha: .16)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: selected
                          ? Border.all(color: AppColors.rose)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${date.day}', style: AppTypography.bodySmall()),
                        if (status != null &&
                            status != DayAvailabilityStatus.none)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: status == DayAvailabilityStatus.available
                                  ? AppColors.sage
                                  : AppColors.rose,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _legendDot(AppColors.sage),
                const SizedBox(width: 6),
                Text(
                  'Available',
                  style: AppTypography.bodySmall(color: AppColors.textMuted),
                ),
                const SizedBox(width: 16),
                _legendDot(AppColors.rose),
                const SizedBox(width: 6),
                Text(
                  'Unavailable',
                  style: AppTypography.bodySmall(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selected: ${_date(_selectedDate)} · ${_itemsForDate(_selectedDate).length} schedule rule(s)',
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                ),
                Tooltip(
                  message: _selectedDate.isBefore(_todayOnly())
                      ? 'Overrides can only be added for today or a future date'
                      : 'Create a one-time schedule change for the selected date',
                  child: TextButton.icon(
                    onPressed: _selectedDate.isBefore(_todayOnly())
                        ? null
                        : () => _edit(lockedDate: _selectedDate),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add override'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<DoctorAvailability> _itemsForDate(DateTime date) {
    return _items.where((item) {
      final inRange =
          !date.isBefore(item.effectiveFrom) &&
          (item.effectiveTo == null || !date.isAfter(item.effectiveTo!));
      final matchesDay =
          item.kind == AvailabilityKind.override ||
          item.dayOfWeek?.name == _dayName(date.weekday);
      return inRange && matchesDay;
    }).toList();
  }

  Widget _legendDot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  String _shortDayLabel(AvailabilityDay day) => const {
    AvailabilityDay.monday: 'Mon',
    AvailabilityDay.tuesday: 'Tue',
    AvailabilityDay.wednesday: 'Wed',
    AvailabilityDay.thursday: 'Thu',
    AvailabilityDay.friday: 'Fri',
    AvailabilityDay.saturday: 'Sat',
    AvailabilityDay.sunday: 'Sun',
  }[day]!;

  String _dayName(int weekday) => const [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ][weekday - 1];

  bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  DateTime _todayOnly() {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day);
  }

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
}

class _AvailabilityDraft {
  const _AvailabilityDraft(
    this.kind,
    this.day,
    this.start,
    this.end,
    this.available,
    this.from,
    this.to,
  );
  final AvailabilityKind kind;
  final AvailabilityDay? day;
  final String start;
  final String end;
  final bool available;
  final DateTime from;
  final DateTime? to;
}

class _AvailabilityDialog extends StatefulWidget {
  const _AvailabilityDialog({
    this.initial,
    required this.selectedDate,
    this.lockedDay,
    this.lockedDate,
  });
  final DoctorAvailability? initial;
  final DateTime selectedDate;
  // Set from the weekday header only.
  final AvailabilityDay? lockedDay;
  // Locks kind to override, from "Add override".
  final DateTime? lockedDate;
  @override
  State<_AvailabilityDialog> createState() => _AvailabilityDialogState();
}

class _AvailabilityDialogState extends State<_AvailabilityDialog> {
  late AvailabilityKind _kind;
  AvailabilityDay? _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late DateTime _from;
  DateTime? _to;
  late bool _available;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    final lockedDay = widget.lockedDay;
    final lockedDate = widget.lockedDate;

    _kind =
        item?.kind ??
        (lockedDate != null
            ? AvailabilityKind.override
            : AvailabilityKind.recurring);
    _day = item?.dayOfWeek ?? lockedDay ?? AvailabilityDay.monday;
    _start = _parseTime(item?.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
    _end = _parseTime(item?.endTime) ?? const TimeOfDay(hour: 17, minute: 0);
    final today = DateTime.now();
    final selected = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (item != null) {
      _from = item.effectiveFrom;
    } else if (lockedDate != null) {
      _from = DateTime(lockedDate.year, lockedDate.month, lockedDate.day);
    } else {
      _from = selected.isBefore(todayOnly) ? todayOnly : selected;
    }
    _to = item?.effectiveTo;
    _available = item?.available ?? true;
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length < 2) {
      return null;
    }
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickDate(bool end) async {
    final minimum = widget.initial == null && !end
        ? _todayOnly()
        : DateTime(2000);
    final selected = await showDatePicker(
      context: context,
      initialDate: end ? (_to ?? _from) : _from,
      firstDate: minimum,
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      if (end) {
        _to = selected;
      } else {
        _from = selected;
      }
    });
  }

  Future<void> _pickTime(bool start) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (selected == null) {
      return;
    }
    setState(() {
      if (start) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  String _dayLabel(AvailabilityDay value) =>
      value.name[0].toUpperCase() + value.name.substring(1);

  String _iso(DateTime value) => value.toIso8601String().split('T').first;

  @override
  Widget build(BuildContext context) {
    final override = _kind == AvailabilityKind.override;
    final isCreate = widget.initial == null;
    final kindLocked =
        isCreate && (widget.lockedDay != null || widget.lockedDate != null);
    final dayLocked =
        (isCreate && widget.lockedDay != null) ||
        (!isCreate && widget.initial!.kind == AvailabilityKind.recurring);
    final fromLocked = isCreate && widget.lockedDate != null;
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Add availability' : 'Edit availability',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              kindLocked
                  ? InputDecorator(
                      decoration: const InputDecoration(labelText: 'Kind'),
                      child: Row(
                        children: [
                          Text(
                            override
                                ? 'Dated override'
                                : 'Recurring weekly rule',
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    )
                  : AppDropdownField<AvailabilityKind>(
                      initialValue: _kind,
                      decoration: const InputDecoration(labelText: 'Kind'),
                      items: AvailabilityKind.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value == AvailabilityKind.recurring
                                    ? 'Recurring weekly rule'
                                    : 'Dated override',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _kind = value!;
                        if (_kind == AvailabilityKind.recurring &&
                            _day == null) {
                          _day = AvailabilityDay.monday;
                        }
                      }),
                    ),
              if (!override)
                dayLocked
                    ? InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Day of week',
                        ),
                        child: Row(
                          children: [
                            Text(_day == null ? '—' : _dayLabel(_day!)),
                            const Spacer(),
                            const Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      )
                    : AppDropdownField<AvailabilityDay>(
                        initialValue: _day,
                        decoration: const InputDecoration(
                          labelText: 'Day of week',
                        ),
                        items: AvailabilityDay.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_dayLabel(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _day = value),
                      ),
              SwitchListTile(
                title: const Text('Available'),
                value: _available,
                onChanged: (value) => setState(() => _available = value),
              ),
              ListTile(
                title: Text('Start: ${_start.format(context)}'),
                onTap: () => _pickTime(true),
                trailing: const Icon(Icons.schedule),
              ),
              ListTile(
                title: Text('End: ${_end.format(context)}'),
                onTap: () => _pickTime(false),
                trailing: const Icon(Icons.schedule),
              ),
              fromLocked
                  ? ListTile(
                      title: Text('Effective from: ${_iso(_from)}'),
                      trailing: const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    )
                  : ListTile(
                      title: Text('Effective from: ${_iso(_from)}'),
                      onTap: () => _pickDate(false),
                      trailing: const Icon(Icons.calendar_today),
                    ),
              ListTile(
                title: Text(
                  'Effective to: ${_to == null ? (override ? 'Choose date' : 'No end date (optional)') : _iso(_to!)}',
                ),
                onTap: () => _pickDate(true),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_to != null && !override)
                      IconButton(
                        tooltip: 'Clear end date',
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _to = null),
                        icon: const Icon(Icons.close),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    final endMinutes = _end.hour * 60 + _end.minute;
    final startMinutes = _start.hour * 60 + _start.minute;
    if (endMinutes <= startMinutes) {
      _showError('End time must be after start time.');
      return;
    }
    if (_kind == AvailabilityKind.recurring && _day == null) {
      _showError('Choose a day of the week.');
      return;
    }
    if (_kind == AvailabilityKind.override && _to == null) {
      _showError('Choose an effective-to date for an override.');
      return;
    }
    if (_to != null && _to!.isBefore(_from)) {
      _showError('Effective-to date must not be before effective-from date.');
      return;
    }
    if (widget.initial == null && _from.isBefore(_todayOnly())) {
      _showError('Effective from must be today or later.');
      return;
    }
    Navigator.pop(
      context,
      _AvailabilityDraft(
        _kind,
        _kind == AvailabilityKind.override ? null : _day,
        _time(_start),
        _time(_end),
        _available,
        _from,
        _to,
      ),
    );
  }

  DateTime _todayOnly() {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
