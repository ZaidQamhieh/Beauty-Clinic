import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_dialog.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../network/api_client.dart';
import '../data/appointment.dart';
import '../data/appointment_api.dart';
import '../data/doctor_api.dart';
import '../data/doctor_summary.dart';
import '../data/treatment_api.dart';
import '../../doctor_availability/data/doctor_availability_api.dart';
import '../../doctor_availability/presentation/widgets/availability_sessions_view.dart';
import '../../patient_profile/data/session_record_api.dart';
import '../../patient_profile/data/session_record.dart';
import '../../patient_profile/presentation/session_record_dialogs.dart';
import '../../patients/presentation/patient_picker.dart';
import 'booking_flow_sheet.dart';
import 'session_description_row.dart';

enum _ViewMode { list, calendar }

/// Clinic-wide appointment workspace for staff.
class ClinicAppointmentsScreen extends StatefulWidget {
  const ClinicAppointmentsScreen({
    super.key,
    required this.appointmentApi,
    required this.treatmentApi,
    required this.doctorApi,
    required this.apiClient,
    this.canAuthorSessionRecords = false,
    this.canViewSessionRecords = false,
    this.doctorUserId,
    this.onViewPatient,
    this.showCalendarTab = false,
    this.availabilityApi,
  });

  final AppointmentApi appointmentApi;
  final TreatmentApi treatmentApi;
  final DoctorApi doctorApi;
  final ApiClient apiClient;
  final bool canAuthorSessionRecords;

  /// Lets a session row's record be opened read-only (no edit, no mark
  /// attended) for a completed session, even without
  /// [canAuthorSessionRecords]. Implied by [canAuthorSessionRecords]
  /// itself, so this only matters when that's false.
  final bool canViewSessionRecords;
  final String? doctorUserId;
  final ValueChanged<String>? onViewPatient;

  /// Offers a Calendar mode (a day-timeline, shaded against
  /// [availabilityApi]'s schedule) alongside the default list. A doctor's
  /// own view is implicitly restricted to themselves via [doctorUserId].
  /// Admin/receptionist have no default practitioner: the same doctor
  /// filter the list already offers narrows their calendar to one doctor's
  /// day too, but left on "any doctor" it shows every doctor's sessions on
  /// one shared timeline instead, each block labeled with whose it is.
  final bool showCalendarTab;

  /// Required when [showCalendarTab] is true.
  final DoctorAvailabilityApi? availabilityApi;

  @override
  State<ClinicAppointmentsScreen> createState() =>
      _ClinicAppointmentsScreenState();
}

class _ClinicAppointmentsScreenState extends State<ClinicAppointmentsScreen> {
  static const double _wideBreakpoint = 900;

