import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/doctor_availability_api.dart';
import 'availability_sessions_view.dart' show resolveAvailableWindows;

/// What the dialog hands back on Save; the screen turns this into a
/// create/update API call.
class AvailabilityDraft {
  const AvailabilityDraft({
    required this.kind,
    this.day,
    this.start,
    this.end,
    required this.from,
    this.to,
    this.isSplit = false,
  });

  final AvailabilityKind kind;
  final AvailabilityDay? day;

  /// "HH:mm:ss"; null for VACATION, which carries no time window.
  final String? start;
  final String? end;
  final DateTime from;
  final DateTime? to;

  /// True when this draft describes the new, forward-looking record of a
  /// split edit: the original entry already started, so its past portion is
  /// left untouched and this draft becomes a fresh record starting today.
  final bool isSplit;
}

class _KindMeta {
  const _KindMeta(this.label, this.icon, this.bg, this.color);

  final String label;
  final IconData icon;
  final Color bg;
  final Color color;
}

const Map<AvailabilityKind, _KindMeta> _kindMeta = {
  AvailabilityKind.regular: _KindMeta(
    'Regular',
    Icons.event_repeat,
    AppColors.bgSage,
    AppColors.sageDark,
  ),
  AvailabilityKind.vacation: _KindMeta(
    'Vacation / Leave',
    Icons.beach_access_outlined,
    AppColors.bgLavender,
    AppColors.lav,
  ),
  AvailabilityKind.extraDay: _KindMeta(
    'Extra Working Day',
    Icons.add_circle_outline,
    AppColors.bgRose,
    AppColors.rose,
  ),
  AvailabilityKind.modified: _KindMeta(
    'Modified Hours',
    Icons.edit_calendar_outlined,
    AppColors.goldPale,
    AppColors.gold,
  ),
};

/// Add/edit form for one availability entry. The kind picker only ever offers
/// the category the dialog was opened for: REGULAR when adding/editing a
/// Weekly Schedule slot, or the three exception kinds (VACATION/MODIFIED/
/// EXTRA_DAY) when adding/editing an Exceptions entry - the two categories
/// are never mixed. Every other field is always interactive.
class AvailabilityEntryDialog extends StatefulWidget {
  const AvailabilityEntryDialog({
    super.key,
    required this.availability,
    this.initial,
    this.initialDay,
    this.initialKind,
  });

  /// Every existing entry, used to check whether an EXTRA_DAY date already
  /// has working hours and so can't take one.
  final List<DoctorAvailability> availability;

  /// The item being edited; null when adding a new one.
  final DoctorAvailability? initial;

  /// Pre-selects the day when opened from a Weekly Schedule row's "+ Add slot".
  final AvailabilityDay? initialDay;

  /// Pre-selects the kind when opened from the Exceptions section's "+ Add
  /// Exception" (VACATION, by convention - the most common exception).
  final AvailabilityKind? initialKind;

  @override
  State<AvailabilityEntryDialog> createState() =>
      _AvailabilityEntryDialogState();
}

class _AvailabilityEntryDialogState extends State<AvailabilityEntryDialog> {
  static const TimeOfDay _clinicOpens = TimeOfDay(hour: 7, minute: 0);
  static const TimeOfDay _clinicCloses = TimeOfDay(hour: 23, minute: 59);
  static const int _minDurationMinutes = 30;

  late AvailabilityKind _kind;
  AvailabilityDay? _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late DateTime _from;
  DateTime? _to;

  // Shown inline, not as a SnackBar: a SnackBar renders on the root Scaffold,
  // which sits behind this dialog's modal barrier while it's open - it would
  // show up dimmed and hard to read instead of on top where it's visible.
  String? _errorMessage;

  // A slot (Weekly Schedule) is always REGULAR; an exception (Exceptions
  // section) is always one of the other three - the two categories are
  // never mixed in one dialog, so there's nothing to pick between them.
  late final bool _regularMode;

