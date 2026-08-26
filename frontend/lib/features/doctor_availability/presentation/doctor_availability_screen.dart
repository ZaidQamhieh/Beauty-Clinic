import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/doctor_availability_api.dart';
import 'widgets/availability_entry_dialog.dart';
import 'widgets/day_view_section.dart';
import 'widgets/exceptions_section.dart';
import 'widgets/weekly_schedule_section.dart';

class DoctorAvailabilityScreen extends StatefulWidget {
  const DoctorAvailabilityScreen({super.key, required this.api, this.doctorId});

  final DoctorAvailabilityApi api;

  /// Null when a doctor is viewing their own schedule (every call targets
  /// "me"). Set when an admin is viewing a specific doctor's schedule from
  /// the doctor detail view - every call targets that doctor explicitly.
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
        if (mounted) setState(() => _items = [..._items, saved]);
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
      final confirmed = await _confirmShadow(error);
      if (confirmed == true) {
        await _save(item, draft, acknowledgeShadow: true);
      }
    } on DoctorAvailabilityConflictException catch (error) {
      if (mounted) _showBlockingError('Booked appointments would be affected', error.message);
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

  Future<bool?> _confirmShadow(DoctorAvailabilityShadowedException error) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("This won't take effect yet"),
        content: Text(error.message),
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

  Future<void> _confirmRemove(DoctorAvailability item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this entry?'),
        content: Text(_describe(item)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
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
    try {
      await widget.api.remove(item, doctorId: widget.doctorId);
      if (mounted) {
        setState(() {
          _items = _items.where((current) => current.id != item.id).toList();
        });
      }
    } on DoctorAvailabilityConflictException catch (error) {
      if (mounted) _showBlockingError('Booked appointments would be affected', error.message);
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
                    Text('Availability Schedule', style: AppTypography.displaySubtitle()),
                    const SizedBox(height: 4),
                    Text(
                      'Set your weekly hours and manage vacations, extra days, '
                      'and modified hours.',
                      style: AppTypography.bodySmall(color: AppColors.textMuted),
                    ),
                  ],
                );
                final action = FilledButton.icon(
                  onPressed: () => _openDialog(initialKind: AvailabilityKind.vacation),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Exception'),
                );
                return narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [titleBlock, const SizedBox(height: 12), action],
                      )
                    : Row(
                        children: [Expanded(child: titleBlock), action],
                      );
              },
            ),
            const SizedBox(height: 20),
            DayViewSection(availability: _items),
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
