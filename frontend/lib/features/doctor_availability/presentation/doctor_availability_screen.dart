import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_dialog.dart';
import '../../../core/widgets/skeleton.dart';
import '../../appointments/data/appointment_api.dart';
import '../data/doctor_availability_api.dart';
import 'widgets/availability_entry_dialog.dart';
import 'widgets/day_view_section.dart';
import 'widgets/exceptions_section.dart';
import 'widgets/weekly_schedule_section.dart';

class DoctorAvailabilityScreen extends StatefulWidget {
  const DoctorAvailabilityScreen({
    super.key,
    required this.api,
    required this.appointmentApi,
    this.doctorId,
  });

  final DoctorAvailabilityApi api;
  final AppointmentApi appointmentApi;

  /// Null targets "me"; set targets that doctor.
  final String? doctorId;

  @override
  State<DoctorAvailabilityScreen> createState() =>
      _DoctorAvailabilityScreenState();
}

class _DoctorAvailabilityScreenState extends State<DoctorAvailabilityScreen> {
  List<DoctorAvailability> _items = const [];
  bool _loading = true;
  String? _loadError;

  List<DoctorAvailability> get _regular =>
      _items.where((item) => item.kind == AvailabilityKind.regular).toList();

  List<DoctorAvailability> get _exceptions =>
      _items.where((item) => item.kind != AvailabilityKind.regular).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final doctorId = widget.doctorId;
      final items = doctorId == null
          ? await widget.api.list()
          : await widget.api.listForDoctor(doctorId);
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

  Future<void> _openDialog({
    DoctorAvailability? item,
    AvailabilityDay? initialDay,
    AvailabilityKind? initialKind,
  }) async {
    final draft = await showDialog<AvailabilityDraft>(
      context: context,
      builder: (context) => AvailabilityEntryDialog(
        availability: _items,
        initial: item,
        initialDay: initialDay,
        initialKind: initialKind,
      ),
    );
    if (draft == null) return;
    await _save(item, draft, acknowledgeShadow: false);
  }

