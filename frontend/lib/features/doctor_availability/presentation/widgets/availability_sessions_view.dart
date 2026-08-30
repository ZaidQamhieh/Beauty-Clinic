import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../network/api_client.dart';
import '../../../appointments/data/appointment.dart';
import '../../../appointments/data/appointment_api.dart';
import '../../../appointments/data/clinic_time.dart';
import '../../../patient_profile/data/session_record.dart';
import '../../../patient_profile/data/session_record_api.dart';
import '../../../patient_profile/presentation/session_record_dialogs.dart';
import '../../data/doctor_availability_api.dart';

// Window math shared by timeline and DayHoursBar.

/// A `[start, end)` span of minutes.
class DayWindow {
  const DayWindow(this.start, this.end);

  final int start;
  final int end;
}

const List<AvailabilityDay> _weekdaysInOrder = [
  AvailabilityDay.monday,
  AvailabilityDay.tuesday,
  AvailabilityDay.wednesday,
  AvailabilityDay.thursday,
  AvailabilityDay.friday,
  AvailabilityDay.saturday,
  AvailabilityDay.sunday,
];

/// Open minutes for [date]. VACATION beats MODIFIED beats REGULAR outright -
/// whichever is present replaces the others entirely, it isn't merged with
/// them. EXTRA_DAY is a pure fallback: it only ever fills a day whose
/// baseline resolved to nothing, never additive on top of a working day.
List<DayWindow> resolveAvailableWindows(
  DateTime date,
  List<DoctorAvailability> availability,
) {
  final onlyDate = DateTime(date.year, date.month, date.day);
  bool covers(DoctorAvailability rule) {
    final from = _dateOnly(rule.effectiveFrom);
    // Null effectiveTo means open-ended (the normal case for REGULAR), not
    // "same day as effectiveFrom" - it must cover every date from then on.
    if (rule.effectiveTo == null) return !onlyDate.isBefore(from);
    final to = _dateOnly(rule.effectiveTo!);
    return !onlyDate.isBefore(from) && !onlyDate.isAfter(to);
  }

  final weekday = _weekdaysInOrder[date.weekday - 1];
  final onDate = availability.where(covers).toList();

  List<DayWindow> baseline;
  if (onDate.any((rule) => rule.kind == AvailabilityKind.vacation)) {
    baseline = const [];
  } else {
    final modified = onDate
        .where((rule) => rule.kind == AvailabilityKind.modified)
        .toList();
    baseline =
        (modified.isNotEmpty
                ? modified
                : onDate.where(
                    (rule) =>
                        rule.kind == AvailabilityKind.regular &&
                        rule.dayOfWeek == weekday,
                  ))
            .map(_toWindow)
            .toList();
  }

  if (baseline.isEmpty) {
    final extraDay = onDate
        .where((rule) => rule.kind == AvailabilityKind.extraDay)
        .map(_toWindow)
        .toList();
    if (extraDay.isNotEmpty) {
      return extraDay;
    }
  }
  return baseline;
}

DayWindow _toWindow(DoctorAvailability rule) =>
    DayWindow(_parseMinutes(rule.startTime!), _parseMinutes(rule.endTime!));

/// Clamps windows to display range, from [startHour].
List<DayWindow> clampToDisplayRange(
  List<DayWindow> windows,
  int startHour,
  int endHour,
) {
  final displayStart = startHour * 60;
  final totalMinutes = (endHour - startHour) * 60;
  final clamped = <DayWindow>[];
  for (final window in windows) {
    final start = (window.start - displayStart).clamp(0, totalMinutes);
    final end = (window.end - displayStart).clamp(0, totalMinutes);
    if (end > start) {
      clamped.add(DayWindow(start, end));
    }
  }
  clamped.sort((a, b) => a.start.compareTo(b.start));
  return clamped;
}

