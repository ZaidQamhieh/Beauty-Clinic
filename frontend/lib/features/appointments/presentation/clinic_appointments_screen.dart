import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../network/api_client.dart';
import '../data/appointment.dart';
import '../data/appointment_api.dart';
import '../data/doctor_api.dart';
import '../data/treatment_api.dart';
import '../../patient_profile/data/session_record_api.dart';
import '../../patient_profile/data/session_record.dart';
import '../../patient_profile/presentation/session_record_dialogs.dart';
import 'booking_flow_sheet.dart';

/// Clinic-wide appointment workspace for staff.
class ClinicAppointmentsScreen extends StatefulWidget {
  const ClinicAppointmentsScreen({
    super.key,
    required this.appointmentApi,
    required this.treatmentApi,
    required this.doctorApi,
    required this.apiClient,
    this.canAuthorSessionRecords = false,
    this.doctorUserId,
    this.onViewPatient,
  });

  final AppointmentApi appointmentApi;
  final TreatmentApi treatmentApi;
  final DoctorApi doctorApi;
  final ApiClient apiClient;
  final bool canAuthorSessionRecords;
  final String? doctorUserId;
  final ValueChanged<String>? onViewPatient;

  @override
  State<ClinicAppointmentsScreen> createState() =>
      _ClinicAppointmentsScreenState();
}

