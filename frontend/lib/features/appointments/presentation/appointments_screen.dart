import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_dialog.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../network/api_client.dart';
import '../../doctor_availability/presentation/widgets/availability_sessions_view.dart';
import '../data/appointment.dart';
import '../data/appointment_api.dart';
import '../data/booking_exceptions.dart';
import '../data/clinic_time.dart';
import '../data/doctor_api.dart';
import '../data/treatment_api.dart';
import '../../patient_profile/data/session_record.dart';
import '../../patient_profile/data/session_record_api.dart';
import '../../patient_profile/presentation/session_record_dialogs.dart';
import '../../products/data/product_api.dart';
import 'appointment_card.dart';
import 'booking_flow_sheet.dart';
import 'booking_format.dart';
import 'booking_result_steps.dart';
import 'history_filter_drawer.dart';
import 'session_description_row.dart';

/// List groups upcoming/history; Calendar shows every visit - any status -
/// on a day timeline, sharing the same status filters as the list.
enum _ViewMode { list, calendar }

/// The patient's own appointments: upcoming and history.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    super.key,
    required this.appointmentApi,
    required this.treatmentApi,
    required this.doctorApi,
    required this.bookedSignal,
    this.onNavigateToForms,
    this.focusedAppointmentId,
    this.refreshSignal,
    this.apiClient,
    this.patientId,
  });

  final AppointmentApi appointmentApi;
  final TreatmentApi treatmentApi;
  final DoctorApi doctorApi;

  /// Reads the treatment records; null hides them.
  final ApiClient? apiClient;

  /// Whose records to read, own id.
  final String? patientId;
  final VoidCallback? onNavigateToForms;
  final String? focusedAppointmentId;

  /// Fires when booked elsewhere; cleared once read.
  final ValueNotifier<Appointment?> bookedSignal;

  /// Chatbot wrote; reload without a skeleton.
  final Listenable? refreshSignal;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Appointment>? _upcoming;
  List<Appointment>? _history;
  bool _loading = true;
  String? _error;

  Map<String, SessionRecord> _recordsBySession = const {};
  // Older versions per session, newest first, current one excluded - lets
  // the notes dialog offer a "previous versions" list.
  Map<String, List<SessionRecord>> _recordHistoryBySession = const {};
  Map<String, String> _productNamesById = const {};

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

  _ViewMode _viewMode = _ViewMode.list;

  /// Which visit, and which of its own sessions, the calendar has selected -
  /// null until a session block is tapped. The session id highlights that
  /// one among its siblings on the same visit; the appointment id says
  /// which visit's full session breakdown to show.
  String? _selectedCalendarAppointmentId;
  String? _selectedCalendarSessionId;

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
  void didUpdateWidget(AppointmentsScreen oldWidget) {
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
        final focusedId = widget.focusedAppointmentId;
        if (focusedId != null) {
          _upcoming!.sort((a, b) {
            if (a.id == focusedId) return -1;
            if (b.id == focusedId) return 1;
            return a.scheduledAt.compareTo(b.scheduledAt);
          });
        }
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
      _loadTreatmentRecords();
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

  // Records arrive after the visits they annotate.
  Future<void> _loadTreatmentRecords() async {
    final apiClient = widget.apiClient;
    final patientId = widget.patientId;
    if (apiClient == null || patientId == null) return;
    try {
      final records = await SessionRecordApi(
        apiClient,
      ).listForPatient(patientId);
      if (!mounted) return;
      final history = SessionRecord.historyBySession(records);
      setState(() {
        _recordsBySession = {
          for (final entry in history.entries) entry.key: entry.value.first,
        };
        _recordHistoryBySession = {
          for (final entry in history.entries)
            entry.key: entry.value.skip(1).toList(),
        };
      });
      await _loadPrescribedNames(records);
    } catch (_) {
      // Visits still read without them.
    }
  }

  Future<void> _loadPrescribedNames(List<SessionRecord> records) async {
    final apiClient = widget.apiClient;
    final patientId = widget.patientId;
    if (apiClient == null || patientId == null) return;
    if (records.every((record) => record.prescribedProductIds.isEmpty)) return;
    try {
      final products = await ProductApi(
        apiClient,
      ).prescribedForPatient(patientId);
      if (!mounted) return;
      setState(() {
        _productNamesById = {
          for (final product in products)
            product.id: '${product.brandLabel} ${product.name}'.trim(),
        };
      });
    } catch (_) {
      // Ids stay hidden rather than raw.
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
      _showError('Could not load more. Try again.');
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
    final confirmed = await confirmDanger(
      context,
      title: 'Cancel this visit?',
      message:
          'This cancels every remaining treatment on '
          '${BookingFormat.dayWithYear(appointment.scheduledAt)}.',
      confirmLabel: 'Cancel visit',
      cancelLabel: 'Keep it',
    );
    if (!confirmed || !mounted) return;

    final restore = _snapshotLists();
    // Moves to history now; server confirms after.
    setState(() {
      _upcoming?.removeWhere((a) => a.id == appointment.id);
      final history = _history;
      if (history != null) {
        history.removeWhere((a) => a.id == appointment.id);
        history.insert(0, appointment.copyWith(status: 'CANCELLED'));
      }
    });

    try {
      final cancelled = await widget.appointmentApi.cancel(appointment.id);
      if (!mounted) return;
      setState(() {
        final history = _history;
        if (history != null) {
          final at = history.indexWhere((a) => a.id == cancelled.id);
          if (at >= 0) history[at] = cancelled;
        }
      });
      _snack('Appointment cancelled.');
      _reloadAfterMutation();
    } on BookingConflictException catch (error) {
      if (!mounted) return;
      _restoreLists(restore);
      _showError(error.message);
    } on ForbiddenException {
      if (!mounted) return;
      _restoreLists(restore);
      _showError('That appointment is not yours to cancel.');
    } catch (_) {
      if (!mounted) return;
      _restoreLists(restore);
      _showError('Could not cancel. Check your connection and try again.');
    }
  }

  ({List<Appointment>? upcoming, List<Appointment>? history})
  _snapshotLists() => (
    upcoming: _upcoming == null ? null : [..._upcoming!],
    history: _history == null ? null : [..._history!],
  );

  void _restoreLists(
    ({List<Appointment>? upcoming, List<Appointment>? history}) saved,
  ) {
    setState(() {
      _upcoming = saved.upcoming;
      _history = saved.history;
    });
  }

  // Drops one treatment; backend resyncs or closes.
  Future<void> _cancelSession(
    Appointment appointment,
    AppointmentSession session,
  ) async {
    final confirmed = await confirmDanger(
      context,
      title: 'Cancel this treatment?',
      message:
          'This drops ${session.treatmentLabel} from the visit on '
          '${BookingFormat.dayWithYear(appointment.scheduledAt)}. '
          'The rest of the visit stays booked.',
      confirmLabel: 'Cancel treatment',
      cancelLabel: 'Keep it',
    );
    if (!confirmed || !mounted) return;

    final restore = _snapshotLists();
    // Drops the row now; server confirms after.
    setState(() => _dropSession(appointment.id, session.id));

    try {
      await widget.appointmentApi.cancelSession(appointment.id, session.id);
      if (!mounted) return;
      _snack('Treatment cancelled.');
      _reloadAfterMutation();
    } on BookingConflictException catch (error) {
      if (!mounted) return;
      _restoreLists(restore);
      _showError(error.message);
    } on ForbiddenException {
      if (!mounted) return;
      _restoreLists(restore);
      _showError('That treatment is not yours to cancel.');
    } catch (_) {
      if (!mounted) return;
      _restoreLists(restore);
      _showError('Could not cancel. Check your connection and try again.');
    }
  }

  void _dropSession(String appointmentId, String sessionId) {
    final upcoming = _upcoming;
    if (upcoming == null) return;
    final at = upcoming.indexWhere((a) => a.id == appointmentId);
    if (at < 0) return;
    final visit = upcoming[at];
    upcoming[at] = visit.copyWith(
      sessions: [
        for (final current in visit.sessions)
          if (current.id == sessionId)
            current.withStatus('CANCELLED')
          else
            current,
      ],
    );
  }

  // Fresh visit; same sheet, nothing to replace.
  Future<void> _book() async {
    Appointment? booked;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => BookingFlowSheet(
        treatmentApi: widget.treatmentApi,
        appointmentApi: widget.appointmentApi,
        doctorApi: widget.doctorApi,
        onBooked: (a) => booked = a,
        onEditClinicalForm: () {
          Navigator.of(dialogCtx).pop();
          widget.onNavigateToForms?.call();
        },
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
      builder: (dialogCtx) => BookingFlowSheet(
        treatmentApi: widget.treatmentApi,
        appointmentApi: widget.appointmentApi,
        doctorApi: widget.doctorApi,
        replacesAppointmentId: appointment.id,
        // Kept as-is unless the day changes.
        initialSessions: appointment.plannedSessions,
        onBooked: (a) => booked = a,
        onEditClinicalForm: () {
          Navigator.of(dialogCtx).pop();
          widget.onNavigateToForms?.call();
        },
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

  void _showError(String message) {
    showErrorDialog(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
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
                  _buildViewModeToggle(),
                  const SizedBox(width: 10),
                  // The calendar carries its own status chips below it;
                  // the day-and-status drawer only makes sense in list mode.
                  if (_viewMode == _ViewMode.list) ...[
                    _filtersButton(),
                    const SizedBox(width: 10),
                  ],
                  // Booking button lives with its own list.
                  ElevatedButton.icon(
                    onPressed: _book,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
        ),
      ],
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

  // List/Calendar toggle, mirroring the doctor's merged Appointments screen.
  Widget _buildViewModeToggle() {
    Widget modeChip(_ViewMode mode, IconData icon, String label) {
      final selected = _viewMode == mode;
      return ChoiceChip(
        avatar: Icon(
          icon,
          size: 16,
          color: selected ? Colors.white : AppColors.textSub,
        ),
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _viewMode = mode),
        showCheckmark: false,
        selectedColor: AppColors.rose,
        backgroundColor: AppColors.bgCard,
        side: BorderSide(color: selected ? AppColors.rose : AppColors.border),
        labelStyle: AppTypography.labelMedium(
          color: selected ? Colors.white : AppColors.textSub,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        modeChip(_ViewMode.list, Icons.view_list_outlined, 'List'),
        modeChip(
          _ViewMode.calendar,
          Icons.calendar_view_day_outlined,
          'Calendar',
        ),
      ],
    );
  }

  Widget _content() {
    if (_loading) {
      return const SkeletonList();
    }
    if (_error != null) {
      return BookingMessage(
        icon: Icons.error_outline,
        text: _error!,
        onRetry: _load,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Both widths decide drawer-vs-sheet and column-vs-stack; shared so
        // toggling view mode doesn't flip either mid-session.
        final wide = constraints.maxWidth >= 900;
        _wideLayout = wide;
        return _viewMode == _ViewMode.list
            ? _buildListBody(wide)
            : _buildCalendarBody(wide);
      },
    );
  }

  // Every loaded appointment (whatever pages of upcoming/history are in
  // memory), deduped by id - the unfiltered source both the calendar's own
  // filtering below and the detail panel's lookup build from. The panel
  // deliberately reads from this, not from _calendarSourceAppointments:
  // once a visit is selected its own breakdown should show every session
  // on it, not just whichever ones the active filter happens to match.
  Map<String, Appointment> get _allCalendarAppointments => {
    for (final a in _upcoming ?? const <Appointment>[]) a.id: a,
    for (final a in _history ?? const <Appointment>[]) a.id: a,
  };

  // Every appointment regardless of status - cancelled and missed included -
  // on one day timeline, narrowed to just the sessions matching the active
  // status filter rather than including or excluding the whole visit - the
  // same session-level filtering the calendar uses for staff, using the
  // same four-word vocabulary the history list's filter already does. A
  // visit with both a completed and a still-planned session, filtered to
  // "Completed," shows just that one session.
  List<Appointment> get _calendarSourceAppointments {
    final all = _allCalendarAppointments.values;
    if (_historyStatuses.isEmpty) return all.toList();
    bool matches(AppointmentSession session) =>
        _historyStatuses.contains(sessionStatusInfo(session.status).label);
    return [
      for (final appointment in all)
        if (appointment.sessions.any(matches))
          appointment.copyWith(
            sessions: appointment.sessions.where(matches).toList(),
          ),
    ];
  }

  Widget _buildCalendarBody(bool wide) {
    final calendar = AvailabilitySessionsView(
      // Unreachable: preloadedAppointments is always set below.
      fetchSessions: (_) async => const [],
      preloadedAppointments: _calendarSourceAppointments,
      primaryLabel: (appointment, session) => session.practitionerName,
      // A cancelled visit is still a real event on the patient's
      // calendar, not something to erase.
      showCancelledSessions: true,
      // Connects to the real backend record for a completed session - its
      // doctor's notes, or confirmation none were added yet - for the
      // inline block affordance. appointmentApi is deliberately omitted:
      // patients can view a record, not author one.
      apiClient: widget.apiClient,
      // Selecting any session (not just completed ones) opens the panel
      // below/beside the calendar showing every session on that visit.
      onSessionSelected: (appointmentId, sessionId) =>
          _selectCalendarVisit(appointmentId, sessionId, wide),
    );

    final selected = _selectedCalendarAppointment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _calendarStatusFilters(),
        const SizedBox(height: 14),
        Expanded(
          child: !wide
              ? calendar
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: calendar),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: selected == null
                          ? _buildNoCalendarSelection()
                          : _buildCalendarSessionsPanel(selected),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // Unlike _selectedAppointment (list mode), this never falls back to "the
  // first appointment" - see the equivalent comment on
  // ClinicAppointmentsScreen for why that fallback wouldn't make sense here.
  // Reads _allCalendarAppointments (unfiltered), not _calendarSourceAppointments -
  // see the comment on the former for why.
  Appointment? get _selectedCalendarAppointment {
    final id = _selectedCalendarAppointmentId;
    if (id == null) return null;
    return _allCalendarAppointments[id];
  }

  void _selectCalendarVisit(String appointmentId, String sessionId, bool wide) {
    setState(() {
      _selectedCalendarAppointmentId = appointmentId;
      _selectedCalendarSessionId = sessionId;
    });
    if (wide) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            controller: controller,
            child: _buildCalendarSessionsPanelBody(_selectedCalendarAppointment),
          ),
        ),
      ),
    );
  }

  Widget _buildNoCalendarSelection() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Select a session to see its details.',
        style: AppTypography.bodySmall(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildCalendarSessionsPanel(Appointment visit) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: _buildCalendarSessionsPanelBody(visit),
      ),
    );
  }

  Widget _buildCalendarSessionsPanelBody(Appointment? visit) {
    if (visit == null) {
      return Text(
        'This visit is no longer available.',
        style: AppTypography.bodySmall(color: AppColors.textMuted),
      );
    }
    final sessions = [...visit.sessions]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    // Same rule UpcomingCard uses in the list, so "cancellable" means the
    // same thing in both views.
    final cancellable = visit.isBooked && _stillCancellable(visit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          BookingFormat.dayWithYear(visit.scheduledAt),
          style: AppTypography.displaySubtitle().copyWith(fontSize: 19),
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: 12),
        Text('SESSIONS', style: AppTypography.labelSmall()),
        const SizedBox(height: 8),
        if (sessions.isEmpty)
          Text(
            'This visit has no treatments on it.',
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          )
        else
          for (final session in sessions)
            SessionDescriptionRow(
              session: session,
              selected: session.id == _selectedCalendarSessionId,
              trailing: _calendarSessionAction(
                visit,
                session,
                cancellable: cancellable,
                sessionCount: sessions.length,
              ),
            ),
        // The same cancel/reschedule the list's UpcomingCard offers, so a
        // booked visit isn't only manageable from one of the two views.
        if (visit.isBooked) ...[
          const SizedBox(height: 16),
          if (!cancellable)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Too close to the appointment to change it. Call the clinic.',
                style: AppTypography.bodySmall(),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: OutlinedButton(
                  onPressed: cancellable ? () => _cancel(visit) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FilledButton(
                  onPressed: cancellable ? () => _reschedule(visit) : null,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
                  child: const Text(
                    'Reschedule',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // A completed session shows its record; an otherwise-still-planned one on
  // a cancellable, multi-session visit can be dropped on its own (dropping
  // the only session would just be cancelling the whole visit, which the
  // buttons below already do). Anything else - cancelled, missed, or a
  // visit no longer cancellable - offers nothing here.
  Widget? _calendarSessionAction(
    Appointment visit,
    AppointmentSession session, {
    required bool cancellable,
    required int sessionCount,
  }) {
    if (session.status == 'COMPLETED') {
      final record = _recordsBySession[session.id];
      return TextButton.icon(
        onPressed: () {
          if (record == null) {
            showNoSessionRecordDialog(context);
          } else {
            showSessionRecordViewDialog(
              context: context,
              record: record,
              previousVersions: _recordHistoryBySession[session.id] ?? const [],
            );
          }
        },
        icon: Icon(
          record != null ? Icons.visibility_outlined : Icons.info_outline,
          size: 16,
        ),
        label: Text(record != null ? 'View record' : 'No record yet'),
      );
    }
    if (cancellable && session.isPlanned && sessionCount > 1) {
      return TextButton.icon(
        onPressed: () => _cancelSession(visit, session),
        icon: const Icon(Icons.close, size: 16),
        label: const Text('Cancel'),
        style: TextButton.styleFrom(foregroundColor: AppColors.textSub),
      );
    }
    return null;
  }

  // Same four statuses and same selection set as the history list's filter
  // drawer, just as inline chips since the calendar has its own day nav
  // (no need for the drawer's mini-calendar day picker here).
  Widget _calendarStatusFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in _historyStatusNames)
          FilterChip(
            label: Text(status),
            selected: _historyStatuses.contains(status),
            onSelected: (_) => _toggleStatus(status),
            showCheckmark: false,
            selectedColor: AppColors.rosePale,
            backgroundColor: AppColors.bgCard,
            side: BorderSide(
              color: _historyStatuses.contains(status)
                  ? AppColors.borderRose
                  : AppColors.border,
            ),
            labelStyle: AppTypography.labelMedium(
              color: _historyStatuses.contains(status)
                  ? AppColors.roseDark
                  : AppColors.textSub,
            ),
          ),
        if (_historyStatuses.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _historyStatuses.clear()),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Clear',
                style: AppTypography.labelSmall(color: AppColors.textMuted),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListBody(bool wide) {
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
              (appointment) => HistoryCard(
                appointment: appointment,
                recordsBySession: _recordsBySession,
                recordHistoryBySession: _recordHistoryBySession,
                productNamesById: _productNamesById,
              ),
              // Load more would page past active filters.
              hasMore: unfiltered && _historyHasMore,
              onLoadMore: () => _loadMore(upcoming: false),
            ),
          ),
        ],
      ),
    );

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
    'Planned',
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