/// Gaps between windows; no rules means closed.
List<DayWindow> invertWindows(List<DayWindow> windows, int totalMinutes) {
  final gaps = <DayWindow>[];
  var cursor = 0;
  for (final window in windows) {
    if (window.start > cursor) {
      gaps.add(DayWindow(cursor, window.start));
    }
    if (window.end > cursor) {
      cursor = window.end;
    }
  }
  if (cursor < totalMinutes) {
    gaps.add(DayWindow(cursor, totalMinutes));
  }
  return gaps;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _parseMinutes(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return 0;
  final hours = int.tryParse(parts[0]) ?? 0;
  final minutes = int.tryParse(parts[1]) ?? 0;
  return hours * 60 + minutes;
}

/// A day-by-day timeline of booked sessions, with a prev/next/date-picker
/// day filter. Used by the admin's doctor detail view (for any doctor), a
/// doctor's own calendar, and a patient's own calendar - the caller supplies
/// how to fetch each day's sessions. [fetchAvailability] is optional: pass it
/// (as doctors do) to shade the timeline against configured working hours;
/// omit it (as a patient's own calendar does, since patients have no
/// availability concept) to show only booked sessions on a plain background.
class AvailabilitySessionsView extends StatefulWidget {
  const AvailabilitySessionsView({
    super.key,
    required this.fetchSessions,
    this.fetchAvailability,
    this.primaryLabel,
    this.apiClient,
    this.appointmentApi,
    this.preloadedAppointments,
    this.restrictToPractitionerId,
    this.preloadedAvailability,
    this.onSessionSelected,
    this.showCancelledSessions = false,
    this.canTapSession,
    this.fetchAvailabilityKey,
  });

  final Future<List<Appointment>> Function(DateTime date) fetchSessions;
  final Future<List<DoctorAvailability>> Function()? fetchAvailability;

  /// When given, sessions for the selected day are filtered out of this
  /// already-loaded list instead of calling [fetchSessions] - the caller
  /// owns one shared fetch (e.g. a clinic-wide appointment list) that both
  /// a list view and this calendar view render from, rather than each
  /// making its own request. [fetchSessions] is still required (it's used
  /// as a fallback impossible to reach while this is set) so existing
  /// callers are unaffected.
  final List<Appointment>? preloadedAppointments;

  /// Narrows [preloadedAppointments] to one practitioner's own sessions -
  /// relevant since one appointment can span sessions with different
  /// doctors. Ignored when [preloadedAppointments] is null.
  final String? restrictToPractitionerId;

  /// Same idea as [preloadedAppointments] but for [fetchAvailability]: an
  /// already-loaded availability list, used instead of calling
  /// [fetchAvailability]. Needed because [fetchAvailability] is only ever
  /// invoked once, in initState - a caller whose own data arrives after
  /// that point (a sibling fetch still in flight) would otherwise leave the
  /// availability shading permanently empty.
  final List<DoctorAvailability>? preloadedAvailability;

  /// Re-invokes [fetchAvailability] whenever this changes between rebuilds
  /// (compared with `!=`), without remounting the widget - so a caller
  /// whose [fetchAvailability] closure now points at a different
  /// practitioner (staff switching which doctor's calendar they're
  /// viewing, say) gets that doctor's hours instead of the previous one's,
  /// while everything else - which day is selected, in particular - stays
  /// exactly as it was. Ignored when [preloadedAvailability] is set.
  final Object? fetchAvailabilityKey;

  /// When set, tapping a session calls this with its appointment id and its
  /// own session id instead of the built-in view/complete-record dialog
  /// flow - for a caller that shows appointment details in its own panel
  /// (e.g. a shared list+detail layout) rather than have this view manage
  /// dialogs itself. The session id lets that panel highlight the specific
  /// session tapped among its siblings on the same visit.
  final void Function(String appointmentId, String sessionId)?
  onSessionSelected;

  /// A cancelled session is dropped entirely by default (it was never a
  /// real commitment on the calendar) - set true to show it anyway, colored
  /// distinctly, for a view that wants the full history of a slot rather
  /// than just what's currently booked.
  final bool showCancelledSessions;

  /// The bold label shown on each session block. Defaults to the patient's
  /// name (for staff/doctor views); a patient's own calendar passes the
  /// practitioner's name instead, since showing their own name is unhelpful.
  final String Function(Appointment appointment, AppointmentSession session)?
  primaryLabel;

  /// [apiClient] alone makes each session block tappable to view its
  /// existing record, or learn it doesn't have one yet (the admin
  /// doctor-detail view, and a patient's own calendar - both can look, not
  /// record). Providing [appointmentApi] too upgrades that into the
  /// doctor's own full "Mark attended & record" / "Add session record" /
  /// "View session record" action, the same one used in
  /// ClinicAppointmentsScreen. Omit both to leave sessions entirely inert.
  final ApiClient? apiClient;
  final AppointmentApi? appointmentApi;

  /// Restricts which sessions actually respond to a tap - e.g. a patient's
  /// calendar only wants completed sessions clickable (to see the doctor's
  /// notes or learn none were added), not booked/cancelled/no-show ones
  /// that could never have a record. Null (the default) taps every session,
  /// which is what a doctor's own calendar needs (marking a still-planned
  /// session attended happens by tapping it).
  final bool Function(AppointmentSession session)? canTapSession;

  @override
  State<AvailabilitySessionsView> createState() =>
      _AvailabilitySessionsViewState();
}

class _ScheduledSession {
  const _ScheduledSession({
    required this.primaryLabel,
    required this.session,
    required this.appointmentId,
    required this.patientUserId,
  });

  final String primaryLabel;
  final AppointmentSession session;
  final String appointmentId;
  final String patientUserId;
}

/// A session assigned to one of [columnCount] equal-width side-by-side
/// columns within its overlap cluster (column 0 through columnCount - 1) -
/// how two sessions sharing a slot (e.g. a cancelled one and its
/// replacement) end up next to each other instead of stacked.
class _PlacedSession {
  const _PlacedSession(this.session, this.column, this.columnCount);

  final _ScheduledSession session;
  final int column;
  final int columnCount;
}

class _AvailabilitySessionsViewState extends State<AvailabilitySessionsView> {
  late DateTime _selectedDate;
  late Future<List<_ScheduledSession>> _sessionsFuture;
  late Future<List<DoctorAvailability>> _availabilityFuture;
  Map<String, SessionRecord> _recordsBySession = {};
  // Older versions per session, newest first, current one excluded - lets
  // the record dialog offer a "previous versions" list.
  Map<String, List<SessionRecord>> _recordHistoryBySession = {};

  bool get _canRecordSessions =>
      widget.apiClient != null && widget.appointmentApi != null;

  // apiClient alone is enough to load and view existing records; only the
  // write actions (mark attended, add, edit) additionally need appointmentApi.
  // onSessionSelected hands tapping off entirely, so it makes a session
  // tappable on its own too.
  bool get _canViewRecords =>
      widget.apiClient != null || widget.onSessionSelected != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _sessionsFuture = _loadSessions();
    _availabilityFuture = widget.preloadedAvailability != null
        ? Future.value(widget.preloadedAvailability!)
        : (widget.fetchAvailability?.call() ??
              Future.value(const <DoctorAvailability>[]));
  }

  Future<List<_ScheduledSession>> _loadSessions() async {
    final preloaded = widget.preloadedAppointments;
    final appointments = preloaded ?? await widget.fetchSessions(_selectedDate);
    final scheduled = <_ScheduledSession>[];
    for (final appointment in appointments) {
      for (final session in appointment.sessions) {
        if (session.status == 'CANCELLED' && !widget.showCancelledSessions) {
          continue;
        }
        if (preloaded != null && !_isOnSelectedDay(session)) continue;
        if (preloaded != null &&
            widget.restrictToPractitionerId != null &&
            session.practitionerUserId != widget.restrictToPractitionerId) {
          continue;
        }
        scheduled.add(
          _ScheduledSession(
            primaryLabel:
                widget.primaryLabel?.call(appointment, session) ??
                appointment.patientName,
            session: session,
            appointmentId: appointment.id,
            patientUserId: appointment.patientUserId,
          ),
        );
      }
    }
    scheduled.sort(
      (a, b) => a.session.startTime.compareTo(b.session.startTime),
    );
    if (_canViewRecords) {
      unawaited(_loadRecords(scheduled));
    }
    return scheduled;
  }

  bool _isOnSelectedDay(AppointmentSession session) {
    final local = session.startTime.toLocal();
    return local.year == _selectedDate.year &&
        local.month == _selectedDate.month &&
        local.day == _selectedDate.day;
  }

  @override
  void didUpdateWidget(covariant AvailabilitySessionsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only the preloaded path needs this: fetchSessions is re-invoked fresh
    // on every day change already, but a preloaded list is only re-read when
    // its content actually changed. Compared by value, not identity - a
    // caller like ClinicAppointmentsScreen recomputes this list (a fresh
    // List instance, same Appointment objects inside) on every one of its
    // own rebuilds, including ones with nothing to do with appointment data
    // at all (a parent layout resizing during an unrelated animation, say).
    // Reloading - and flashing the loading skeleton - on every such rebuild
    // would turn any of those into a visible glitch for no reason.
    //
    // restrictToPractitionerId is checked separately, not folded into the
    // content comparison above: staff switching which doctor they're
    // filtered to changes nothing about preloadedAppointments itself (same
    // clinic-wide list either way) - only which of its sessions this view
    // should keep. Missing that would leave the previous doctor's sessions
    // on screen after picking a different one.
    if (widget.preloadedAppointments != null &&
        (!listEquals(
              widget.preloadedAppointments,
              oldWidget.preloadedAppointments,
            ) ||
            widget.restrictToPractitionerId !=
                oldWidget.restrictToPractitionerId)) {
      setState(() {
        _sessionsFuture = _loadSessions();
      });
    }

    if (widget.preloadedAvailability != null &&
        !listEquals(
          widget.preloadedAvailability,
          oldWidget.preloadedAvailability,
        )) {
      setState(() {
        _availabilityFuture = Future.value(widget.preloadedAvailability!);
      });
    }

    if (widget.preloadedAvailability == null &&
        widget.fetchAvailability != null &&
        widget.fetchAvailabilityKey != oldWidget.fetchAvailabilityKey) {
      setState(() {
        _availabilityFuture = widget.fetchAvailability!();
      });
    }
  }

  Future<void> _loadRecords(List<_ScheduledSession> scheduled) async {
    final apiClient = widget.apiClient;
    if (apiClient == null) return;
    final api = SessionRecordApi(apiClient);
    final patientIds = scheduled.map((s) => s.patientUserId).toSet();
    final lists = await Future.wait(
      patientIds.map((patientId) async {
        try {
          return await api.listForPatient(patientId);
        } catch (_) {
          return const <SessionRecord>[];
        }
      }),
    );
    if (!mounted) return;
    final history = SessionRecord.historyBySession(
      lists.expand((items) => items),
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

  Future<void> _onSessionTap(_ScheduledSession scheduled) async {
    final onSessionSelected = widget.onSessionSelected;
    if (onSessionSelected != null) {
      onSessionSelected(scheduled.appointmentId, scheduled.session.id);
      return;
    }

    final apiClient = widget.apiClient;
    if (apiClient == null) return;
    final record = _recordsBySession[scheduled.session.id];

    final appointmentApi = widget.appointmentApi;
    if (appointmentApi == null) {
      // Read-only viewer (the admin doctor-detail view, and a patient's own
      // calendar): look, don't record.
      if (record == null) {
        showNoSessionRecordDialog(context);
      } else {
        showSessionRecordViewDialog(
          context: context,
          record: record,
          previousVersions:
              _recordHistoryBySession[scheduled.session.id] ?? const [],
        );
      }
      return;
    }

    if (record == null) {
      final saved = await completeSessionWithRecord(
        context: context,
        apiClient: apiClient,
        appointmentApi: appointmentApi,
        appointmentId: scheduled.appointmentId,
        patientUserId: scheduled.patientUserId,
        session: scheduled.session,
      );
      // The session itself moved from PLANNED to COMPLETED, which the
      // timeline needs to redraw - a full reload is warranted here, unlike
      // a pure content edit below.
      if (saved != null) {
        setState(() {
          _sessionsFuture = _loadSessions();
        });
      }
      return;
    }

    showSessionRecordViewDialog(
      context: context,
      record: record,
      canEdit: true,
      previousVersions:
          _recordHistoryBySession[scheduled.session.id] ?? const [],
      onEdit: () async {
        final saved = await editSessionRecord(
          context: context,
          apiClient: apiClient,
          record: record,
          session: scheduled.session,
          patientUserId: scheduled.patientUserId,
        );
        // Nothing about the session itself changed - just the note - so
        // patch it in directly instead of a full reload.
        if (saved != null) _applySavedRecord(saved);
      },
    );
  }

  void _changeDay(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
      _sessionsFuture = _loadSessions();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 2);
    final last = DateTime(now.year + 2);
    // Keep the opening day inside the range.
    final start = _selectedDate.isBefore(first)
        ? first
        : _selectedDate.isAfter(last)
        ? last
        : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _sessionsFuture = _loadSessions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _buildDayFilterBar(),
        const SizedBox(height: 16),
        FutureBuilder<List<_ScheduledSession>>(
          future: _sessionsFuture,
          builder: (context, sessionsSnapshot) {
            return FutureBuilder<List<DoctorAvailability>>(
              future: _availabilityFuture,
              builder: (context, availabilitySnapshot) {
                final loading =
                    sessionsSnapshot.connectionState != ConnectionState.done ||
                    availabilitySnapshot.connectionState !=
                        ConnectionState.done;
                if (loading) {
                  return const SkeletonList(
                    itemCount: 5,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                  );
                }
                if (sessionsSnapshot.hasError) {
                  return _ErrorCard(
                    message:
                        "Unable to load this day's schedule.\n${sessionsSnapshot.error}",
                  );
                }
                return _DayTimelineView(
                  date: _selectedDate,
                  sessions: sessionsSnapshot.data ?? const [],
                  availability: availabilitySnapshot.data ?? const [],
                  showAvailability:
                      widget.fetchAvailability != null ||
                      widget.preloadedAvailability != null,
                  recordsBySession: _recordsBySession,
                  onSessionTap: _canViewRecords ? _onSessionTap : null,
                  canTapSession: widget.canTapSession,
                  readOnly: !_canRecordSessions,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildDayFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeDay(-1),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous day',
          ),
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.rose,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, d MMM yyyy').format(_selectedDate),
                      style: AppTypography.labelLarge(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _changeDay(1),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.roseDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium(color: AppColors.textSub),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTimelineView extends StatelessWidget {
  const _DayTimelineView({
    required this.date,
    required this.sessions,
    required this.availability,
    required this.showAvailability,
    required this.recordsBySession,
    required this.onSessionTap,
    this.canTapSession,
    required this.readOnly,
  });

  final DateTime date;
  final List<_ScheduledSession> sessions;
  final List<DoctorAvailability> availability;

  /// Whether to shade the timeline against configured availability at all.
  /// False for a patient's own calendar, which has no availability concept.
  final bool showAvailability;

  final Map<String, SessionRecord> recordsBySession;

  /// Non-null makes each session block tappable. Null leaves sessions
  /// entirely inert (a patient's own calendar - no session-record concept
  /// there at all).
  final void Function(_ScheduledSession scheduled)? onSessionTap;

  /// Further restricts which sessions [onSessionTap] applies to. Null means
  /// every session is tappable.
  final bool Function(AppointmentSession session)? canTapSession;

  /// True when tapping can only ever view a record or learn there isn't one
  /// yet (the admin doctor-detail view) - false enables the doctor's own
  /// "Mark attended & record"/"Add session record" actions too.
  final bool readOnly;

  static const int _startHour = 7;
  static const int _endHour = 24;
  static const double _hourHeight = 64;

  int get _totalMinutes => (_endHour - _startHour) * 60;
  double get _totalHeight => (_endHour - _startHour) * _hourHeight;

  // A plain, clearly-open surface for available time - it has to read as
  // distinct from every session color below, so it deliberately stays out
  // of the sage/lavender/rose family those use.
  Color get _availableColor => AppColors.bgCard;
  // Bumped up from a near-invisible 10% so "closed" hours are actually
  // legible as their own state, not just an absence of white.
  Color get _unavailableColor => AppColors.textMuted.withValues(alpha: 0.16);

  @override
  Widget build(BuildContext context) {
    final List<DayWindow> available;
    final List<DayWindow> unavailable;
    if (showAvailability) {
      final absoluteWindows = resolveAvailableWindows(date, availability);
      final clampedWindows = clampToDisplayRange(
        absoluteWindows,
        _startHour,
        _endHour,
      );
      available = clampedWindows;
      unavailable = invertWindows(clampedWindows, _totalMinutes);
    } else {
      available = const [];
      unavailable = const [];
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                sessions.isEmpty
                    ? 'No sessions this day'
                    : '${sessions.length} session${sessions.length == 1 ? '' : 's'} this day',
                style: AppTypography.labelLarge(),
              ),
              if (showAvailability) _legendDot(_availableColor, 'Available'),
              _legendDot(_sessionColors('PLANNED').accent, 'Planned'),
              _legendDot(_sessionColors('COMPLETED').accent, 'Completed'),
              _legendDot(_sessionColors('CANCELLED').accent, 'Cancelled'),
              _legendDot(_sessionColors('NO_SHOW').accent, 'No show'),
              if (showAvailability)
                _legendDot(_unavailableColor, 'Unavailable'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hourLabels(),
                const SizedBox(width: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return Stack(
                        children: [
                          for (final segment in available)
                            _shadedSegment(segment, _availableColor),
                          for (final segment in unavailable)
                            _shadedSegment(segment, _unavailableColor),
                          IgnorePointer(child: _hourGridLines()),
                          for (final placed in _placeOverlapping(sessions))
                            _sessionBlock(placed, width),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // A booked session and, say, the cancelled one it replaced can land in the
  // exact same slot; drawing both full-width would hide one under the other.
  // Overlapping sessions are clustered into connected groups, then packed
  // into as many side-by-side columns as the group actually needs (a greedy
  // interval-scheduling packing - the same idea used for calendar-app event
  // layout), so every one of them stays visible and tappable.
  List<_PlacedSession> _placeOverlapping(List<_ScheduledSession> input) {
    final clusters = <List<_ScheduledSession>>[];
    for (final scheduled in input) {
      final overlapping = <List<_ScheduledSession>>[];
      for (final cluster in clusters) {
        if (cluster.any((member) => _timesOverlap(member, scheduled))) {
          overlapping.add(cluster);
        }
      }
      if (overlapping.isEmpty) {
        clusters.add([scheduled]);
      } else {
        final target = overlapping.first;
        target.add(scheduled);
        for (final other in overlapping.skip(1)) {
          target.addAll(other);
          clusters.remove(other);
        }
      }
    }

    final placed = <_PlacedSession>[];
    for (final cluster in clusters) {
      final sorted = [...cluster]
        ..sort((a, b) => a.session.startTime.compareTo(b.session.startTime));
      final columnEnds = <int>[];
      final columnOf = <_ScheduledSession, int>{};
      for (final scheduled in sorted) {
        final start = _minutesOf(scheduled.session.startTime);
        var column = -1;
        for (var i = 0; i < columnEnds.length; i++) {
          if (columnEnds[i] <= start) {
            column = i;
            break;
          }
        }
        if (column == -1) {
          column = columnEnds.length;
          columnEnds.add(0);
        }
        columnEnds[column] = _minutesOf(scheduled.session.endTime);
        columnOf[scheduled] = column;
      }
      for (final scheduled in sorted) {
        placed.add(
          _PlacedSession(scheduled, columnOf[scheduled]!, columnEnds.length),
        );
      }
    }
    return placed;
  }

  bool _timesOverlap(_ScheduledSession a, _ScheduledSession b) {
    final aStart = _minutesOf(a.session.startTime);
    final aEnd = _minutesOf(a.session.endTime);
    final bStart = _minutesOf(b.session.startTime);
    final bEnd = _minutesOf(b.session.endTime);
    return aStart < bEnd && bStart < aEnd;
  }

  int _minutesOf(DateTime time) {
    final local = ClinicTime.at(time);
    return local.hour * 60 + local.minute;
  }

  // Mirrors ClinicAppointmentsScreen's palette, so a session reads the same
  // color whether it's seen in the list or the calendar. Four genuinely
  // distinct statuses get four distinct hues, rather than folding no-show
  // into cancelled - they mean different things (one is a deliberate
  // cancellation, the other is a patient who never turned up).
  ({Color accent, Color background}) _sessionColors(String status) {
    return switch (status) {
      'COMPLETED' => (
        accent: AppColors.lavDark,
        background: AppColors.bgLavender,
      ),
      'CANCELLED' => (accent: AppColors.roseDark, background: AppColors.bgRose),
      'NO_SHOW' => (accent: AppColors.gold, background: AppColors.goldPale),
      _ => (accent: AppColors.sageDark, background: AppColors.bgSage),
    };
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.bodySmall()),
      ],
    );
  }

  Widget _hourLabels() {
    return SizedBox(
      width: 52,
      child: Column(
        children: [
          for (var hour = _startHour; hour < _endHour; hour++)
            SizedBox(
              height: _hourHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  DateFormat('h a').format(DateTime(2000, 1, 1, hour)),
                  style: AppTypography.bodySmall(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hourGridLines() {
    return Column(
      children: [
        for (var hour = _startHour; hour < _endHour; hour++)
          Container(
            height: _hourHeight,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
          ),
      ],
    );
  }

  Widget _shadedSegment(DayWindow segment, Color color) {
    return Positioned(
      top: segment.start / 60.0 * _hourHeight,
      left: 0,
      right: 0,
      height: (segment.end - segment.start) / 60.0 * _hourHeight,
      child: Container(color: color),
    );
  }

  Widget _sessionBlock(_PlacedSession placed, double totalWidth) {
    final scheduled = placed.session;
    final session = scheduled.session;
    final displayStart = _startHour * 60;
    final localStart = ClinicTime.at(session.startTime);
    final localEnd = ClinicTime.at(session.endTime);
    final startMinutes =
        (localStart.hour * 60 + localStart.minute) - displayStart;
    final endMinutes = (localEnd.hour * 60 + localEnd.minute) - displayStart;
    final clampedStart = startMinutes.clamp(0, _totalMinutes);
    final clampedEnd = endMinutes.clamp(0, _totalMinutes);
    if (clampedEnd <= clampedStart) {
      return const SizedBox.shrink();
    }

    final colors = _sessionColors(session.status);
    final accent = colors.accent;
    final background = colors.background;

    final blockHeight = (clampedEnd - clampedStart) / 60.0 * _hourHeight;

    final tappable =
        onSessionTap != null && (canTapSession?.call(session) ?? true);

    // Only sessions that actually overlap another one get squeezed into a
    // narrower column with a small gap between them; a lone session in its
    // slot keeps the exact same full-width look as before.
    const outerPadding = 4.0;
    const columnGap = 3.0;
    final gap = placed.columnCount > 1 ? columnGap : 0.0;
    final columnWidth =
        (totalWidth - outerPadding * 2) / placed.columnCount;
    final left = outerPadding + placed.column * columnWidth;
    final blockWidth = columnWidth - gap;

    return Positioned(
      top: clampedStart / 60.0 * _hourHeight,
      left: left,
      width: blockWidth,
      height: blockHeight,
      child: ClipRect(
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: tappable ? () => onSessionTap!(scheduled) : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: accent, width: 3)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final primaryLabel = scheduled.primaryLabel.isEmpty
                      ? 'Patient'
                      : scheduled.primaryLabel;
                  final timeRange =
                      '${DateFormat('h:mm a').format(localStart)}–${DateFormat('h:mm a').format(localEnd)}';

                  // Below two comfortable lines of text, cram everything
                  // onto one line rather than dropping details.
                  if (constraints.maxHeight < 28) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          style: AppTypography.labelMedium(),
                          children: [
                            TextSpan(text: primaryLabel),
                            TextSpan(
                              text: ' · ${session.treatmentLabel} · ',
                              style: AppTypography.bodySmall(color: accent),
                            ),
                            TextSpan(
                              text: timeRange,
                              style: AppTypography.bodySmall(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }

                  // Only room for the record action once the block is tall
                  // enough to fit a third line comfortably; shorter blocks
                  // stay tappable via the InkWell above instead.
                  final showActionButton =
                      tappable && constraints.maxHeight >= 60;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        primaryLabel,
                        style: AppTypography.labelMedium(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: session.treatmentLabel,
                              style: AppTypography.bodySmall(color: accent),
                            ),
                            TextSpan(
                              text: ' · $timeRange',
                              style: AppTypography.bodySmall(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showActionButton) ...[
                        const SizedBox(height: 4),
                        Theme(
                          data: Theme.of(context).copyWith(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: SessionRecordActionButton(
                            session: session,
                            hasRecord: recordsBySession.containsKey(session.id),
                            onTap: () => onSessionTap!(scheduled),
                            readOnly: readOnly,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// DAY HOURS BAR

/// One-row summary of open, closed, booked hours.
class DayHoursBar extends StatelessWidget {
  const DayHoursBar({
    super.key,
    required this.date,
    required this.availability,
    required this.sessions,
    this.startHour = 7,
    this.endHour = 24,
    this.height = 28,
  });

  final DateTime date;
  final List<DoctorAvailability> availability;
  final List<AppointmentSession> sessions;
  final int startHour;
  final int endHour;
  final double height;

  int get _totalMinutes => (endHour - startHour) * 60;

  // Matches _DayTimelineView's palette so "available"/"unavailable" reads
  // the same wherever it's shown.
  Color get _availableColor => AppColors.bgCard;
  Color get _unavailableColor => AppColors.textMuted.withValues(alpha: 0.16);
  Color get _bookedColor => AppColors.rose;

  @override
  Widget build(BuildContext context) {
    final absoluteWindows = resolveAvailableWindows(date, availability);
    final available = clampToDisplayRange(absoluteWindows, startHour, endHour);
    final booked = _bookedSegments();

    final labelHours = _labelHours();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(_availableColor, 'Available'),
            const SizedBox(width: 10),
            _legendDot(_bookedColor, 'Booked'),
            const SizedBox(width: 10),
            _legendDot(_unavailableColor, 'Unavailable'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    Container(color: _unavailableColor),
                    for (final segment in available)
                      _segment(segment, width, _availableColor),
                    for (final segment in booked)
                      _segment(segment, width, _bookedColor),
                    for (final hour in labelHours) _tickLine(hour, width),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 14,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                children: [
                  for (final hour in labelHours) _hourLabel(hour, width),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Every hour from [startHour] to [endHour].
  List<int> _labelHours() => [for (var h = startHour; h <= endHour; h++) h];

  Widget _tickLine(int hour, double width) {
    final frac = (hour - startHour) / (endHour - startHour);
    return Positioned(
      left: (frac * width).clamp(0, width - 1),
      top: 0,
      bottom: 0,
      child: Container(width: 1, color: AppColors.border),
    );
  }

  Widget _hourLabel(int hour, double width) {
    final frac = (hour - startHour) / (endHour - startHour);
    final align = frac <= 0
        ? 0.0
        : frac >= 1
        ? -1.0
        : -0.5;
    return Positioned(
      left: frac * width,
      child: FractionalTranslation(
        translation: Offset(align, 0),
        child: Text(
          DateFormat('h a').format(DateTime(2000, 1, 1, hour % 24)),
          style: AppTypography.labelSmall(),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.labelSmall()),
      ],
    );
  }

  Widget _segment(DayWindow segment, double totalWidth, Color color) {
    final left = segment.start / _totalMinutes * totalWidth;
    final segmentWidth =
        (segment.end - segment.start) / _totalMinutes * totalWidth;
    return Positioned(
      left: left,
      width: segmentWidth,
      top: 0,
      bottom: 0,
      child: Container(color: color),
    );
  }

  List<DayWindow> _bookedSegments() {
    final displayStart = startHour * 60;
    final segments = <DayWindow>[];
    for (final session in sessions) {
      if (session.status == 'CANCELLED') continue;
      final localStart = ClinicTime.at(session.startTime);
      final localEnd = ClinicTime.at(session.endTime);
      final start = (localStart.hour * 60 + localStart.minute) - displayStart;
      final end = (localEnd.hour * 60 + localEnd.minute) - displayStart;
      final clampedStart = start.clamp(0, _totalMinutes);
      final clampedEnd = end.clamp(0, _totalMinutes);
      if (clampedEnd > clampedStart) {
        segments.add(DayWindow(clampedStart, clampedEnd));
      }
    }
    return segments;
  }
}