  static const List<AvailabilityKind> _exceptionKinds = [
    AvailabilityKind.vacation,
    AvailabilityKind.modified,
    AvailabilityKind.extraDay,
  ];

  List<AvailabilityKind> get _availableKinds =>
      _regularMode ? const [AvailabilityKind.regular] : _exceptionKinds;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    _regularMode = item != null
        ? item.kind == AvailabilityKind.regular
        : widget.initialDay != null ||
              widget.initialKind == AvailabilityKind.regular;

    _kind =
        item?.kind ??
        widget.initialKind ??
        (_regularMode ? AvailabilityKind.regular : AvailabilityKind.vacation);
    _day =
        item?.dayOfWeek ??
        widget.initialDay ??
        (_kind == AvailabilityKind.regular ? AvailabilityDay.monday : null);
    _start = _parseTime(item?.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
    _end = _parseTime(item?.endTime) ?? const TimeOfDay(hour: 17, minute: 0);
    final today = _todayOnly();
    // A record with a past portion (it started before today) can't have that
    // portion rewritten. If it's already fully over, editing is blocked
    // outright. Otherwise editing becomes a split: the original record's
    // history stays as-is, and this dialog edits a new record that starts
    // today - so _from is pinned to today rather than the original start.
    _alreadyEnded = item?.hasEnded ?? false;
    _splitMode =
        item != null && item.effectiveFrom.isBefore(today) && !_alreadyEnded;

    _from = _splitMode ? today : (item?.effectiveFrom ?? today);
    _to = _kind == AvailabilityKind.extraDay ? _from : item?.effectiveTo;
    _initialSnapshot = _snapshot();
  }

  late final bool _alreadyEnded;
  late final bool _splitMode;

  late List<Object?> _initialSnapshot;

  List<Object?> _snapshot() => [_kind, _day, _start, _end, _from, _to];

  bool get _isDirty => !listEquals(_snapshot(), _initialSnapshot);

  bool get _isEditing => widget.initial != null;

  // Item 6: once an entry has already started (its original start date is
  // today or earlier), that start date is locked - only a not-yet-started
  // entry's start date may still move, and only forward. In split mode the
  // "start" being locked is today's date, standing in for the new record.
  bool get _fromLockedForEditing =>
      _isEditing && !widget.initial!.effectiveFrom.isAfter(_todayOnly());

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;

  DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _iso(DateTime value) => value.toIso8601String().split('T').first;

  String _dayLabel(AvailabilityDay value) =>
      value.name[0].toUpperCase() + value.name.substring(1);

