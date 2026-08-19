import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../network/api_client.dart';
import '../../forms/data/clinical_intake_api.dart';
import '../../forms/data/clinical_intake_schema.dart';
import '../data/appointment.dart';
import '../data/appointment_api.dart';
import '../data/booking_exceptions.dart';
import '../data/clinic_time.dart';
import '../data/doctor_api.dart';
import '../data/treatment_api.dart';
import 'appointment_card.dart';
import 'booking_flow_sheet.dart';
import 'booking_format.dart';
import 'booking_result_steps.dart';
import 'history_filter_drawer.dart';

/// The patient's own appointments: upcoming and history.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    super.key,
    required this.appointmentApi,
    required this.treatmentApi,
    required this.doctorApi,
    required this.bookedSignal,
    this.refreshSignal,
    this.clinicalApi,
    this.onNavigateToForms,
  });

  final AppointmentApi appointmentApi;
  final TreatmentApi treatmentApi;
  final DoctorApi doctorApi;
  final ClinicalIntakeApi? clinicalApi;
  final VoidCallback? onNavigateToForms;

  /// Fires when booked elsewhere; cleared once read.
  final ValueNotifier<Appointment?> bookedSignal;

  /// Ticks when the bot books or cancels.
  final Listenable? refreshSignal;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Appointment>? _upcoming;
  List<Appointment>? _history;
  bool _loading = true;
  String? _error;

  int _upcomingPage = 0;
  int _historyPage = 0;
  bool _upcomingHasMore = false;
  bool _historyHasMore = false;
  bool _loadingMore = false;
  int _loadRun = 0; // newest reload; older pages are dropped

  /// Empty shows every history status.
  final Set<String> _historyStatuses = {};

  /// Day history narrows to; upcoming is exempt.
  DateTime? _selectedDay;

  /// Day under the pointer, previewed not filtered.
  DateTime? _previewDay;

  bool _filtersOpen = false;

  /// Set during layout; decides drawer versus sheet.
  bool _wideLayout = true;

  /// Booked while the first load ran.
  Appointment? _pendingBooked;

  /// How late a patient may cancel.
  Duration? _cancellationCutoff;

  @override
  void initState() {
    super.initState();
    widget.bookedSignal.addListener(_onExternalBooking);
    widget.refreshSignal?.addListener(_reloadAfterMutation);
    _useClinicRules();
    _load();
  }

  @override
  void didUpdateWidget(covariant AppointmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_reloadAfterMutation);
      widget.refreshSignal?.addListener(_reloadAfterMutation);
    }
  }

  // Clinic zone and cutoff; failure keeps device's.
  Future<void> _useClinicRules() async {
    try {
      final rules = await widget.treatmentApi.rules();
      if (!mounted) return;
      setState(() {
        ClinicTime.use(rules.timezone);
        _cancellationCutoff = Duration(
          minutes: rules.cancellationCutoffMinutes,
        );
      });
    } catch (_) {
      // The device zone already stands in.
    }
  }

  // Backend refuses inside the cutoff.
  bool _stillCancellable(Appointment appointment) {
    final cutoff = _cancellationCutoff;
    if (cutoff == null) return true;
    return appointment.scheduledAt.difference(DateTime.now()) >= cutoff;
  }

  @override
  void dispose() {
    widget.bookedSignal.removeListener(_onExternalBooking);
    widget.refreshSignal?.removeListener(_reloadAfterMutation);
    super.dispose();
  }

  // Quiet reloads keep what screen already shows.
  Future<void> _load({bool quiet = false}) async {
    final run = ++_loadRun;
    setState(() {
      if (!quiet) _loading = true;
      _loadingMore = false;
    });
    try {
      // Both lists at once, not sequentially.
      final results = await Future.wait([
        widget.appointmentApi.upcoming(),
        widget.appointmentApi.history(),
      ]);
      if (!mounted || run != _loadRun) return;
      setState(() {
        _upcoming = results[0].items.toList();
        _history = results[1].items.toList();
        _upcomingPage = 0;
        _historyPage = 0;
        _upcomingHasMore = !results[0].isLast;
        _historyHasMore = !results[1].isLast;
        _loading = false;
        _error = null;
        final pending = _pendingBooked;
        _pendingBooked = null;
        // Insert dedupes by id.
        if (pending != null) _insertUpcoming(pending);
      });
    } catch (_) {
      if (!mounted || run != _loadRun) return;
      // A quiet refresh must not blank list.
      if (quiet) return;
      setState(() {
        _loading = false;
        _error = 'Could not load appointments.';
      });
    }
  }

  // Next page, appended to whichever tab asked.
  Future<void> _loadMore({required bool upcoming}) async {
    if (_loadingMore) return;
    final run = _loadRun;
    setState(() => _loadingMore = true);
    final next = (upcoming ? _upcomingPage : _historyPage) + 1;
    try {
      final page = upcoming
          ? await widget.appointmentApi.upcoming(page: next)
          : await widget.appointmentApi.history(page: next);
      // A newer reload owns the lists.
      if (!mounted || run != _loadRun) return;
      setState(() {
        _loadingMore = false;
        if (upcoming) {
          _upcomingPage = next;
          _upcomingHasMore = !page.isLast;
          _append(_upcoming, page.items);
        } else {
          _historyPage = next;
          _historyHasMore = !page.isLast;
          _append(_history, page.items);
        }
      });
    } catch (_) {
      if (!mounted || run != _loadRun) return;
      setState(() => _loadingMore = false);
      _snack('Could not load more. Try again.');
    }
  }

  // Local edits shift offsets; ids can repeat.
  static void _append(List<Appointment>? list, List<Appointment> page) {
    if (list == null) return;
    final seen = list.map((a) => a.id).toSet();
    list.addAll(page.where((a) => seen.add(a.id)));
  }

  // A visit booked from the top button.
  void _onExternalBooking() {
    final appointment = widget.bookedSignal.value;
    if (appointment == null) return;
    // Consumed once; stale visits can't outlive it.
    widget.bookedSignal.value = null;
    if (_upcoming == null) {
      _pendingBooked = appointment;
      return;
    }
    setState(() => _insertUpcoming(appointment));
    _reloadAfterMutation();
  }

  // Offset pages need a fresh first page.
  void _reloadAfterMutation() {
    unawaited(_load(quiet: true));
  }

  // Keeps upcoming sorted, replacing what it supersedes.
  void _insertUpcoming(Appointment appointment) {
    final list = _upcoming;
    if (list == null) return;
    list.removeWhere(
      (a) =>
          a.id == appointment.id || a.id == appointment.replacesAppointmentId,
    );
    list.add(appointment);
    list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  Future<void> _cancel(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this visit?'),
        content: Text(
          'This cancels every remaining treatment on '
          '${BookingFormat.dayWithYear(appointment.scheduledAt)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel visit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final cancelled = await widget.appointmentApi.cancel(appointment.id);
      if (!mounted) return;
      // Move it into history locally, no refetch.
      setState(() {
        _upcoming?.removeWhere((a) => a.id == appointment.id);
        final history = _history;
        if (history != null) {
          history.removeWhere((a) => a.id == cancelled.id);
          history.insert(0, cancelled);
        }
      });
      _snack('Appointment cancelled.');
      _reloadAfterMutation();
    } on BookingConflictException catch (error) {
      if (mounted) _snack(error.message);
    } on ForbiddenException {
      if (mounted) _snack('That appointment is not yours to cancel.');
    } catch (_) {
      if (mounted) {
        _snack('Could not cancel. Check your connection and try again.');
      }
    }
  }

  // Drops one treatment; backend resyncs or closes.
  Future<void> _cancelSession(
    Appointment appointment,
    AppointmentSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this treatment?'),
        content: Text(
          'This drops ${session.treatmentLabel} from the visit on '
          '${BookingFormat.dayWithYear(appointment.scheduledAt)}. '
          'The rest of the visit stays booked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel treatment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.appointmentApi.cancelSession(appointment.id, session.id);
      if (!mounted) return;
      _snack('Treatment cancelled.');
      _reloadAfterMutation();
    } on BookingConflictException catch (error) {
      if (mounted) _snack(error.message);
    } on ForbiddenException {
      if (mounted) _snack('That treatment is not yours to cancel.');
    } catch (_) {
      if (mounted) {
        _snack('Could not cancel. Check your connection and try again.');
      }
    }
  }

  // Health form gate before the booking sheet.
  Future<bool> _verifyClinicalFormBeforeBooking() async {
    if (widget.clinicalApi == null) return true;

    try {
      final data = await widget.clinicalApi!.fetchOwn();
      final isComplete = ClinicalIntakeSchema.isComplete(data);

      if (!mounted) return false;

      if (!isComplete) {
        // Incomplete form must be filled first.
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_late_outlined,
                    color: AppColors.rose,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Clinical Form Required',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Please complete your clinical health & intake form before booking an appointment. '
              'Our medical team requires this information to ensure your treatment is safe and tailored to you.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSub,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.onNavigateToForms?.call();
                },
                child: const Text('Fill Clinical Form'),
              ),
            ],
          ),
        );
        return false;
      } else {
        // Complete form still offers a review.
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: AppColors.sage,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Clinical Form Verified',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Your clinical intake form has been completed and verified. Would you like to continue with booking, or review and update your health details first?',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSub,
                height: 1.4,
              ),
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop('modify');
                  widget.onNavigateToForms?.call();
                },
                child: const Text('Review / Modify Form'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop('proceed'),
                child: const Text('Continue to Booking'),
              ),
            ],
          ),
        );
        return action == 'proceed';
      }
    } catch (_) {
      // Network error must not block booking.
      return true;
    }
  }

  // Fresh visit; same sheet, nothing to replace.
  Future<void> _book() async {
    final canProceed = await _verifyClinicalFormBeforeBooking();
    if (!canProceed || !mounted) return;

    Appointment? booked;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => BookingFlowSheet(
        treatmentApi: widget.treatmentApi,
        appointmentApi: widget.appointmentApi,
        doctorApi: widget.doctorApi,
        onBooked: (a) => booked = a,
      ),
    );
    if (!mounted) return;
    if (result == true && booked != null) {
      setState(() => _insertUpcoming(booked!));
      _reloadAfterMutation();
    }
  }

  Future<void> _reschedule(Appointment appointment) async {
    final canProceed = await _verifyClinicalFormBeforeBooking();
    if (!canProceed || !mounted) return;

    Appointment? booked;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => BookingFlowSheet(
        treatmentApi: widget.treatmentApi,
        appointmentApi: widget.appointmentApi,
        doctorApi: widget.doctorApi,
        replacesAppointmentId: appointment.id,
        // Kept as-is unless the day changes.
        initialSessions: appointment.plannedSessions,
        onBooked: (a) => booked = a,
      ),
    );
    if (!mounted) return;
    if (result == true && booked != null) {
      // The old visit is superseded and hidden.
      setState(() => _insertUpcoming(booked!));
      _reloadAfterMutation();
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My appointments',
                  style: AppTypography.displayTitle(),
                ),
              ),
              _filtersButton(),
              const SizedBox(width: 10),
              // Booking button lives with its own list.
              ElevatedButton.icon(
                onPressed: _book,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'New appointment',
                  style: AppTypography.labelMedium(color: AppColors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  // Carries its count, so shut still informs.
  Widget _filtersButton() {
    final active = (_selectedDay == null ? 0 : 1) + _historyStatuses.length;
    return OutlinedButton.icon(
      onPressed: _wideLayout
          ? () => setState(() => _filtersOpen = !_filtersOpen)
          : _openFilterSheet,
      style: OutlinedButton.styleFrom(
        backgroundColor: active > 0 ? AppColors.rosePale : null,
        side: BorderSide(
          color: active > 0 ? AppColors.borderRose : AppColors.border,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: Icon(
        Icons.tune_rounded,
        size: 16,
        color: active > 0 ? AppColors.roseDark : AppColors.textMuted,
      ),
      label: Text(
        active > 0 ? 'Filters · $active' : 'Filters',
        style: AppTypography.labelMedium(
          color: active > 0 ? AppColors.roseDark : AppColors.textSub,
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return BookingMessage(
        icon: Icons.error_outline,
        text: _error!,
        onRetry: _load,
      );
    }
    final allUpcoming = _upcoming ?? const <Appointment>[];
    final allHistory = _history ?? const <Appointment>[];
    final day = _selectedDay;
    final dayLabel = day == null ? null : BookingFormat.calendarDay(day);

    // Filters touch history; next visit always shows.
    final upcoming = _section(
      'UPCOMING',
      allUpcoming.isEmpty ? null : '${allUpcoming.length}',
      _list(
        allUpcoming,
        'No upcoming appointments.',
        (appointment) => UpcomingCard(
          appointment: appointment,
          cancellable: _stillCancellable(appointment),
          onCancel: () => _cancel(appointment),
          onReschedule: () => _reschedule(appointment),
          onCancelSession: (session) => _cancelSession(appointment, session),
        ),
        hasMore: _upcomingHasMore,
        onLoadMore: () => _loadMore(upcoming: true),
      ),
    );

    final filteredHistory = _filterHistory(allHistory);
    final unfiltered = day == null && _historyStatuses.isEmpty;

    final history = _section(
      'HISTORY',
      unfiltered
          ? '${allHistory.length}'
          : '${filteredHistory.length} of ${allHistory.length}',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!unfiltered) ...[
            _summaryChips(dayLabel),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: _list(
              filteredHistory,
              _historyEmptyText(dayLabel),
              (appointment) => HistoryCard(appointment: appointment),
              // Load more would page past active filters.
              hasMore: unfiltered && _historyHasMore,
              onLoadMore: () => _loadMore(upcoming: false),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The drawer needs width it can borrow.
        final wide = constraints.maxWidth >= 900;
        _wideLayout = wide;
        if (!wide) {
          // Too narrow to push; sheet instead.
          return ListView(
            children: [
              SizedBox(height: 320, child: upcoming),
              const SizedBox(height: 24),
              SizedBox(height: 420, child: history),
            ],
          );
        }
        // Third column, so all rules line up.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Even width now the calendar left.
            Expanded(child: upcoming),
            const SizedBox(width: 28),
            Expanded(child: history),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: _filtersOpen ? 284 : 0,
              child: _filtersOpen
                  ? Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: _section('FILTERS', null, _drawer()),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  // Echo rebuilds the sheet, which owns itself.
  Widget _drawer({VoidCallback? echo, VoidCallback? onClose}) {
    final allUpcoming = _upcoming ?? const <Appointment>[];
    final allHistory = _history ?? const <Appointment>[];
    final preview = _previewDay ?? _selectedDay;
    void change(VoidCallback mutate) {
      setState(mutate);
      echo?.call();
    }

    return HistoryFilterDrawer(
      markedDates: {
        for (final a in allUpcoming) _dayOf(a.scheduledAt),
        for (final a in allHistory) _dayOf(a.scheduledAt),
      },
      selectedDay: _selectedDay,
      previewDay: preview,
      previewAppointments: _visitsOn(allHistory, preview),
      statuses: _historyStatusNames,
      selectedStatuses: _historyStatuses,
      statusCounts: _statusCounts(allHistory),
      shown: _filterHistory(allHistory).length,
      total: allHistory.length,
      onDaySelected: (picked) => change(() => _selectedDay = picked),
      onDayHovered: (hovered) => change(() => _previewDay = hovered),
      onStatusToggled: (status) => change(() {
        if (!_historyStatuses.remove(status)) _historyStatuses.add(status);
      }),
      onClose: onClose ?? () => setState(() => _filtersOpen = false),
    );
  }

  // Too narrow for a panel; sheet instead.
  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: _drawer(
            echo: () => setSheetState(() {}),
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    );
    // Pointer left with the sheet.
    if (mounted) setState(() => _previewDay = null);
  }

  // Filters stack, each narrowing the last.
  List<Appointment> _filterHistory(List<Appointment> items) {
    final day = _selectedDay;
    return items.where((a) {
      if (day != null && _dayOf(a.scheduledAt) != day) return false;
      if (_historyStatuses.isNotEmpty &&
          !_historyStatuses.contains(HistoryCard.historyStatus(a))) {
        return false;
      }
      return true;
    }).toList();
  }

  // Faceted: a status ignores its own selection.
  Map<String, int> _statusCounts(List<Appointment> items) {
    final day = _selectedDay;
    final pool = day == null
        ? items
        : items.where((a) => _dayOf(a.scheduledAt) == day);
    final counts = {for (final name in _historyStatusNames) name: 0};
    for (final appointment in pool) {
      final status = HistoryCard.historyStatus(appointment);
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  static List<Appointment> _visitsOn(List<Appointment> items, DateTime? day) {
    if (day == null) return const [];
    return items.where((a) => _dayOf(a.scheduledAt) == day).toList();
  }

  void _toggleStatus(String status) {
    setState(() {
      if (!_historyStatuses.remove(status)) _historyStatuses.add(status);
    });
  }

  // Clinic-local day, time stripped, for grid matching.
  static DateTime _dayOf(DateTime instant) {
    final local = ClinicTime.at(instant);
    return DateTime(local.year, local.month, local.day);
  }

  // Every outcome, not only the current ones.
  static const _historyStatusNames = [
    'Completed',
    'Pending',
    'Missed',
    'Cancelled',
  ];

  String _historyEmptyText(String? dayLabel) {
    final statuses = _historyStatuses.toList()..sort();
    final named = statuses.isEmpty ? 'past' : statuses.join(' or ');
    if (dayLabel == null) {
      return statuses.isEmpty
          ? 'No past appointments yet.'
          : 'No $named appointments.';
    }
    return 'No $named appointments on $dayLabel.';
  }

  // Each active filter, removable where it shows.
  Widget _summaryChips(String? dayLabel) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (dayLabel != null)
          _summaryChip(dayLabel, () => setState(() => _selectedDay = null)),
        for (final status in _historyStatuses.toList()..sort())
          _summaryChip(status, () => _toggleStatus(status)),
        GestureDetector(
          onTap: () => setState(() {
            _selectedDay = null;
            _historyStatuses.clear();
          }),
          child: Text(
            'Clear all',
            style: AppTypography.labelSmall(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, VoidCallback onRemove) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
        decoration: BoxDecoration(
          color: AppColors.rosePale,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderRose),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.labelSmall(color: AppColors.roseDark),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.close, size: 12, color: AppColors.rose),
          ],
        ),
      ),
    );
  }

  // Rule runs from label to column edge.
  Widget _section(String label, String? count, Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppTypography.labelSmall()),
            if (count != null) ...[
              const SizedBox(width: 8),
              Text(
                count,
                style: AppTypography.labelSmall(color: AppColors.textSub),
              ),
            ],
            const SizedBox(width: 12),
            Expanded(child: Container(height: 1, color: AppColors.hairline)),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(child: body),
      ],
    );
  }

  Widget _list(
    List<Appointment> items,
    String emptyText,
    Widget Function(Appointment) card, {
    required bool hasMore,
    required VoidCallback onLoadMore,
  }) {
    if (items.isEmpty) {
      return BookingMessage(
        icon: Icons.event_available_outlined,
        text: emptyText,
      );
    }
    return ListView.separated(
      // One extra row carries the load-more button.
      itemCount: items.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => index == items.length
          ? _loadMoreButton(onLoadMore)
          : card(items[index]),
    );
  }

  Widget _loadMoreButton(VoidCallback onLoadMore) {
    return Center(
      child: OutlinedButton(
        onPressed: _loadingMore ? null : onLoadMore,
        child: _loadingMore
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Load more'),
      ),
    );
  }
}