class _ClinicAppointmentsScreenState extends State<ClinicAppointmentsScreen> {
  String _statusFilter = 'ALL';
  DateTime? _dateFilter;
  List<Appointment> _appointments = const [];
  bool _loading = true;
  String? _error;
  Map<String, SessionRecord> _recordsBySession = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.appointmentApi.allForStaff();
      if (!mounted) return;
      setState(() {
        _appointments = page.items;
        _loading = false;
      });
      await _loadSessionRecords(page.items);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load clinic appointments.';
      });
    }
  }

  Future<void> _loadSessionRecords(List<Appointment> appointments) async {
    final recordLists = await Future.wait(
      appointments.map((appointment) async {
        try {
          return await SessionRecordApi(
            widget.apiClient,
          ).listForPatient(appointment.patientUserId);
        } catch (_) {
          return const <SessionRecord>[];
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _recordsBySession = {
        for (final record in recordLists.expand((items) => items))
          record.sessionId: record,
      };
    });
  }

  Future<void> _openBooking({Appointment? appointment}) async {
    if (appointment != null && !_canModify(appointment)) return;
    String? patientUserId;
    if (appointment == null) {
      patientUserId = await _choosePatient();
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

  Future<String?> _choosePatient() async {
    try {
      final response = await widget.apiClient.get<Map<String, dynamic>>(
        '/api/patients',
        queryParameters: {'size': 100, 'sort': 'user.lastName,asc'},
      );
      final patients = (response.data?['content'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return null;
      return await showDialog<String>(
        context: context,
        builder: (context) {
          final searchController = TextEditingController();
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final query = searchController.text.trim().toLowerCase();
              final filteredPatients = patients.where((patient) {
                final name =
                    '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'
                        .toLowerCase();
                return query.isEmpty || name.contains(query);
              }).toList();
              return AlertDialog(
                title: const Text('Select patient'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search by patient name',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (filteredPatients.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No patients found.'),
                        )
                      else
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredPatients.length,
                            itemBuilder: (_, index) {
                              final patient = filteredPatients[index];
                              return ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(
                                  '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}',
                                ),
                                subtitle: Text(
                                  patient['phone']?.toString() ??
                                      patient['email']?.toString() ??
                                      'No contact',
                                ),
                                onTap: () => Navigator.of(
                                  context,
                                ).pop(patient['id']?.toString()),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load patients.')),
        );
      }
      return null;
    }
  }

  Future<void> _cancel(Appointment appointment) async {
    if (!_canModify(appointment)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text(
          'Cancel ${appointment.patientName}\'s appointment on '
          '${DateFormat('d MMM yyyy · HH:mm').format(appointment.scheduledAt.toLocal())}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.appointmentApi.cancel(appointment.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel the appointment.')),
      );
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
    if (saved) {
      await _load();
    }
  }

  void _viewSessionRecord(SessionRecord record) {
    showSessionRecordViewDialog(
      context: context,
      record: record,
      canEdit: widget.canAuthorSessionRecords,
      onEdit: () => _editSessionRecord(record),
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
    if (saved) {
      await _load();
    }
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
      return matchesStatus && matchesDate;
    }).toList();
    sorted.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _visibleAppointments;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.rose,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildPageHeader(),
          const SizedBox(height: 20),
          _buildSummary(appointments),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: AppColors.rose),
              const SizedBox(width: 8),
              Text('Find an appointment', style: AppTypography.labelLarge()),
            ],
          ),
          const SizedBox(height: 12),
          _buildScheduleFilters(),
          const SizedBox(height: 12),
          _buildStatusFilter(),
          const SizedBox(height: 20),
          if (_loading)
            const SizedBox(height: 400, child: SkeletonList())
          else if (_error != null)
            _buildError()
          else if (appointments.isEmpty)
            _buildEmptyState()
          else
            ..._buildGroupedAppointments(appointments),
        ],
      ),
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
                const SizedBox(height: 4),
                Text(
                  widget.canAuthorSessionRecords
                      ? 'Your assigned consultations and clinical follow-up.'
                      : 'Clinic schedule and patient visits.',
                  style: AppTypography.bodySmall(color: AppColors.textSub),
                ),
              ],
            ),
          ),
          if (!widget.canAuthorSessionRecords)
            FilledButton.icon(
              onPressed: () => _openBooking(),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Book appointment'),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<Appointment> appointments) {
    final now = DateTime.now();
    final upcoming = appointments.where((appointment) {
      if (appointment.status != 'BOOKED') return false;
      return appointment.sessions.any(
        (session) =>
            session.status == 'PLANNED' && !session.startTime.isBefore(now),
      );
    }).length;
    final completed = appointments
        .expand((appointment) => appointment.sessions)
        .where((session) => session.status == 'COMPLETED')
        .length;
    return Row(
      children: [
        Expanded(
          child: _summaryTile(
            'Upcoming',
            '$upcoming',
            Icons.pending_actions_outlined,
            AppColors.gold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryTile(
            'Completed',
            '$completed',
            Icons.check_circle_outline,
            AppColors.sage,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTypography.displaySubtitle()),
                Text(
                  label,
                  style: AppTypography.bodySmall(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleFilters() {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: _dateFilter ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (selected != null) setState(() => _dateFilter = selected);
        },
        icon: const Icon(Icons.calendar_today_outlined, size: 16),
        label: Text(
          _dateFilter == null
              ? 'Any date'
              : DateFormat('d MMM yyyy').format(_dateFilter!),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedAppointments(List<Appointment> appointments) {
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
          child: Text(
            entry.key,
            style: AppTypography.labelLarge(color: AppColors.roseDark),
          ),
        ),
        for (final appointment in entry.value)
          _buildAppointmentCard(appointment),
      ],
    ];
  }

  Widget _buildStatusFilter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 18,
                color: AppColors.rose,
              ),
              const SizedBox(width: 8),
              Text(
                'Filter by booking status',
                style: AppTypography.labelMedium(color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _statusChoiceChip('ALL'),
              _statusChoiceChip('BOOKED'),
              _statusChoiceChip('CANCELLED'),
              _statusChoiceChip('FINISHED'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChoiceChip(String status) {
    return ChoiceChip(
      label: Text(_statusLabel(status)),
      selected: _statusFilter == status,
      onSelected: (_) => setState(() => _statusFilter = status),
      showCheckmark: true,
      selectedColor: AppColors.rose,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: _statusFilter == status ? AppColors.rose : AppColors.border,
      ),
      labelStyle: AppTypography.labelMedium(
        color: _statusFilter == status ? Colors.white : AppColors.textSub,
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'BOOKED' => 'Booked',
      'CANCELLED' => 'Cancelled',
      'FINISHED' => 'Finished',
      _ => 'All statuses',
    };
  }

  bool _matchesStatus(Appointment appointment) {
    return switch (_statusFilter) {
      'BOOKED' => appointment.status == 'BOOKED',
      'CANCELLED' => appointment.status == 'CANCELLED',
      'FINISHED' =>
        appointment.sessions.isNotEmpty &&
            appointment.sessions.every(
              (session) => session.status == 'COMPLETED',
            ),
      _ => true,
    };
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    final sessions = appointment.sessions;
    final statusColor = appointment.status == 'CANCELLED'
        ? AppColors.rose
        : AppColors.sage;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.bgRose,
                child: Text(
                  _initials(appointment.patientName),
                  style: AppTypography.labelMedium(color: AppColors.rose),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.patientName,
                      style: AppTypography.labelLarge(),
                    ),
                    Text(
                      DateFormat(
                        'EEE, d MMM yyyy · HH:mm',
                      ).format(appointment.scheduledAt.toLocal()),
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(appointment.status, statusColor),
            ],
          ),
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            for (final session in sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.spa_outlined,
                          size: 16,
                          color: AppColors.rose,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.treatmentLabel,
                            style: AppTypography.bodyMedium(),
                          ),
                        ),
                        Text(
                          session.practitionerName,
                          style: AppTypography.bodySmall(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    if (widget.canAuthorSessionRecords &&
                        session.status != 'CANCELLED' &&
                        session.status != 'NO_SHOW' &&
                        (widget.doctorUserId == null ||
                            session.practitionerUserId == widget.doctorUserId))
                      Align(
                        alignment: Alignment.centerRight,
                        child: SessionRecordActionButton(
                          session: session,
                          hasRecord: _recordsBySession.containsKey(session.id),
                          onTap: () {
                            final record = _recordsBySession[session.id];
                            if (record == null) {
                              _completeSession(appointment, session);
                            } else {
                              _viewSessionRecord(record);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
          if (_canModify(appointment)) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _cancel(appointment),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openBooking(appointment: appointment),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text('Reschedule'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rose,
                  ),
                ),
              ],
            ),
          ],
          if (widget.onViewPatient != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    widget.onViewPatient!(appointment.patientUserId),
                icon: const Icon(Icons.person_outline, size: 16),
                label: const Text('View patient details'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status == 'BOOKED' ? 'Booked' : 'Cancelled',
        style: AppTypography.labelSmall(color: color),
      ),
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