  Future<void> _pickDate(bool end) async {
    if (_alreadyEnded) return;
    // A locked start date has no picker wired to it at all; this guards a
    // direct call all the same.
    if (!end && _fromLockedForEditing) return;

    final today = _todayOnly();
    final DateTime minimum;
    if (end) {
      // Item 2: "to" can never precede whatever "from" is currently set to.
      minimum = _from;
    } else if (_isEditing) {
      // Item 6: a not-yet-started entry's start may move, but never back to
      // today or earlier.
      minimum = today.add(const Duration(days: 1));
    } else {
      minimum = today;
    }
    final wanted = end ? (_to ?? _from) : _from;
    final selected = await showDatePicker(
      context: context,
      // Never open before the first allowed day - showDatePicker asserts if
      // initialDate precedes firstDate.
      initialDate: wanted.isBefore(minimum) ? minimum : wanted,
      firstDate: minimum,
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    final normalized = DateTime(selected.year, selected.month, selected.day);
    if (!end &&
        _kind == AvailabilityKind.extraDay &&
        _extraDayHasBaselineHours(normalized)) {
      _showError(
        'An extra day can only be added on a date with no working hours.',
      );
      return;
    }
    setState(() {
      _errorMessage = null;
      if (end) {
        _to = normalized;
      } else {
        _from = normalized;
        // Item 3: extra day is always a single date. Item 2: keep an
        // already-picked "to" from being left stranded before the new "from".
        if (_kind == AvailabilityKind.extraDay ||
            (_to != null && _to!.isBefore(_from))) {
          _to = _from;
        }
      }
    });
  }

  // Item 3: EXTRA_DAY can only land on a date whose baseline (everything but
  // other EXTRA_DAY rows, and excluding the entry being edited) resolves to
  // no working hours - the same rule the backend's shadow check enforces,
  // checked here up front so the UI never lets the date be picked at all.
  bool _extraDayHasBaselineHours(DateTime date) {
    final baseline = widget.availability
        .where((a) => a.id != widget.initial?.id)
        .where((a) => a.kind != AvailabilityKind.extraDay)
        .toList();
    return resolveAvailableWindows(date, baseline).isNotEmpty;
  }

  Future<void> _pickTime(bool start) async {
    if (_alreadyEnded) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (selected == null) return;
    if (_minutes(selected) < _minutes(_clinicOpens) ||
        _minutes(selected) > _minutes(_clinicCloses)) {
      _showError(
        'Clinic hours are 7:00 AM - 12:00 AM; pick a time within that range.',
      );
      return;
    }
    // Item 2: deny an end time that doesn't leave a valid window after the
    // start time (and vice versa) at pick time, not just at submit.
    if (start && _minutes(selected) + _minDurationMinutes > _minutes(_end)) {
      _showError(
        'Start time must leave at least 30 minutes before the end time.',
      );
      return;
    }
    if (!start && _minutes(selected) - _minutes(_start) < _minDurationMinutes) {
      _showError('End time must be at least 30 minutes after the start time.');
      return;
    }
    setState(() {
      _errorMessage = null;
      if (start) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final needsDay = _kind == AvailabilityKind.regular;
    final needsTime = _kind != AvailabilityKind.vacation;
    final needsBoundedRange = _kind != AvailabilityKind.regular;

    return AlertDialog(
      title: Text(
        widget.initial == null
            ? 'Add availability'
            : (_alreadyEnded ? 'View availability' : 'Edit availability'),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_splitMode) ...[
                _infoBanner(
                  icon: Icons.info_outline,
                  message:
                      'This entry already started, so what happened before today '
                      "stays unchanged. Saving creates a new entry starting today "
                      'with your changes.',
                  bg: AppColors.bgLavender,
                  border: AppColors.borderLav,
                  color: AppColors.lavDark,
                ),
                const SizedBox(height: 16),
              ],
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgRose,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.rose.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.roseDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodySmall(
                            color: AppColors.roseDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Type',
                style: AppTypography.labelSmall(color: AppColors.textSub),
              ),
              const SizedBox(height: 8),
              _kindGrid(),
              if (needsDay) ...[
                const SizedBox(height: 16),
                Text(
                  'Day of week',
                  style: AppTypography.labelSmall(color: AppColors.textSub),
                ),
                const SizedBox(height: 8),
                _dayChips(),
              ],
              if (needsBoundedRange) ...[
                const SizedBox(height: 16),
                _dateField(
                  label: _kind == AvailabilityKind.extraDay ? 'Date' : 'From',
                  value: _iso(_from),
                  onTap: () => _pickDate(false),
                  locked: _fromLockedForEditing || _alreadyEnded,
                ),
                if (_kind != AvailabilityKind.extraDay) ...[
                  const SizedBox(height: 10),
                  _dateField(
                    label: 'To',
                    value: _to == null ? 'Choose date' : _iso(_to!),
                    onTap: () => _pickDate(true),
                    locked: _alreadyEnded,
                  ),
                ],
              ] else ...[
                const SizedBox(height: 16),
                _dateField(
                  label: 'Effective from',
                  value: _iso(_from),
                  onTap: () => _pickDate(false),
                  locked: _fromLockedForEditing || _alreadyEnded,
                ),
                const SizedBox(height: 10),
                _dateField(
                  label: 'Effective to',
                  value: _to == null ? 'No end date (optional)' : _iso(_to!),
                  onTap: () => _pickDate(true),
                  locked: _alreadyEnded,
                  onClear: _to == null || _alreadyEnded
                      ? null
                      : () => setState(() {
                          _to = null;
                          _errorMessage = null;
                        }),
                ),
              ],
              if (needsTime) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _timeField(
                        'Start time',
                        _start,
                        () => _pickTime(true),
                        enabled: !_alreadyEnded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timeField(
                        'End time',
                        _end,
                        () => _pickTime(false),
                        enabled: !_alreadyEnded,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!_alreadyEnded)
          FilledButton(
            // A fresh create has nothing to be "dirty" against - only an edit
            // needs the check, to avoid saving a no-op change.
            onPressed: (widget.initial == null || _isDirty) ? _save : null,
            child: const Text('Save'),
          ),
      ],
    );
  }

  // A plain Row/Column grid, not GridView: GridView is a Viewport, and
  // AlertDialog's content sizing measures children's intrinsic dimensions -
  // something a Viewport can never report ("RenderShrinkWrappingViewport does
  // not support returning intrinsic dimensions"), which crashed this dialog
  // on every open regardless of shrinkWrap.
  Widget _kindGrid() {
    final kinds = _availableKinds;
    // Item 6: the type can't be changed once editing an existing entry -
    // show only the current kind, same as the single-kind (regular) case.
    if (kinds.length == 1 || _isEditing) {
      return _kindTile(_kind, interactive: false);
    }
    return Column(
      children: [
        for (var i = 0; i < kinds.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < kinds.length ? 8 : 0),
            child: Row(
              children: [
                Expanded(child: _kindTile(kinds[i])),
                const SizedBox(width: 8),
                Expanded(
                  child: i + 1 < kinds.length
                      ? _kindTile(kinds[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _kindTile(AvailabilityKind kind, {bool interactive = true}) {
    final meta = _kindMeta[kind]!;
    final active = !interactive || _kind == kind;
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: active ? meta.bg : AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? meta.color.withValues(alpha: 0.4)
              : AppColors.hairline,
        ),
      ),
      child: Row(
        children: [
          Icon(
            meta.icon,
            size: 16,
            color: active ? meta.color : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              meta.label,
              style: AppTypography.labelSmall(
                color: active ? meta.color : AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (!interactive) return tile;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        _kind = kind;
        _errorMessage = null;
        if (_kind == AvailabilityKind.regular) {
          _day ??= AvailabilityDay.monday;
        }
        // Item 3: extra day is always a single date.
        if (_kind == AvailabilityKind.extraDay) {
          _to = _from;
        }
      }),
      child: tile,
    );
  }

  Widget _dayChips() {
    // A split's new record keeps the same weekday as the original it
    // continues from; only a fresh or not-yet-started slot may pick one.
    final enabled = !_alreadyEnded && !_splitMode;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AvailabilityDay.values.map((day) {
        final active = _day == day;
        return ChoiceChip(
          label: Text(_dayLabel(day).substring(0, 3)),
          selected: active,
          onSelected: !enabled
              ? null
              : (_) => setState(() {
                  _day = day;
                  _errorMessage = null;
                }),
          selectedColor: AppColors.sage.withValues(alpha: 0.18),
          labelStyle: AppTypography.labelSmall(
            color: active ? AppColors.sageDark : AppColors.textMuted,
          ),
          side: BorderSide(
            color: active
                ? AppColors.sage.withValues(alpha: 0.4)
                : AppColors.hairline,
          ),
          backgroundColor: AppColors.bgAlt,
        );
      }).toList(),
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    VoidCallback? onTap,
    VoidCallback? onClear,
    bool locked = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: AppTypography.labelSmall(color: AppColors.textSub),
      ),
      subtitle: Text(
        value,
        style: AppTypography.bodyMedium(
          color: locked ? AppColors.textMuted : AppColors.text,
        ),
      ),
      onTap: locked ? null : onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClear != null)
            IconButton(
              tooltip: 'Clear end date',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          Icon(
            locked ? Icons.lock_outline : Icons.calendar_today_outlined,
            size: 18,
            color: locked ? AppColors.textMuted : null,
          ),
        ],
      ),
    );
  }

  Widget _timeField(
    String label,
    TimeOfDay value,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: AppTypography.labelSmall(color: AppColors.textSub),
      ),
      subtitle: Text(
        value.format(context),
        style: AppTypography.bodyMedium(
          color: enabled ? AppColors.text : AppColors.textMuted,
        ),
      ),
      onTap: enabled ? onTap : null,
      trailing: Icon(
        enabled ? Icons.schedule : Icons.lock_outline,
        size: 18,
        color: enabled ? null : AppColors.textMuted,
      ),
    );
  }

  Widget _infoBanner({
    required IconData icon,
    required String message,
    required Color bg,
    required Color border,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: AppTypography.bodySmall(color: color)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_alreadyEnded) return;
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    if (_kind == AvailabilityKind.regular && _day == null) {
      _showError('Choose a day of the week.');
      return;
    }
    if (_kind != AvailabilityKind.regular && _to == null) {
      _showError('Choose an effective-to date.');
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
    if (_kind == AvailabilityKind.extraDay &&
        _extraDayHasBaselineHours(_from)) {
      _showError(
        'An extra day can only be added on a date with no working hours.',
      );
      return;
    }
    if (_kind != AvailabilityKind.vacation) {
      if (_minutes(_end) <= _minutes(_start)) {
        _showError('End time must be after start time.');
        return;
      }
      if (_minutes(_end) - _minutes(_start) < _minDurationMinutes) {
        _showError('The window must be at least 30 minutes.');
        return;
      }
      if (_minutes(_start) < _minutes(_clinicOpens) ||
          _minutes(_end) > _minutes(_clinicCloses)) {
        _showError(
          'Availability must be within clinic hours (7:00 AM - 12:00 AM).',
        );
        return;
      }
    }

    if (_kind == AvailabilityKind.vacation) {
      final shadowedExtraDays = _vacationOverlappingExtraDayDates();
      if (shadowedExtraDays.isNotEmpty) {
        final confirmed = await _confirmVacationOverridesExtraDay(
          shadowedExtraDays,
        );
        if (confirmed != true) return;
      }
    }
    if (!mounted) return;

    Navigator.pop(
      context,
      AvailabilityDraft(
        kind: _kind,
        day: _kind == AvailabilityKind.regular ? _day : null,
        start: _kind == AvailabilityKind.vacation ? null : _time(_start),
        end: _kind == AvailabilityKind.vacation ? null : _time(_end),
        from: _from,
        to: _kind == AvailabilityKind.extraDay ? _from : _to,
        isSplit: _splitMode,
      ),
    );
  }

  // VACATION always wins over EXTRA_DAY (backend priority: VACATION >
  // MODIFIED > REGULAR, with EXTRA_DAY only ever filling what would
  // otherwise be an empty day) - but the backend's shadow check skips
  // VACATION entirely ("nothing can shadow it"), so it never warns that
  // *this* vacation is about to silently void an existing extra day. That
  // has to be caught here instead.
  List<DateTime> _vacationOverlappingExtraDayDates() {
    final to = _to;
    if (to == null) return const [];
    final dates =
        widget.availability
            .where((a) => a.kind == AvailabilityKind.extraDay)
            .where((a) => a.id != widget.initial?.id)
            .map((a) => a.effectiveFrom)
            .where((date) => !date.isBefore(_from) && !date.isAfter(to))
            .toList()
          ..sort();
    return dates;
  }

  Future<bool?> _confirmVacationOverridesExtraDay(List<DateTime> dates) {
    final datesText = dates.length == 1
        ? _iso(dates.first)
        : '${_iso(dates.first)} through ${_iso(dates.last)} '
              '(${dates.length} day(s))';
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('This also cancels an extra working day'),
        content: Text(
          'An extra working day is already scheduled on $datesText. Saving '
          "this vacation takes priority, so that extra day won't be "
          'available anymore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
  }
}
