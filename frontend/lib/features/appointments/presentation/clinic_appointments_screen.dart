import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../network/api_client.dart';
import '../data/appointment.dart';
import '../data/appointment_api.dart';
import '../data/doctor_api.dart';
import '../data/doctor_summary.dart';
import '../data/treatment_api.dart';
import 'booking_flow_sheet.dart';

/// Clinic-wide appointment workspace for staff.
class ClinicAppointmentsScreen extends StatefulWidget {
  const ClinicAppointmentsScreen({
    super.key,
    required this.appointmentApi,
    required this.treatmentApi,
    required this.doctorApi,
    required this.apiClient,
  });

  final AppointmentApi appointmentApi;
  final TreatmentApi treatmentApi;
  final DoctorApi doctorApi;
  final ApiClient apiClient;

  @override
  State<ClinicAppointmentsScreen> createState() =>
      _ClinicAppointmentsScreenState();
}

enum _TimeFilter { all, past, current, future }

class _ClinicAppointmentsScreenState extends State<ClinicAppointmentsScreen> {
  _TimeFilter _timeFilter = _TimeFilter.current;
  String _statusFilter = 'ALL';
  String? _doctorFilter;
  DateTime? _dateFilter;
  List<Appointment> _appointments = const [];
  bool _loading = true;
  String? _error;

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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load clinic appointments.';
      });
    }
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
      return showDialog<String>(
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

  bool _canModify(Appointment appointment) {
    return appointment.status == 'BOOKED' &&
        appointment.scheduledAt.isAfter(DateTime.now());
  }

  List<Appointment> get _visibleAppointments {
    final now = DateTime.now();
    final sorted = _appointments.where((appointment) {
      final scheduled = appointment.scheduledAt.toLocal();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(scheduled.year, scheduled.month, scheduled.day);
      final matchesTime = switch (_timeFilter) {
        _TimeFilter.all => true,
        _TimeFilter.past =>
          appointment.status == 'CANCELLED' || scheduled.isBefore(now),
        _TimeFilter.current => day == today,
        _TimeFilter.future => scheduled.isAfter(now),
      };
      final matchesStatus =
          _statusFilter == 'ALL' || appointment.status == _statusFilter;
      final matchesDoctor =
          _doctorFilter == null ||
          appointment.sessions.any(
            (session) => session.practitionerUserId == _doctorFilter,
          );
      final matchesDate =
          _dateFilter == null ||
          (scheduled.year == _dateFilter!.year &&
              scheduled.month == _dateFilter!.month &&
              scheduled.day == _dateFilter!.day);
      return matchesTime && matchesStatus && matchesDoctor && matchesDate;
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
          Text('Clinic Appointments', style: AppTypography.displayTitle()),
          const SizedBox(height: 16),
          Text(
            'Book a new appointment',
            style: AppTypography.displaySubtitle(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _openBooking(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Book appointment'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          Text('View appointments', style: AppTypography.displaySubtitle()),
          const SizedBox(height: 16),
          _buildScheduleFilters(),
          const SizedBox(height: 18),
          _buildTimeFilter(),
          const SizedBox(height: 14),
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

  Widget _buildScheduleFilters() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
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
        FutureBuilder<List<DoctorSummary>>(
          future: widget.doctorApi.list(),
          builder: (context, snapshot) {
            final doctors = snapshot.data ?? const <DoctorSummary>[];
            return AppDropdown<String?>(
              value: _doctorFilter,
              hint: const Text('Any doctor'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Any doctor'),
                ),
                ...doctors.map(
                  (doctor) => DropdownMenuItem<String?>(
                    value: doctor.userId,
                    child: Text(doctor.fullName),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _doctorFilter = value),
            );
          },
        ),
        if (_dateFilter != null || _doctorFilter != null)
          TextButton(
            onPressed: () => setState(() {
              _dateFilter = null;
              _doctorFilter = null;
            }),
            child: const Text('Clear filters'),
          ),
      ],
    );
  }

  // Uppercase label over a chip row.
  Widget _quietFilterGroup({
    required String label,
    required List<Widget> chips,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall(
            color: AppColors.textMuted,
          ).copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  Widget _buildTimeFilter() {
    return _quietFilterGroup(
      label: 'Time',
      chips: [
        for (final filter in _TimeFilter.values)
          ChoiceChip(
            label: Text(_timeFilterLabel(filter)),
            selected: _timeFilter == filter,
            onSelected: (_) => setState(() => _timeFilter = filter),
            showCheckmark: true,
            selectedColor: AppColors.rose,
            checkmarkColor: Colors.white,
            side: BorderSide(
              color: _timeFilter == filter ? AppColors.rose : AppColors.border,
            ),
            labelStyle: AppTypography.labelMedium(
              color: _timeFilter == filter ? Colors.white : AppColors.textSub,
            ),
          ),
      ],
    );
  }

  String _timeFilterLabel(_TimeFilter filter) {
    return switch (filter) {
      _TimeFilter.all => 'All dates',
      _TimeFilter.past => 'Past',
      _TimeFilter.current => 'Current day',
      _TimeFilter.future => 'Future',
    };
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
    return _quietFilterGroup(
      label: 'Status',
      chips: [
        for (final status in const ['ALL', 'BOOKED', 'CANCELLED'])
          ChoiceChip(
            label: Text(_statusLabel(status)),
            selected: _statusFilter == status,
            onSelected: (_) => setState(() => _statusFilter = status),
            showCheckmark: true,
            selectedColor: AppColors.rose,
            checkmarkColor: Colors.white,
            side: BorderSide(
              color: _statusFilter == status
                  ? AppColors.rose
                  : AppColors.border,
            ),
            labelStyle: AppTypography.labelMedium(
              color: _statusFilter == status ? Colors.white : AppColors.textSub,
            ),
          ),
      ],
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'BOOKED' => 'Booked',
      'CANCELLED' => 'Cancelled',
      _ => 'All statuses',
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
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.spa_outlined, size: 16, color: AppColors.rose),
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
