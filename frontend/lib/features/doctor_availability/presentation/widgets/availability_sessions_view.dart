import 'dart:async';

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
  });

  final Future<List<Appointment>> Function(DateTime date) fetchSessions;
  final Future<List<DoctorAvailability>> Function()? fetchAvailability;

  /// The bold label shown on each session block. Defaults to the patient's
  /// name (for staff/doctor views); a patient's own calendar passes the
  /// practitioner's name instead, since showing their own name is unhelpful.
  final String Function(Appointment appointment, AppointmentSession session)?
  primaryLabel;

  /// [apiClient] alone makes each session block tappable to view its
  /// existing record, or learn it doesn't have one yet (the admin
  /// doctor-detail view - it can look, not record). Providing
  /// [appointmentApi] too upgrades that into the doctor's own full "Mark
  /// attended & record" / "Add session record" / "View session record"
  /// action, the same one used in ClinicAppointmentsScreen. Omit both to
  /// leave sessions entirely inert (a patient's own calendar).
  final ApiClient? apiClient;
  final AppointmentApi? appointmentApi;

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

class _AvailabilitySessionsViewState extends State<AvailabilitySessionsView> {
  late DateTime _selectedDate;
  late Future<List<_ScheduledSession>> _sessionsFuture;
  late final Future<List<DoctorAvailability>> _availabilityFuture;
  Map<String, SessionRecord> _recordsBySession = {};

  bool get _canRecordSessions =>
      widget.apiClient != null && widget.appointmentApi != null;