  // Appointment-level (list): ALL/BOOKED/CANCELLED, matching Appointment.status.
  String _statusFilter = 'ALL';
  // Session-level (calendar): ALL/PLANNED/COMPLETED/CANCELLED/NO_SHOW,
  // matching AppointmentSession.status - a separate filter because the two
  // views filter by two different entities' status, not the same field.
  String _calendarStatusFilter = 'ALL';
  DateTime? _dateFilter;
  String? _doctorFilter;
  String _query = '';
  String? _selectedId;
  // Which specific session within the selected visit was actually tapped -
  // only ever set from a calendar tap (a list row selects the whole visit,
  // no one session in particular) - so its row can be told apart from its
  // siblings on the same visit rather than blending in with them.
  String? _selectedSessionId;
  _ViewMode _viewMode = _ViewMode.list;
  List<Appointment> _appointments = const [];
  List<DoctorSummary> _doctors = const [];
  List<DoctorAvailability> _availability = const [];
  bool _loading = true;
  String? _error;
  Map<String, SessionRecord> _recordsBySession = {};
  // Older versions per session, newest first, current one excluded - lets
  // the record dialog offer a "previous versions" list.
  Map<String, List<SessionRecord>> _recordHistoryBySession = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadDoctors());
    // Only a doctor's own calendar preloads hours this way; admin/
    // receptionist fetch whichever doctor they pick live instead (see
    // _buildCalendarBody), since there's no "me" to preload for them.
    if (widget.showCalendarTab && widget.doctorUserId != null) {
      unawaited(_loadAvailability());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _fetchAllAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = items;
        _loading = false;
      });
      await _loadSessionRecords(items);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load clinic appointments.';
      });
    }
  }

  // Refetch behind the screen, no skeleton.
  Future<void> _refreshQuietly() async {
    try {
      final items = await _fetchAllAppointments();
      if (!mounted) return;
      setState(() => _appointments = items);
      await _loadSessionRecords(items);
    } catch (_) {
      // What is on screen already stands.
    }
  }

  // Every page, not just the first - both the list and the calendar (when
  // showCalendarTab) render off this same in-memory set, so neither can
  // afford to silently miss whatever falls past a single page.
  Future<List<Appointment>> _fetchAllAppointments() async {
    final all = <Appointment>[];
    var page = 0;
    while (true) {
      final result = await widget.appointmentApi.allForStaff(page: page);
      all.addAll(result.items);
      if (result.isLast) break;
      page++;
    }
    return all;
  }

  Future<void> _loadAvailability() async {
    try {
      final availability = await widget.availabilityApi!.list();
      if (!mounted) return;
      setState(() => _availability = availability);
    } catch (_) {
      // The calendar mode still renders; it just shows no availability
      // shading, same as AvailabilitySessionsView does when
      // fetchAvailability is omitted entirely.
    }
  }

  void _replaceAppointment(Appointment next) {
    _appointments = [
      for (final current in _appointments)
        current.id == next.id ? next : current,
    ];
  }

  Future<void> _loadDoctors() async {
    try {
      final doctors = await widget.doctorApi.list();
      if (!mounted) return;
      setState(() => _doctors = doctors);
    } catch (_) {}
  }

  Future<void> _loadSessionRecords(List<Appointment> appointments) async {
    // One fetch per distinct patient, not per appointment - a patient with
    // several visits would otherwise have their whole record history
    // fetched (and counted) once per visit, multiplying every "previous
    // versions" count by however many appointments they happen to have.
    final patientIds = appointments.map((a) => a.patientUserId).toSet();
    final recordLists = await Future.wait(
      patientIds.map((patientId) async {
        try {
          return await SessionRecordApi(
            widget.apiClient,
          ).listForPatient(patientId);
        } catch (_) {
          return const <SessionRecord>[];
        }
      }),
    );
    if (!mounted) return;
    final history = SessionRecord.historyBySession(
      recordLists.expand((items) => items),
    );
    setState(() {
      _recordsBySession = {
        for (final entry in history.entries) entry.key: entry.value.first,
      };
      _recordHistoryBySession = {
        for (final entry in history.entries)
          entry.key: entry.value.skip(1).toList(),
      };
    });
  }

  // Patches one session's record locally instead of re-fetching every
  // patient's whole history just to display what this call itself already
  // returned - instant on screen instead of waiting on a full reload.
  void _applySavedRecord(SessionRecord record) {
    setState(() {
      final previous = _recordsBySession[record.sessionId];
      if (previous != null) {
        _recordHistoryBySession = {
          ..._recordHistoryBySession,
          record.sessionId: [
            previous,
            ...?_recordHistoryBySession[record.sessionId],
          ],
        };
      }
      _recordsBySession = {..._recordsBySession, record.sessionId: record};
    });
  }

  Future<void> _openBooking({Appointment? appointment}) async {
    if (appointment != null && !_canModify(appointment)) return;
    String? patientUserId;
    if (appointment == null) {
      patientUserId = await showPatientPicker(context, widget.apiClient);
      if (patientUserId == null || !mounted) return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => BookingFlowSheet(
        treatmentApi: widget.treatmentApi,
        appointmentApi: widget.appointmentApi,
        doctorApi: widget.doctorApi,
        patientUserId: patientUserId ?? appointment?.patientUserId,
        replacesAppointmentId: appointment?.id,
        initialSessions: appointment?.sessions ?? const [],
        onBooked: (_) => _load(),
      ),
    );
  }

  // Same patient, fresh booking; nothing is replaced.
  Future<void> _bookFollowUp(Appointment appointment) async {
    await showDialog<void>(
      context: context,
      builder: (context) => BookingFlowSheet(
        treatmentApi: widget.treatmentApi,
        appointmentApi: widget.appointmentApi,
        doctorApi: widget.doctorApi,
        patientUserId: appointment.patientUserId,
        onBooked: (_) => _load(),
      ),
    );
  }

  Future<void> _cancel(Appointment appointment) async {
    if (!_canModify(appointment)) return;
    final confirmed = await confirmDanger(
      context,
      title: 'Cancel appointment?',
      message:
          'Cancel ${appointment.patientName}\'s appointment on '
          '${DateFormat('d MMM yyyy · HH:mm').format(appointment.scheduledAt.toLocal())}?',
      confirmLabel: 'Cancel appointment',
      cancelLabel: 'Keep',
    );
    if (!confirmed || !mounted) return;

    final previous = _appointments;
    // Reads cancelled now; reverts if refused.
    setState(
      () => _replaceAppointment(appointment.copyWith(status: 'CANCELLED')),
    );

    try {
      await widget.appointmentApi.cancel(appointment.id);
      if (!mounted) return;
      await _refreshQuietly();
    } catch (_) {
      if (!mounted) return;
      setState(() => _appointments = previous);
      showErrorDialog(context, 'Could not cancel the appointment.');
    }
  }

  Future<void> _completeSession(
    Appointment appointment,
    AppointmentSession session,
  ) async {
    final saved = await completeSessionWithRecord(
      context: context,
      apiClient: widget.apiClient,
      appointmentApi: widget.appointmentApi,
      appointmentId: appointment.id,
      patientUserId: appointment.patientUserId,
      session: session,
    );
    if (saved == null) return;
    // The session itself moved from PLANNED to COMPLETED - that has to be
    // reflected locally too, not just the record. Everything else about the
    // appointment is unchanged, so a full clinic-wide refetch to learn that
    // would just be a slow way to redraw what we already know.
    setState(() {
      _replaceAppointment(
        appointment.copyWith(
          sessions: [
            for (final s in appointment.sessions)
              if (s.id == session.id) s.withStatus('COMPLETED') else s,
          ],
        ),
      );
    });
    _applySavedRecord(saved);
  }

  void _viewSessionRecord(SessionRecord record) {
    showSessionRecordViewDialog(
      context: context,
      record: record,
      canEdit: widget.canAuthorSessionRecords,
      onEdit: () => _editSessionRecord(record),
      previousVersions: _recordHistoryBySession[record.sessionId] ?? const [],
    );
  }

  Future<void> _editSessionRecord(SessionRecord record) async {
    final session = _appointments
        .expand((appointment) => appointment.sessions)
        .firstWhere((session) => session.id == record.sessionId);
    final patientUserId = _appointments
        .firstWhere(
          (appointment) => appointment.sessions.any(
            (session) => session.id == record.sessionId,
          ),
        )
        .patientUserId;
    final saved = await editSessionRecord(
      context: context,
      apiClient: widget.apiClient,
      record: record,
      session: session,
      patientUserId: patientUserId,
    );
    // Nothing about the appointment itself changed - just the note - so
    // patch it in directly instead of a full reload.
    if (saved != null) _applySavedRecord(saved);
  }

  bool _canModify(Appointment appointment) {
    return appointment.status == 'BOOKED' &&
        appointment.scheduledAt.isAfter(DateTime.now());
  }

  List<Appointment> get _visibleAppointments {
    final sorted = _appointments.where((appointment) {
      final scheduled = appointment.scheduledAt.toLocal();
      final matchesStatus = _matchesStatus(appointment);
      final matchesDate =
          _dateFilter == null ||
          (scheduled.year == _dateFilter!.year &&
              scheduled.month == _dateFilter!.month &&
              scheduled.day == _dateFilter!.day);
      final matchesDoctor =
          _doctorFilter == null ||
          appointment.sessions.any(
            (session) => session.practitionerUserId == _doctorFilter,
          );
      return matchesStatus &&
          matchesDate &&
          matchesDoctor &&
          _matchesQuery(appointment);
    }).toList();
    // Most recent/soonest-in-the-future first.
    sorted.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return sorted;
  }

  bool _matchesQuery(Appointment appointment) {
    if (_query.isEmpty) return true;
    final haystack = [
      appointment.patientName,
      for (final session in appointment.sessions) ...[
        session.treatmentLabel,
        session.practitionerName,
      ],
    ].join(' ').toLowerCase();
    return haystack.contains(_query);
  }

  // The entity's own visit-level truth: every appointment is either BOOKED
  // or CANCELLED, full stop - nothing derived, matching the same field
  // _matchesStatus and _statusPill read for the list. Counts every
  // appointment, not the filtered list, so a count up top always means
  // "the clinic's totals," not "whatever the status chips happen to show."
  ({int booked, int cancelled}) get _appointmentCounts {
    var booked = 0;
    var cancelled = 0;
    for (final appointment in _appointments) {
      if (appointment.status == 'CANCELLED') {
        cancelled++;
      } else {
        booked++;
      }
    }
    return (booked: booked, cancelled: cancelled);
  }

  // The other level: not the visit, but what's actually happening session
  // by session - the same four states the calendar colors sessions by.
  // Scoped through _visibleSessions like the detail panel is, so a
  // doctor's own count is their own sessions, not every session on every
  // visit they happen to share with someone else.
  ({int planned, int completed, int cancelled, int noShow}) get _sessionCounts {
    var planned = 0;
    var completed = 0;
    var cancelled = 0;
    var noShow = 0;
    for (final appointment in _appointments) {
      for (final session in _visibleSessions(appointment)) {
        switch (session.status) {
          case 'COMPLETED':
            completed++;
          case 'CANCELLED':
            cancelled++;
          case 'NO_SHOW':
            noShow++;
          default:
            planned++;
        }
      }
    }
    return (
      planned: planned,
      completed: completed,
      cancelled: cancelled,
      noShow: noShow,
    );
  }

  Appointment? _selectedAppointment(List<Appointment> appointments) {
    if (appointments.isEmpty) return null;
    return appointments.firstWhere(
      (appointment) => appointment.id == _selectedId,
      orElse: () => appointments.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _visibleAppointments;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(),
              const SizedBox(height: 16),
              _buildToolbar(),
              const SizedBox(height: 16),
              Expanded(
                // Both bodies stay mounted so AvailabilitySessionsView's own
                // selected-day state survives toggling back and forth.
                child: IndexedStack(
                  index: _viewMode == _ViewMode.list ? 0 : 1,
                  sizing: StackFit.expand,
                  children: [
                    _buildWorkspace(appointments, wide),
                    // Only ever selected when showCalendarTab is true (that's
                    // the only way _viewMode can become .calendar), but kept
                    // as a real second child either way so the index above is
                    // always valid.
                    if (widget.showCalendarTab)
                      _buildCalendarBody(wide)
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Never the search query or (moot for a doctor's own view anyway) the
  // doctor filter - the calendar is always one specific day for one
  // specific practitioner, which day-matching and restrictToPractitionerId
  // below handle on their own. Status is its own, separate filter here too
  // (_calendarStatusFilter, not _statusFilter): the calendar shows
  // sessions, not visits, so it filters by session status - narrowing
  // each visit down to just the sessions that match rather than including
  // or excluding the visit as a whole, so a visit with both a completed
  // and a still-planned session can show just the one that matches.
  List<Appointment> get _calendarSourceAppointments {
    if (_calendarStatusFilter == 'ALL') return _appointments;
    return [
      for (final appointment in _appointments)
        if (appointment.sessions.any(
          (session) => session.status == _calendarStatusFilter,
        ))
          appointment.copyWith(
            sessions: appointment.sessions
                .where((session) => session.status == _calendarStatusFilter)
                .toList(),
          ),
    ];
  }

  // The one doctor this view is scoped to, if any - a doctor's own view is
  // always themselves; admin/receptionist have no default practitioner, so
  // it comes from the same doctor filter the list already offers. Null
  // means "every doctor" (never for a doctor's own view, which always has
  // doctorUserId). Drives both the calendar's restrictToPractitionerId and
  // which sessions of a visit are shown/actionable in the detail panel -
  // a visit spanning several doctors should only ever show this one's
  // sessions once a doctor scope is active, not every session on it.
  String? get _effectiveDoctorId => widget.doctorUserId ?? _doctorFilter;

  Widget _buildCalendarBody(bool wide) {
    final practitionerId = _effectiveDoctorId;

    final calendar = AvailabilitySessionsView(
      // Unreachable: preloadedAppointments is always set below.
      fetchSessions: (_) async => const [],
      preloadedAppointments: _calendarSourceAppointments,
      restrictToPractitionerId: practitionerId,
      // A single doctor's hours can be shaded (the doctor's own, preloaded
      // once clinic-wide, or an arbitrary one staff picked, fetched live);
      // "every doctor" has no one schedule to shade against, so it shows
      // sessions on a plain background instead, same as the patient's
      // own calendar does.
      preloadedAvailability: widget.doctorUserId != null ? _availability : null,
      fetchAvailability: widget.doctorUserId != null || practitionerId == null
          ? null
          : () => widget.availabilityApi!.listForDoctor(practitionerId),
      // No key on this widget on purpose: staff switching doctors should
      // refresh whose hours are shaded, not lose which day they had picked
      // (that's exactly what fetchAvailabilityKey is for - it re-fetches
      // without remounting, unlike keying on practitionerId would).
      fetchAvailabilityKey: practitionerId,
      // Staff seeing every doctor at once need to know whose session is
      // whose - a doctor's own calendar, or one staff narrowed to a single
      // doctor, already makes that obvious from context.
      primaryLabel: practitionerId == null
          ? (appointment, session) =>
                '${appointment.patientName} · ${session.practitionerName}'
          : null,
      apiClient: widget.apiClient,
      // Only a doctor may mark attended or add/edit a record from the
      // calendar - admin/receptionist can look, same as the list already
      // restricts via canAuthorSessionRecords.
      appointmentApi: widget.canAuthorSessionRecords
          ? widget.appointmentApi
          : null,
      onSessionSelected: (appointmentId, sessionId) =>
          _selectCalendarSession(appointmentId, sessionId, wide),
      showCancelledSessions: true,
    );
    if (!wide) return calendar;

    final selected = _selectedCalendarAppointment;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: calendar),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: selected == null
              ? _buildNoSelection()
              : _buildDetailPanel(selected),
        ),
      ],
    );
  }

  // Unlike _selectedAppointment (list mode), this never falls back to "the
  // first appointment" - that fallback exists so the wide list view never
  // shows an empty panel next to a non-empty list, but "first appointment
  // overall" has no relation to whatever day the calendar happens to be
  // showing, so it would just be a confusing, arbitrary pick.
  Appointment? get _selectedCalendarAppointment {
    final id = _selectedId;
    if (id == null) return null;
    for (final appointment in _appointments) {
      if (appointment.id == id) return appointment;
    }
    return null;
  }

  void _selectCalendarSession(
    String appointmentId,
    String sessionId,
    bool wide,
  ) {
    for (final appointment in _appointments) {
      if (appointment.id == appointmentId) {
        _selectAppointment(appointment, wide, sessionId: sessionId);
        return;
      }
    }
  }

  // Only the list scrolls; shell stays put.
  Widget _buildWorkspace(List<Appointment> appointments, bool wide) {
    if (_loading) return const SkeletonList();
    if (_error != null) return _buildError();
    if (appointments.isEmpty) return _buildEmptyState();

    final list = RefreshIndicator(
      onRefresh: _load,
      color: AppColors.rose,
      child: ListView(
        padding: const EdgeInsets.only(right: 4, bottom: 8),
        children: _buildGroupedAppointments(appointments, wide),
      ),
    );
    if (!wide) return list;

    final selected = _selectedAppointment(appointments);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: list),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: selected == null
              ? _buildNoSelection()
              : _buildDetailPanel(selected),
        ),
      ],
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.bgRose, AppColors.bgLavender],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.rose,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appointments', style: AppTypography.displayTitle()),
                const SizedBox(height: 8),
                _buildHeaderCounts(),
              ],
            ),
          ),
          // Both can apply at once now: admin/receptionist get the
          // calendar too, but still need to book - only a doctor's view
          // (which never books from here) shows the toggle alone.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showCalendarTab) ...[
                _buildViewModeToggle(),
                if (!widget.canAuthorSessionRecords) const SizedBox(width: 10),
              ],
              if (!widget.canAuthorSessionRecords)
                FilledButton.icon(
                  onPressed: () => _openBooking(),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Book appointment'),
                ),
            ],
          ),
        ],
      ),
    );
  }

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

  // A doctor's own visits are only ever theirs, so the visit-level count
  // (booked/cancelled) wouldn't tell them anything the session count
  // doesn't already - only the session breakdown matters to them. Staff
  // see the whole clinic, where the two levels genuinely diverge (a
  // visit stays booked while individual sessions on it get completed,
  // cancelled, or missed), so both rows earn their place.
  Widget _buildHeaderCounts() {
    if (widget.doctorUserId != null) {
      return _buildSessionCountsRow();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAppointmentCountsRow(),
        const SizedBox(height: 6),
        _buildSessionCountsRow(),
      ],
    );
  }

  Widget _buildAppointmentCountsRow() {
    final counts = _appointmentCounts;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _countChip('${counts.booked} booked', AppColors.sageDark),
        _countChip('${counts.cancelled} cancelled', AppColors.roseDark),
      ],
    );
  }

  // Same four colors _sessionStatusInfo/_sessionColors use, so a dot up
  // here reads as the same status wherever it's seen - list, calendar, or
  // this summary.
  Widget _buildSessionCountsRow() {
    final counts = _sessionCounts;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _countChip('${counts.planned} planned', AppColors.sageDark),
        _countChip('${counts.cancelled} cancelled', AppColors.roseDark),
        _countChip('${counts.noShow} no show', AppColors.gold),
        _countChip('${counts.completed} completed', AppColors.lavDark),
      ],
    );
  }

  Widget _countChip(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(label, style: AppTypography.labelSmall(color: AppColors.textSub)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // List filters by the visit's own two real states (_matchesStatus);
          // calendar filters by session status instead, matching what it
          // actually colors sessions by (_calendarSourceAppointments).
          final statuses = _viewMode == _ViewMode.calendar
              ? const ['ALL', 'PLANNED', 'COMPLETED', 'CANCELLED', 'NO_SHOW']
              : const ['ALL', 'BOOKED', 'CANCELLED'];
          // Calendar mode is always one day: search and the date filter
          // don't apply there - it has its own day nav for picking which
          // day to show. The doctor filter is different: a doctor's own
          // calendar is implicitly restricted to themselves, but
          // admin/receptionist have no default practitioner in calendar
          // mode either, so they still need it there to pick whose day
          // to view. Status carries over to narrow either mode down further.
          final showListOnlyFilters = _viewMode == _ViewMode.list;
          final showDoctorFilter = widget.doctorUserId == null;
          if (constraints.maxWidth < 720) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (showListOnlyFilters) ...[
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _buildSearchField(),
                  ),
                  _buildDateFilterButton(),
                ],
                if (showDoctorFilter) _buildDoctorFilterButton(),
                for (final status in statuses) _statusChoiceChip(status),
              ],
            );
          }
          return Row(
            children: [
              if (showListOnlyFilters) ...[
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 10),
                _buildDateFilterButton(),
              ],
              if (showDoctorFilter) ...[
                if (showListOnlyFilters) const SizedBox(width: 10),
                _buildDoctorFilterButton(),
              ],
              for (final status in statuses) ...[
                const SizedBox(width: 8),
                _statusChoiceChip(status),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return AppSearchField(
      hintText: 'Search patient or treatment',
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
      onClear: () {
        _searchController.clear();
        setState(() => _query = '');
      },
    );
  }

  Future<void> _pickDateFilter() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => _dateFilter = selected);
  }

  Widget _buildDateFilterButton() {
    final label = _dateFilter == null
        ? 'Any date'
        : DateFormat('d MMM yyyy').format(_dateFilter!);
    final active = _dateFilter != null;
    // "All dates" is a real, visible menu item (not just a hidden long-press
    // gesture) - same pattern as the doctor filter's "Any doctor" entry.
    return PopupMenuButton<String>(
      tooltip: 'Filter by date',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 'any') {
          setState(() => _dateFilter = null);
        } else {
          _pickDateFilter();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'any',
          child: _doctorOption('All dates', !active),
        ),
        PopupMenuItem<String>(
          value: 'pick',
          child: _doctorOption(active ? label : 'Pick a date…', active),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? AppColors.borderRose : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? Icons.event_available_outlined
                  : Icons.calendar_today_outlined,
              size: 16,
              color: active ? AppColors.roseDark : AppColors.textSub,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.labelMedium(
                color: active ? AppColors.roseDark : AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doctorOption(String label, bool isSelected) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: isSelected
              ? const Icon(Icons.check, size: 16, color: AppColors.roseDark)
              : null,
        ),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: isSelected
                ? AppTypography.labelLarge(color: AppColors.roseDark)
                : AppTypography.bodyMedium(),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorFilterButton() {
    DoctorSummary? selectedDoctor;
    for (final doctor in _doctors) {
      if (doctor.userId == _doctorFilter) {
        selectedDoctor = doctor;
        break;
      }
    }
    final label = selectedDoctor?.fullName ?? 'Any doctor';

    // Opens under the chip, never over it.
    return PopupMenuButton<String>(
      tooltip: 'Filter by doctor',
      position: PopupMenuPosition.under,
      onSelected: (value) =>
          setState(() => _doctorFilter = value.isEmpty ? null : value),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '',
          child: _doctorOption('Any doctor', _doctorFilter == null),
        ),
        ..._doctors.map(
          (doctor) => PopupMenuItem<String>(
            value: doctor.userId,
            child: _doctorOption(
              doctor.fullName,
              doctor.userId == _doctorFilter,
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _doctorFilter == null
                ? AppColors.border
                : AppColors.borderRose,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _doctorFilter == null
                  ? Icons.medical_services_outlined
                  : Icons.person_search_outlined,
              size: 16,
              color: _doctorFilter == null
                  ? AppColors.textSub
                  : AppColors.roseDark,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium(
                  color: _doctorFilter == null
                      ? AppColors.textSub
                      : AppColors.roseDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedAppointments(
    List<Appointment> appointments,
    bool wide,
  ) {
    final groups = <String, List<Appointment>>{};
    for (final appointment in appointments) {
      final date = DateFormat(
        'EEE d MMM yyyy',
      ).format(appointment.scheduledAt.toLocal());
      groups.putIfAbsent(date, () => []).add(appointment);
    }

    return [
      for (final entry in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(
            children: [
              Text(
                entry.key.toUpperCase(),
                style: AppTypography.labelSmall(color: AppColors.roseDark),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Divider(height: 1)),
              const SizedBox(width: 10),
              Text(
                '${entry.value.length} ${entry.value.length == 1 ? 'visit' : 'visits'}',
                style: AppTypography.bodySmall(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        for (final appointment in entry.value)
          _buildAppointmentRow(appointment, wide),
      ],
    ];
  }

  Widget _statusChoiceChip(String status) {
    final calendar = _viewMode == _ViewMode.calendar;
    final current = calendar ? _calendarStatusFilter : _statusFilter;
    final selected = current == status;
    return ChoiceChip(
      label: Text(_statusLabel(status)),
      selected: selected,
      onSelected: (_) => setState(() {
        if (calendar) {
          _calendarStatusFilter = status;
        } else {
          _statusFilter = status;
        }
      }),
      showCheckmark: true,
      selectedColor: AppColors.rose,
      checkmarkColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.rose : AppColors.border),
      labelStyle: AppTypography.labelMedium(
        color: selected ? Colors.white : AppColors.textSub,
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      // Appointment-level (list).
      'BOOKED' => 'Booked',
      'CANCELLED' => 'Cancelled',
      // Session-level (calendar) - CANCELLED is shared with the list above,
      // the rest are session-only states.
      'PLANNED' => 'Planned',
      'COMPLETED' => 'Completed',
      'NO_SHOW' => 'No show',
      _ => 'All statuses',
    };
  }

  // The list shows the visit's own entity-level status, full stop - not a
  // derived read of what happened session by session. That distinction
  // belongs to the calendar, which colors individual sessions by their own
  // four-state status instead (see _sessionCounts, and AvailabilitySessionsView
  // for the calendar's own session coloring).
  bool _matchesStatus(Appointment appointment) {
    return switch (_statusFilter) {
      'CANCELLED' => appointment.status == 'CANCELLED',
      'BOOKED' => appointment.status == 'BOOKED',
      _ => true,
    };
  }

  Widget _buildAppointmentRow(Appointment appointment, bool wide) {
    final selected = wide && appointment.id == _selectedId;
    final sessions = appointment.sessions;
    final summary = sessions.isEmpty
        ? 'Appointment'
        : sessions.length == 1
        ? sessions.first.treatmentLabel
        : '${sessions.first.treatmentLabel}, and ${sessions.length - 1} more';
    final practitioner = sessions.isEmpty
        ? null
        : sessions.first.practitionerName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _selectAppointment(appointment, wide),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.rosePale : AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.borderRose : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    DateFormat(
                      'HH:mm',
                    ).format(appointment.scheduledAt.toLocal()),
                    style: AppTypography.numeric(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.bgRose,
                  child: Text(
                    _initials(appointment.patientName),
                    style: AppTypography.labelSmall(color: AppColors.roseDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMedium(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        practitioner == null
                            ? summary
                            : '$summary · $practitioner',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall(
                          color: selected
                              ? AppColors.textSub
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _statusPill(appointment),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // sessionId is the one actually tapped on the calendar, to highlight
  // among its siblings; a list-row tap selects the whole visit with no
  // single session in particular, so it stays null there.
  void _selectAppointment(
    Appointment appointment,
    bool wide, {
    String? sessionId,
  }) {
    if (wide) {
      setState(() {
        _selectedId = appointment.id;
        _selectedSessionId = sessionId;
      });
      return;
    }
    setState(() {
      _selectedId = appointment.id;
      _selectedSessionId = sessionId;
    });
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            controller: controller,
            child: _buildDetailBody(appointment, boxed: false),
          ),
        ),
      ),
    );
  }

  Widget _buildNoSelection() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Select a visit to see its details.',
        style: AppTypography.bodySmall(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildDetailPanel(Appointment appointment) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      // A short viewport (a laptop screen, a zoomed-in browser) can make
      // even the capped 3-session preview taller than the panel - scrolling
      // is the fallback for that, not the norm.
      child: SingleChildScrollView(
        child: _buildDetailBody(appointment, boxed: true),
      ),
    );
  }

  // Scoped by _effectiveDoctorId - see its own doc comment for why.
  List<AppointmentSession> _visibleSessions(Appointment appointment) {
    final doctorId = _effectiveDoctorId;
    if (doctorId == null) return appointment.sessions;
    return appointment.sessions
        .where((session) => session.practitionerUserId == doctorId)
        .toList();
  }

  // Capped to 3 sessions when boxed (the rest reachable via "Show all"),
  // but the panel itself always scrolls now - a cap bounds width and count,
  // not height, and a short enough viewport can still overflow otherwise.
  Widget _buildDetailBody(Appointment appointment, {required bool boxed}) {
    final sessions = _visibleSessions(appointment);
    final shown = sessions.take(boxed ? 3 : sessions.length).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.bgRose,
              child: Text(
                _initials(appointment.patientName),
                style: AppTypography.labelMedium(color: AppColors.roseDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.patientName,
                    style: AppTypography.displaySubtitle().copyWith(
                      fontSize: 19,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'EEE, d MMM yyyy · HH:mm',
                    ).format(appointment.scheduledAt.toLocal()),
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (widget.onViewPatient != null)
              TextButton.icon(
                onPressed: () =>
                    widget.onViewPatient!(appointment.patientUserId),
                icon: const Icon(Icons.person_outline, size: 16),
                label: const Text('Patient'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSub,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'SESSIONS',
            style: AppTypography.labelSmall(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          _sessionList(appointment, shown),
          if (shown.length < sessions.length)
            TextButton(
              onPressed: () => _showAllSessions(appointment),
              child: Text('Show all ${sessions.length} sessions'),
            ),
        ],
        const SizedBox(height: 16),
        _buildActionStrip(appointment),
      ],
    );
  }

  // Admin/receptionist always have full authority over a visit; a doctor
  // only owns the whole thing when every session on it is theirs. Cancel
  // and reschedule both act on the entire visit (rescheduling cancels the
  // old one behind the scenes), so a doctor sharing it with another
  // practitioner can't safely use either - the backend refuses it too, in
  // AppointmentSessionService.assertOwnsWholeVisit.
  bool _ownsWholeVisit(Appointment appointment) {
    return widget.doctorUserId == null ||
        appointment.sessions.every(
          (session) => session.practitionerUserId == widget.doctorUserId,
        );
  }

  Widget _buildActionStrip(Appointment appointment) {
    final upcoming = _canModify(appointment);
    // Both act on the whole visit (rescheduling cancels the old one behind
    // the scenes), and the backend refuses either once a doctor doesn't own
    // every session on it - see AppointmentSessionService.assertOwnsWholeVisit.
    final modifiable = upcoming && _ownsWholeVisit(appointment);
    final sharedVisit = upcoming && !modifiable;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (modifiable)
            TextButton(
              onPressed: () => _cancel(appointment),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSub,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Cancel'),
            ),
          const SizedBox(width: 6),
          Tooltip(
            message: sharedVisit
                ? "This visit includes another doctor's sessions - it isn't "
                      "yours alone to reschedule. Cancel your own sessions above."
                : '',
            child: FilledButton.icon(
              onPressed: modifiable
                  ? () => _openBooking(appointment: appointment)
                  : (upcoming ? null : () => _bookFollowUp(appointment)),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(upcoming ? 'Reschedule' : 'Book follow-up'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rose,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Clips instead of scrolling in short panels.
  Widget _sessionList(
    Appointment appointment,
    List<AppointmentSession> sessions,
  ) {
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final session in sessions) _buildSessionRow(appointment, session),
      ],
    );
  }

  // A record can only be added while the visit is actually happening, or
  // within an hour after it ends - not before it starts, and not long
  // after the fact. Viewing an existing record is never time-restricted.
  bool _isWithinRecordWindow(AppointmentSession session) {
    final now = DateTime.now();
    final windowEnd = session.endTime.add(const Duration(hours: 1));
    return !now.isBefore(session.startTime) && now.isBefore(windowEnd);
  }

  // Staff (no doctorUserId) may cancel any session; a doctor may only
  // cancel their own, and only one that hasn't started yet - a session
  // already under way or in the past is done, not something to undo.
  bool _canCancelSession(AppointmentSession session) {
    return session.isPlanned &&
        session.startTime.isAfter(DateTime.now()) &&
        (widget.doctorUserId == null ||
            session.practitionerUserId == widget.doctorUserId);
  }

  Future<void> _cancelOneSession(
    Appointment appointment,
    AppointmentSession session,
  ) async {
    final confirmed = await confirmDanger(
      context,
      title: 'Cancel this session?',
      message:
          'This drops ${session.treatmentLabel} from the visit on '
          '${DateFormat('d MMM yyyy · HH:mm').format(session.startTime.toLocal())}. '
          'The rest of the visit stays booked.',
      confirmLabel: 'Cancel session',
      cancelLabel: 'Keep it',
    );
    if (!confirmed || !mounted) return;

    final previous = _appointments;
    setState(() {
      _replaceAppointment(
        appointment.copyWith(
          sessions: [
            for (final s in appointment.sessions)
              if (s.id == session.id) s.withStatus('CANCELLED') else s,
          ],
        ),
      );
    });

    try {
      await widget.appointmentApi.cancelSession(appointment.id, session.id);
      if (!mounted) return;
      await _refreshQuietly();
    } catch (_) {
      if (!mounted) return;
      setState(() => _appointments = previous);
      showErrorDialog(context, 'Could not cancel that session.');
    }
  }

  Widget _buildSessionRow(Appointment appointment, AppointmentSession session) {
    final record = _recordsBySession[session.id];
    final canRecord =
        widget.canAuthorSessionRecords &&
        session.status != 'CANCELLED' &&
        session.status != 'NO_SHOW' &&
        (record != null || _isWithinRecordWindow(session)) &&
        (widget.doctorUserId == null ||
            session.practitionerUserId == widget.doctorUserId);
    // Below canAuthorSessionRecords: a completed session's record can still
    // be opened read-only (no mark-attended, no edit) for a viewer with
    // canViewSessionRecords - admin, currently. Only a completed session
    // can even have a record, so nothing else qualifies.
    final canViewOnly =
        !canRecord &&
        widget.canViewSessionRecords &&
        session.status == 'COMPLETED';

    Widget? trailing;
    if (canRecord) {
      trailing = TextButton.icon(
        onPressed: () {
          if (record == null) {
            _completeSession(appointment, session);
          } else {
            _viewSessionRecord(record);
          }
        },
        icon: Icon(
          record != null
              ? Icons.visibility_outlined
              : Icons.check_circle_outline,
          size: 16,
        ),
        label: Text(record != null ? 'View record' : 'Mark attended'),
      );
    } else if (canViewOnly) {
      trailing = TextButton.icon(
        onPressed: () {
          if (record == null) {
            showNoSessionRecordDialog(context);
          } else {
            _viewSessionRecord(record);
          }
        },
        icon: Icon(
          record != null ? Icons.visibility_outlined : Icons.info_outline,
          size: 16,
        ),
        label: Text(record != null ? 'View record' : 'No record yet'),
      );
    } else if (_canCancelSession(session)) {
      trailing = TextButton.icon(
        onPressed: () => _cancelOneSession(appointment, session),
        icon: const Icon(Icons.close, size: 16),
        label: const Text('Cancel'),
        style: TextButton.styleFrom(foregroundColor: AppColors.textSub),
      );
    }

    return SessionDescriptionRow(
      session: session,
      selected: session.id == _selectedSessionId,
      // Doctor's own view: showing their own name on every row is just noise.
      showPractitioner: widget.doctorUserId == null,
      trailing: trailing,
    );
  }

  Future<void> _showAllSessions(Appointment appointment) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appointment.patientName),
        content: SizedBox(
          width: 460,
          // Bounded, not shrink-wrapped: a visit with many sessions must
          // scroll within the dialog rather than grow past the screen.
          height: MediaQuery.of(context).size.height * 0.6,
          child: ListView(
            children: [
              for (final session in _visibleSessions(appointment))
                _buildSessionRow(appointment, session),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(Appointment appointment) {
    final (label, color) = appointment.status == 'CANCELLED'
        ? ('Cancelled', AppColors.rose)
        : ('Booked', AppColors.sage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: AppTypography.labelSmall(color: color)),
    );
  }

  Widget _buildEmptyState() {
    const message = 'No appointments match these filters.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Text(
          message,
          style: AppTypography.bodyMedium(color: AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Text(_error!, style: AppTypography.bodyMedium()),
            const SizedBox(height: 10),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    return parts.take(2).map((part) => part[0]).join().toUpperCase();
  }
}
