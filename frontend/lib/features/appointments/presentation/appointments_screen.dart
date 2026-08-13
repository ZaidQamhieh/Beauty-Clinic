import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../network/api_client.dart';
import '../data/appointment.dart';
import '../data/appointment_api.dart';
import '../data/booking_exceptions.dart';
import '../data/clinic_time.dart';
import '../data/doctor_api.dart';
import '../data/treatment_api.dart';
import 'booking_flow_sheet.dart';
import 'booking_format.dart';
import 'booking_result_steps.dart';

/// The patient's own appointments: upcoming and history.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    super.key,
    required this.appointmentApi,
    required this.treatmentApi,
    required this.doctorApi,
    required this.bookedSignal,
  });

  final AppointmentApi appointmentApi;
  final TreatmentApi treatmentApi;
  final DoctorApi doctorApi;

  /// Fires when a visit is booked elsewhere; cleared once read.
  final ValueNotifier<Appointment?> bookedSignal;

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

  /// Booked while the first load was in flight.
  Appointment? _pendingBooked;

  /// How late a patient may still cancel, once the rules land.
  Duration? _cancellationCutoff;

  @override
  void initState() {
    super.initState();
    widget.bookedSignal.addListener(_onExternalBooking);
    _useClinicRules();
    _load();
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

  // The backend refuses inside the cutoff, so do not offer it.
  bool _stillCancellable(Appointment appointment) {
    final cutoff = _cancellationCutoff;
    if (cutoff == null) return true;
    return appointment.scheduledAt.difference(DateTime.now()) >= cutoff;
  }

  @override
  void dispose() {
    widget.bookedSignal.removeListener(_onExternalBooking);
    super.dispose();
  }

  // Quiet reloads keep what the screen already shows.
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
      // A quiet refresh must not blank the list.
      if (quiet) return;
      setState(() {
        _loading = false;
        _error = 'Could not load appointments.';
      });
    }
  }

  // The next page, appended to whichever tab asked.
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
    // Consumed once, so a stale visit cannot outlive this screen.
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

  // A fresh visit. Same sheet as a reschedule, with nothing to replace.
  Future<void> _book() async {
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
    Appointment? booked;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => BookingFlowSheet(
        treatmentApi: widget.treatmentApi,
        appointmentApi: widget.appointmentApi,
        doctorApi: widget.doctorApi,
        replacesAppointmentId: appointment.id,
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
              // Booking lives with the list it adds to, not in the global header.
              ElevatedButton.icon(
                onPressed: _book,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'New appointment',
                  style: AppTypography.labelSmall(color: AppColors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _content()),
        ],
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
    final upcoming = _column(
      'UPCOMING',
      _list(
        _upcoming ?? const [],
        'No upcoming appointments.',
        (appointment) => _UpcomingCard(
          appointment: appointment,
          cancellable: _stillCancellable(appointment),
          onCancel: () => _cancel(appointment),
          onReschedule: () => _reschedule(appointment),
        ),
        hasMore: _upcomingHasMore,
        onLoadMore: () => _loadMore(upcoming: true),
      ),
    );

    final history = _column(
      'HISTORY',
      _list(
        _history ?? const [],
        'No past appointments yet.',
        (appointment) => _HistoryCard(appointment: appointment),
        hasMore: _historyHasMore,
        onLoadMore: () => _loadMore(upcoming: false),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side where there is room; stacked when the pair would be
        // too narrow to read, which is the tabs' job done by the layout.
        if (constraints.maxWidth < 900) {
          return ListView(
            children: [
              SizedBox(height: 320, child: upcoming),
              const SizedBox(height: 24),
              SizedBox(height: 320, child: history),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: upcoming),
            const SizedBox(width: 32),
            Expanded(flex: 2, child: history),
          ],
        );
      },
    );
  }

  Widget _column(String title, Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.labelSmall()),
        const SizedBox(height: 4),
        const Divider(),
        const SizedBox(height: 8),
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

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.appointment,
    required this.cancellable,
    required this.onCancel,
    required this.onReschedule,
  });

  final Appointment appointment;

  /// False once the cancellation cutoff has passed.
  final bool cancellable;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    return _AppointmentCard(
      appointment: appointment,
      // Still to come, or all if none planned.
      sessions: appointment.plannedSessions.isNotEmpty
          ? appointment.plannedSessions
          : appointment.sessions,
      statusLabel: 'Confirmed',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!cancellable) ...[
            Text(
              'Too close to the appointment to change it. Call the clinic.',
              style: AppTypography.bodySmall(),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: cancellable ? onReschedule : null,
                  child: const Text('Reschedule'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: cancellable ? onCancel : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return _AppointmentCard(
      appointment: appointment,
      // What was delivered, not only what is planned.
      sessions: [...appointment.sessions]
        ..sort((a, b) => a.startTime.compareTo(b.startTime)),
      statusLabel: _historyStatus(appointment),
    );
  }

  // What became of the visit, per its treatments.
  static String _historyStatus(Appointment appointment) {
    if (!appointment.isBooked) return 'Cancelled';
    final sessions = appointment.sessions;
    if (sessions.any((s) => s.status == 'COMPLETED')) return 'Completed';
    if (sessions.isEmpty) return 'Pending';
    if (sessions.every((s) => s.status == 'CANCELLED')) return 'Cancelled';
    // Nothing delivered and nothing left planned.
    if (sessions.every((s) => !s.isPlanned)) return 'Missed';
    // Past, but no outcome was recorded.
    return 'Pending';
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.sessions,
    required this.statusLabel,
    this.footer,
  });

  final Appointment appointment;

  /// Which treatments to list; the caller decides.
  final List<AppointmentSession> sessions;
  final String statusLabel;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Flexible(
                child: Text(
                  '${BookingFormat.day(appointment.scheduledAt)} · '
                  '${BookingFormat.time12(appointment.scheduledAt)}',
                  style: AppTypography.labelLarge(),
                ),
              ),
              StatusPill(status: statusLabel),
            ],
          ),
          const SizedBox(height: 8),
          for (final session in sessions)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${session.treatmentLabel} · ${BookingFormat.time12(session.startTime)} · '
                '${session.practitionerName}',
                style: AppTypography.bodySmall(),
              ),
            ),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}