  // apiClient alone is enough to load and view existing records; only the
  // write actions (mark attended, add, edit) additionally need appointmentApi.
  bool get _canViewRecords => widget.apiClient != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _sessionsFuture = _loadSessions();
    _availabilityFuture =
        widget.fetchAvailability?.call() ??
        Future.value(const <DoctorAvailability>[]);
  }

  Future<List<_ScheduledSession>> _loadSessions() async {
    final appointments = await widget.fetchSessions(_selectedDate);
    final scheduled = <_ScheduledSession>[];
    for (final appointment in appointments) {
      for (final session in appointment.sessions) {
        if (session.status == 'CANCELLED') continue;
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
    setState(() {
      _recordsBySession = {
        for (final record in lists.expand((items) => items))
          record.sessionId: record,
      };
    });
  }

  Future<void> _onSessionTap(_ScheduledSession scheduled) async {
    final apiClient = widget.apiClient;
    if (apiClient == null) return;
    final record = _recordsBySession[scheduled.session.id];

    final appointmentApi = widget.appointmentApi;
    if (appointmentApi == null) {
      // Read-only viewer (the admin doctor-detail view): look, don't record.
      if (record == null) {
        showNoSessionRecordDialog(context);
      } else {
        showSessionRecordViewDialog(context: context, record: record);
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
      if (saved) {
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
      onEdit: () async {
        final saved = await editSessionRecord(
          context: context,
          apiClient: apiClient,
          record: record,
          session: scheduled.session,
          patientUserId: scheduled.patientUserId,
        );
        if (saved) {
          setState(() {
            _sessionsFuture = _loadSessions();
          });
        }
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
                  showAvailability: widget.fetchAvailability != null,
                  recordsBySession: _recordsBySession,
                  onSessionTap: _canViewRecords ? _onSessionTap : null,
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

  /// True when tapping can only ever view a record or learn there isn't one
  /// yet (the admin doctor-detail view) - false enables the doctor's own
  /// "Mark attended & record"/"Add session record" actions too.
  final bool readOnly;

  static const int _startHour = 7;
  static const int _endHour = 24;
  static const double _hourHeight = 64;

  int get _totalMinutes => (_endHour - _startHour) * 60;
  double get _totalHeight => (_endHour - _startHour) * _hourHeight;

  Color get _availableColor => AppColors.white;
  Color get _unavailableColor => AppColors.textMuted.withValues(alpha: 0.10);

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
    final appointmentGroups = _appointmentGroups();

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
          Row(
            children: [
              Text(
                sessions.isEmpty
                    ? 'No sessions booked for this day'
                    : '${sessions.length} session${sessions.length == 1 ? '' : 's'} booked',
                style: AppTypography.labelLarge(),
              ),
              const Spacer(),
              if (showAvailability) ...[
                _legendDot(_availableColor, 'Available'),
                const SizedBox(width: 12),
              ],
              _legendDot(AppColors.rose, 'Booked'),
              if (showAvailability) ...[
                const SizedBox(width: 12),
                _legendDot(_unavailableColor, 'Unavailable'),
              ],
              if (appointmentGroups.isNotEmpty) ...[
                const SizedBox(width: 12),
                _legendOutline(AppColors.lavDark, 'Visit'),
              ],
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
                  child: Stack(
                    children: [
                      for (final segment in available)
                        _shadedSegment(segment, _availableColor),
                      for (final segment in unavailable)
                        _shadedSegment(segment, _unavailableColor),
                      IgnorePointer(child: _hourGridLines()),
                      for (final group in appointmentGroups)
                        _appointmentGroupBox(group),
                      for (final scheduled in sessions)
                        _sessionBlock(scheduled),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _legendOutline(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(3),
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

  /// Groups sessions that belong to the same visit (appointment), so a
  /// multi-treatment booking can be outlined as one whole - only visits
  /// with more than one session get a box; a lone session is already fully
  /// represented by its own block.
  List<List<_ScheduledSession>> _appointmentGroups() {
    final byAppointmentId = <String, List<_ScheduledSession>>{};
    for (final scheduled in sessions) {
      byAppointmentId
          .putIfAbsent(scheduled.session.appointmentId, () => [])
          .add(scheduled);
    }
    return byAppointmentId.values.where((group) => group.length > 1).toList();
  }

  Widget _appointmentGroupBox(List<_ScheduledSession> group) {
    final displayStart = _startHour * 60;
    final starts = group.map((scheduled) {
      final start = ClinicTime.at(scheduled.session.startTime);
      return (start.hour * 60 + start.minute) - displayStart;
    });
    final ends = group.map((scheduled) {
      final end = ClinicTime.at(scheduled.session.endTime);
      return (end.hour * 60 + end.minute) - displayStart;
    });
    final start = starts
        .reduce((a, b) => a < b ? a : b)
        .clamp(0, _totalMinutes);
    final end = ends.reduce((a, b) => a > b ? a : b).clamp(0, _totalMinutes);
    if (end <= start) {
      return const SizedBox.shrink();
    }

    // A little breathing room around the sessions it contains, so the frame
    // doesn't sit flush against their edges.
    const verticalPadding = 4.0;
    const horizontalPadding = 2.0;
    final top = (start / 60.0 * _hourHeight - verticalPadding).clamp(
      0.0,
      _totalHeight,
    );
    final bottom = (end / 60.0 * _hourHeight + verticalPadding).clamp(
      0.0,
      _totalHeight,
    );

    return Positioned(
      top: top,
      left: horizontalPadding,
      right: horizontalPadding,
      height: bottom - top,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.lav.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.lavDark, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _sessionBlock(_ScheduledSession scheduled) {
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

    // Softer rose; sage still reads open.
    final isPast = session.status == 'COMPLETED' || session.status == 'NO_SHOW';
    final accent = isPast ? AppColors.roseLight : AppColors.rose;
    final background = isPast ? AppColors.rosePale : AppColors.bgRose;

    final blockHeight = (clampedEnd - clampedStart) / 60.0 * _hourHeight;

    final tappable = onSessionTap != null;

    return Positioned(
      top: clampedStart / 60.0 * _hourHeight,
      left: 4,
      right: 4,
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

  Color get _availableColor => AppColors.white;
  Color get _unavailableColor => AppColors.textMuted.withValues(alpha: 0.14);
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