  Future<void> _save(
    DoctorAvailability? item,
    AvailabilityDraft draft, {
    required bool acknowledgeShadow,
  }) async {
    // An entry that's already started can't have its past portion rewritten:
    // the dialog hands back a split draft instead, which is saved as two
    // records rather than one in-place update.
    if (draft.isSplit && item != null) {
      await _saveSplit(item, draft, acknowledgeShadow: acknowledgeShadow);
      return;
    }
    final previous = _items;
    // Shows now; server confirms after.
    final optimistic = DoctorAvailability(
      id: item?.id ?? 'pending-${DateTime.now().microsecondsSinceEpoch}',
      kind: draft.kind,
      dayOfWeek: draft.day,
      startTime: draft.start,
      endTime: draft.end,
      effectiveFrom: draft.from,
      effectiveTo: draft.to,
    );
    setState(() {
      _items = item == null
          ? [..._items, optimistic]
          : [
              for (final current in _items)
                current.id == item.id ? optimistic : current,
            ];
    });

    try {
      final DoctorAvailability saved;
      if (item == null) {
        saved = await widget.api.create(
          kind: draft.kind,
          dayOfWeek: draft.day,
          startTime: draft.start,
          endTime: draft.end,
          effectiveFrom: draft.from,
          effectiveTo: draft.to,
          acknowledgeShadow: acknowledgeShadow,
          doctorId: widget.doctorId,
        );
        if (mounted) {
          setState(() {
            _items = [
              for (final current in _items)
                current.id == optimistic.id ? saved : current,
            ];
          });
        }
      } else {
        saved = await widget.api.update(
          item,
          kind: draft.kind,
          dayOfWeek: draft.day,
          startTime: draft.start,
          endTime: draft.end,
          effectiveFrom: draft.from,
          effectiveTo: draft.to,
          acknowledgeShadow: acknowledgeShadow,
          doctorId: widget.doctorId,
        );
        if (mounted) {
          setState(() {
            _items = [
              for (final current in _items)
                current.id == saved.id ? saved : current,
            ];
          });
        }
      }
    } on DoctorAvailabilityShadowedException catch (error) {
      if (!mounted) return;
      // Not saved yet; roll back while confirming.
      setState(() => _items = previous);
      final confirmed = await _confirmShadow(error, draft.kind);
      if (confirmed == true) {
        await _save(item, draft, acknowledgeShadow: true);
      }
    } on DoctorAvailabilityConflictException catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      _showBlockingError(
        'Booked appointments would be affected',
        error.message,
      );
    } on DoctorAvailabilityException catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      showErrorDialog(context, error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
      showErrorDialog(context, 'Unable to save availability.');
    }
  }

  // Saves an edit to an already-started entry as two records instead of one
  // in-place update: the original is truncated to end yesterday (its past
  // portion - and anything already true about it - is left untouched), and
  // the edited values become a new record starting today. Both changes go
  // through the backend's split endpoint as one atomic operation, so there's
  // no moment in between where the truncated original has already dropped
  // today onward but the new record hasn't landed yet - and so nothing to
  // roll back by hand if it's refused.
  Future<void> _saveSplit(
    DoctorAvailability item,
    AvailabilityDraft draft, {
    required bool acknowledgeShadow,
  }) async {
    final previous = _items;
    final yesterday = draft.from.subtract(const Duration(days: 1));
    final optimisticTruncated = DoctorAvailability(
      id: item.id,
      kind: item.kind,
      dayOfWeek: item.dayOfWeek,
      startTime: item.startTime,
      endTime: item.endTime,
      effectiveFrom: item.effectiveFrom,
      effectiveTo: yesterday,
    );
    final optimisticNew = DoctorAvailability(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      kind: draft.kind,
      dayOfWeek: draft.day,
      startTime: draft.start,
      endTime: draft.end,
      effectiveFrom: draft.from,
      effectiveTo: draft.to,
    );
    setState(() {
      _items = [
        for (final current in _items)
          current.id == item.id ? optimisticTruncated : current,
        optimisticNew,
      ];
    });

    try {
      await widget.api.split(
        item,
        splitDate: draft.from,
        newKind: draft.kind,
        newDayOfWeek: draft.day,
        newStartTime: draft.start,
        newEndTime: draft.end,
        newEffectiveTo: draft.to,
        acknowledgeShadow: acknowledgeShadow,
        doctorId: widget.doctorId,
      );
      // The original weekly slot ran indefinitely; if the edit now caps the
      // new record with an end date, the slot would otherwise vanish once
      // that date passes. Re-add a third, indefinite record with the
      // original hours starting the day after, so the schedule reverts to
      // what it was once this temporary change is over.
      if (item.kind == AvailabilityKind.regular &&
          item.effectiveTo == null &&
          draft.to != null) {
        await _restorePreviousAfterSplit(item, draft.to!);
      }
      if (!mounted) return;
      // Fetches the real records (with server-assigned ids) instead of
      // reconciling the optimistic placeholders by hand.
      await _load();
    } on DoctorAvailabilityShadowedException catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      final confirmed = await _confirmShadow(error, draft.kind);
      if (confirmed == true) {
        await _saveSplit(item, draft, acknowledgeShadow: true);
      }
    } on DoctorAvailabilityConflictException catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      _showBlockingError(
        'Booked appointments would be affected',
        error.message,
      );
    } on DoctorAvailabilityException catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      showErrorDialog(context, error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
      showErrorDialog(context, 'Unable to save availability.');
    }
  }

  // Best-effort: re-adds the original (pre-edit) hours as a fresh,
  // indefinite record right after the split's newly-bounded record ends.
  // Failing silently here still leaves the edit itself saved - it only
  // means the automatic revert has to be added by hand.
  Future<void> _restorePreviousAfterSplit(
    DoctorAvailability original,
    DateTime splitEnd,
  ) async {
    try {
      await widget.api.create(
        kind: original.kind,
        dayOfWeek: original.dayOfWeek,
        startTime: original.startTime,
        endTime: original.endTime,
        effectiveFrom: splitEnd.add(const Duration(days: 1)),
        effectiveTo: null,
        acknowledgeShadow: true,
        doctorId: widget.doctorId,
      );
    } catch (_) {
      // Best-effort; the primary edit already succeeded regardless.
    }
  }

  Future<bool?> _confirmShadow(
    DoctorAvailabilityShadowedException error,
    AvailabilityKind attemptedKind,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("This won't take effect yet"),
        content: Text(_shadowMessage(error, attemptedKind)),
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

  // Item 4: adding/editing a REGULAR or MODIFIED entry that's shadowed by an
  // existing VACATION gets its own message - "Save anyway" here doesn't
  // override the leave, it only queues the entry to take effect once the
  // leave ends or is removed, which the backend's generic shadow message
  // doesn't make clear.
  String _shadowMessage(
    DoctorAvailabilityShadowedException error,
    AvailabilityKind attemptedKind,
  ) {
    final overridesVacation =
        error.shadowedBy == AvailabilityKind.vacation &&
        (attemptedKind == AvailabilityKind.regular ||
            attemptedKind == AvailabilityKind.modified);
    if (!overridesVacation) return error.message;
    return 'Vacation/leave is already scheduled on '
        '${_describeDates(error.affectedDates)}. Saving this now won\'t '
        'override that leave - it will only take effect once the leave ends '
        'or is removed.';
  }

  String _describeDates(List<DateTime> dates) {
    if (dates.isEmpty) return 'the selected dates';
    if (dates.length == 1) return _date(dates.first);
    return '${_date(dates.first)} through ${_date(dates.last)} '
        '(${dates.length} day(s))';
  }

  void _showBlockingError(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // An entry that already started can't just vanish outright - that would
  // erase what was true on the days already gone by. Removing it instead
  // keeps everything up to yesterday as-is and drops only today onward
  // (still refused if a booked appointment needs those future dates).
  bool _removalKeepsHistory(DoctorAvailability item) =>
      item.effectiveFrom.isBefore(_todayOnly()) && !item.hasEnded;

  Future<void> _confirmRemove(DoctorAvailability item) async {
    final keepsHistory = _removalKeepsHistory(item);
    final confirmed = await confirmDanger(
      context,
      title: 'Remove this entry?',
      message: keepsHistory
          ? '${_describe(item)}\n\nThis already started, so only today '
                "onward is removed - what's already happened stays on "
                'record.'
          : _describe(item),
      confirmLabel: 'Remove',
    );
    if (confirmed && mounted) {
      await _remove(item);
    }
  }

  String _describe(DoctorAvailability item) {
    final range = item.effectiveTo == null
        ? _date(item.effectiveFrom)
        : (item.effectiveFrom == item.effectiveTo
              ? _date(item.effectiveFrom)
              : '${_date(item.effectiveFrom)} → ${_date(item.effectiveTo!)}');
    if (item.kind == AvailabilityKind.regular) {
      final day = item.dayOfWeek == null ? '' : item.dayOfWeek!.name;
      return '${day.isEmpty ? '' : '${day[0].toUpperCase()}${day.substring(1)} · '}'
          '${_short(item.startTime)} - ${_short(item.endTime)}';
    }
    if (item.kind == AvailabilityKind.vacation) {
      return 'Vacation · $range';
    }
    return '${item.kind == AvailabilityKind.modified ? 'Modified hours' : 'Extra day'} '
        '· $range · ${_short(item.startTime)} - ${_short(item.endTime)}';
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _short(String? value) =>
      value == null || value.length < 5 ? (value ?? '') : value.substring(0, 5);

  Future<void> _remove(DoctorAvailability item) async {
    if (_removalKeepsHistory(item)) {
      await _removeFutureOnly(item);
      return;
    }

    final previous = _items;
    // Leaves now; the cutoff may refuse it.
    setState(() {
      _items = _items.where((current) => current.id != item.id).toList();
    });

    try {
      await widget.api.remove(item, doctorId: widget.doctorId);
    } on DoctorAvailabilityConflictException catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      _showBlockingError(
        'Booked appointments would be affected',
        error.message,
      );
    } on DoctorAvailabilityException catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      showErrorDialog(context, error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
      showErrorDialog(context, 'Unable to delete availability.');
    }
  }

  // Removing an already-started entry is really a truncation: shrink its
  // effective-to date to yesterday instead of deleting the row, so the past
  // it already covered is left exactly as it was. Goes through the split
  // endpoint with no new segment, which still refuses the whole thing if a
  // booked future appointment would fall outside the resulting schedule.
  Future<void> _removeFutureOnly(DoctorAvailability item) async {
    final previous = _items;
    final today = _todayOnly();
    final truncated = DoctorAvailability(
      id: item.id,
      kind: item.kind,
      dayOfWeek: item.dayOfWeek,
      startTime: item.startTime,
      endTime: item.endTime,
      effectiveFrom: item.effectiveFrom,
      effectiveTo: today.subtract(const Duration(days: 1)),
    );
    setState(() {
      _items = [
        for (final current in _items)
          current.id == item.id ? truncated : current,
      ];
    });

    try {
      await widget.api.split(item, splitDate: today, doctorId: widget.doctorId);
    } on DoctorAvailabilityConflictException catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      _showBlockingError(
        'Booked appointments would be affected',
        error.message,
      );
    } on DoctorAvailabilityException catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      showErrorDialog(context, error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
      showErrorDialog(context, 'Unable to delete availability.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: SkeletonList(itemCount: 5),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 480;
                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Availability Schedule',
                      style: AppTypography.displaySubtitle(),
                    ),
                  ],
                );
                final action = FilledButton.icon(
                  onPressed: () =>
                      _openDialog(initialKind: AvailabilityKind.vacation),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Exception'),
                );
                return narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleBlock,
                          const SizedBox(height: 12),
                          action,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: titleBlock),
                          action,
                        ],
                      );
              },
            ),
            const SizedBox(height: 20),
            DayViewSection(
              availability: _items,
              fetchSessions: (date) {
                final doctorId = widget.doctorId;
                return doctorId == null
                    ? widget.appointmentApi.myScheduleFor(date)
                    : widget.appointmentApi.scheduleFor(doctorId, date);
              },
            ),
            const SizedBox(height: 16),
            WeeklyScheduleSection(
              regular: _regular,
              onAdd: (day) => _openDialog(initialDay: day),
              onEdit: (item) => _openDialog(item: item),
              onDelete: _confirmRemove,
            ),
            const SizedBox(height: 16),
            ExceptionsSection(
              exceptions: _exceptions,
              onAdd: () => _openDialog(initialKind: AvailabilityKind.vacation),
              onEdit: (item) => _openDialog(item: item),
              onDelete: _confirmRemove,
            ),
          ],
        ),
      ),
    );
  }
}
