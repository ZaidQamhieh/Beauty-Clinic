import 'package:flutter/foundation.dart';
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
import '../../products/data/product.dart';
import '../../products/data/product_api.dart';
import '../../patients/presentation/patient_picker.dart';
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
  static const double _wideBreakpoint = 900;

  String _statusFilter = 'ALL';
  DateTime? _dateFilter;
  String _query = '';
  String? _selectedId;
  List<Appointment> _appointments = const [];
  bool _loading = true;
  String? _error;
  Map<String, SessionRecord> _recordsBySession = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
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
    try {
      final products = await ProductApi(widget.apiClient).list();
      if (!mounted) return;
      final input = await showDialog<_SessionRecordInput>(
        context: context,
        builder: (_) =>
            _SessionRecordDialog(session: session, catalog: products),
      );
      if (input == null) return;
      if (session.isPlanned) {
        await widget.appointmentApi.markAttended(appointment.id, session.id);
      }
      await SessionRecordApi(widget.apiClient).create(
        patientId: appointment.patientUserId,
        sessionId: session.id,
        note: input.note,
        skinReaction: input.skinReaction,
        followUpDate: input.followUpDate,
        prescribedProductIds: input.prescribedProductIds,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session completed and record saved.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not complete the session.')),
      );
    }
  }

  void _viewSessionRecord(SessionRecord record) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Session record · ${record.createdAt.toLocal().toIso8601String().split('T').first}',
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (record.note == null || record.note!.trim().isEmpty)
                    ? 'No clinical note added.'
                    : record.note!,
              ),
              const SizedBox(height: 12),
              Text('Skin reaction: ${record.skinReaction ?? 'Not recorded'}'),
              if (record.followUpDate != null)
                Text('Follow-up: ${record.followUpDate}'),
              Text(
                'Prescribed products: ${record.prescribedProductIds.length}',
              ),
            ],
          ),
        ),
        actions: [
          if (widget.canAuthorSessionRecords)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _editSessionRecord(record);
              },
              child: const Text('Edit'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editSessionRecord(SessionRecord record) async {
    try {
      final products = await ProductApi(widget.apiClient).list();
      if (!mounted) return;
      final input = await showDialog<_SessionRecordInput>(
        context: context,
        builder: (_) => _SessionRecordDialog(
          session: _appointments
              .expand((appointment) => appointment.sessions)
              .firstWhere((session) => session.id == record.sessionId),
          catalog: products,
          initial: record,
        ),
      );
      if (input == null) return;
      await SessionRecordApi(widget.apiClient).amend(
        patientId: _appointments
            .firstWhere(
              (appointment) => appointment.sessions.any(
                (session) => session.id == record.sessionId,
              ),
            )
            .patientUserId,
        recordId: record.id,
        note: input.note,
        skinReaction: input.skinReaction,
        followUpDate: input.followUpDate,
        prescribedProductIds: input.prescribedProductIds,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not edit the session record.')),
        );
      }
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
      return matchesStatus && matchesDate && _matchesQuery(appointment);
    }).toList();
    sorted.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
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

  // Counts every appointment, not the filtered list.
  ({int upcoming, int completed, int cancelled}) get _counts {
    final now = DateTime.now();
    var upcoming = 0;
    var cancelled = 0;
    var completed = 0;
    for (final appointment in _appointments) {
      if (appointment.status == 'CANCELLED') {
        cancelled++;
      } else if (appointment.sessions.any(
        (session) =>
            session.status == 'PLANNED' && !session.startTime.isBefore(now),
      )) {
        upcoming++;
      }
      completed += appointment.sessions
          .where((session) => session.status == 'COMPLETED')
          .length;
    }
    return (upcoming: upcoming, completed: completed, cancelled: cancelled);
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
              Expanded(child: _buildWorkspace(appointments, wide)),
            ],
          ),
        );
      },
    );
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
        Expanded(child: list),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
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
                const SizedBox(height: 4),
                Text(
                  widget.canAuthorSessionRecords
                      ? 'Your assigned consultations and clinical follow-up.'
                      : 'Clinic schedule and patient visits.',
                  style: AppTypography.bodySmall(color: AppColors.textSub),
                ),
                const SizedBox(height: 8),
                _buildHeaderCounts(),
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

  Widget _buildHeaderCounts() {
    final counts = _counts;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _countChip('${counts.upcoming} upcoming', AppColors.gold),
        _countChip('${counts.completed} completed', AppColors.sage),
        _countChip('${counts.cancelled} cancelled', AppColors.textMuted),
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
          const statuses = ['ALL', 'BOOKED', 'CANCELLED', 'FINISHED'];
          if (constraints.maxWidth < 720) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: constraints.maxWidth,
                  child: _buildSearchField(),
                ),
                _buildDateFilterButton(),
                for (final status in statuses) _statusChoiceChip(status),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: _buildSearchField()),
              const SizedBox(width: 10),
              _buildDateFilterButton(),
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
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
      style: AppTypography.bodyMedium(),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.bgAlt,
        hintText: 'Search patient or treatment',
        hintStyle: AppTypography.bodySmall(color: AppColors.textMuted),
        prefixIcon: const Icon(
          Icons.search,
          size: 18,
          color: AppColors.textMuted,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: AppColors.textMuted,
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDateFilterButton() {
    final label = _dateFilter == null
        ? 'Any date'
        : DateFormat('d MMM yyyy').format(_dateFilter!);
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: _dateFilter ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (selected != null) setState(() => _dateFilter = selected);
      },
      onLongPress: _dateFilter == null
          ? null
          : () => setState(() => _dateFilter = null),
      icon: Icon(
        _dateFilter == null
            ? Icons.calendar_today_outlined
            : Icons.event_available_outlined,
        size: 16,
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _dateFilter == null
            ? AppColors.textSub
            : AppColors.roseDark,
        side: BorderSide(
          color: _dateFilter == null ? AppColors.border : AppColors.borderRose,
        ),
        shape: const StadiumBorder(),
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

  void _selectAppointment(Appointment appointment, bool wide) {
    if (wide) {
      setState(() => _selectedId = appointment.id);
      return;
    }
    setState(() => _selectedId = appointment.id);
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
      child: _buildDetailBody(appointment, boxed: true),
    );
  }

  // Panel never scrolls; overflow opens a dialog.
  Widget _buildDetailBody(Appointment appointment, {required bool boxed}) {
    final sessions = appointment.sessions;
    final shown = sessions.take(boxed ? 3 : sessions.length).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: boxed ? MainAxisSize.max : MainAxisSize.min,
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
            const SizedBox(width: 8),
            _statusPill(appointment),
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
        if (boxed) const Spacer(),
        const SizedBox(height: 16),
        _buildActionStrip(appointment),
      ],
    );
  }

  // The state sentence carries its own remedy.
  Widget _buildActionStrip(Appointment appointment) {
    final modifiable = _canModify(appointment);
    final message = switch (appointment.status) {
      'CANCELLED' => 'This visit was cancelled.',
      _ when modifiable => 'Booked and still upcoming.',
      _ => 'This visit has already happened.',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall(color: AppColors.roseDark),
            ),
          ),
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
          FilledButton.icon(
            onPressed: modifiable
                ? () => _openBooking(appointment: appointment)
                : () => _bookFollowUp(appointment),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(modifiable ? 'Reschedule' : 'Book follow-up'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rose,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildSessionRow(Appointment appointment, AppointmentSession session) {
    final record = _recordsBySession[session.id];
    final canRecord =
        widget.canAuthorSessionRecords &&
        session.status != 'CANCELLED' &&
        session.status != 'NO_SHOW' &&
        (widget.doctorUserId == null ||
            session.practitionerUserId == widget.doctorUserId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.spa_outlined, size: 16, color: AppColors.rose),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.treatmentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium(),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('HH:mm').format(session.startTime.toLocal())} · ${session.practitionerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (canRecord) ...[
            const SizedBox(width: 8),
            TextButton.icon(
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
                    : session.status == 'COMPLETED'
                    ? Icons.note_add_outlined
                    : Icons.check_circle_outline,
                size: 16,
              ),
              label: Text(
                record != null
                    ? 'Record'
                    : session.status == 'COMPLETED'
                    ? 'Add record'
                    : 'Attended',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAllSessions(Appointment appointment) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appointment.patientName),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final session in appointment.sessions)
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
    final (label, color) = switch (appointment) {
      _ when appointment.status == 'CANCELLED' => ('Cancelled', AppColors.rose),
      _
          when appointment.sessions.isNotEmpty &&
              appointment.sessions.every(
                (session) => session.status == 'COMPLETED',
              ) =>
        ('Finished', AppColors.lavDark),
      _ => ('Booked', AppColors.sage),
    };
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

class _SessionRecordInput {
  const _SessionRecordInput({
    required this.note,
    required this.skinReaction,
    required this.followUpDate,
    required this.prescribedProductIds,
  });

  final String? note;
  final String? skinReaction;
  final String? followUpDate;
  final List<String> prescribedProductIds;
}

class _SessionRecordDialog extends StatefulWidget {
  const _SessionRecordDialog({
    required this.session,
    required this.catalog,
    this.initial,
  });

  final AppointmentSession session;
  final List<Product> catalog;
  final SessionRecord? initial;

  @override
  State<_SessionRecordDialog> createState() => _SessionRecordDialogState();
}

class _SessionRecordDialogState extends State<_SessionRecordDialog> {
  late final TextEditingController _note;
  late final Set<String> _products;
  late String _reaction;
  DateTime? _followUp;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _note = TextEditingController(text: initial?.note ?? '');
    _products = {...?initial?.prescribedProductIds};
    _reaction = initial?.skinReaction ?? 'NONE';
    _followUp = initial?.followUpDate == null
        ? null
        : DateTime.tryParse(initial!.followUpDate!);
    _initialSnapshot = _snapshot();
  }

  late List<Object?> _initialSnapshot;

  List<Object?> _snapshot() => [
    _note.text,
    _reaction,
    _followUp,
    ..._products.toList()..sort(),
  ];

  bool get _isDirty => !listEquals(_snapshot(), _initialSnapshot);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    // A past follow-up would break the picker.
    final start = _followUp == null || _followUp!.isBefore(now)
        ? now
        : _followUp!;
    final date = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date != null) setState(() => _followUp = date);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Session record · ${widget.session.treatmentLabel}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _note,
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Clinical note',
                  alignLabelWithHint: true,
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _reaction,
                decoration: const InputDecoration(labelText: 'Skin reaction'),
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text('None')),
                  DropdownMenuItem(value: 'MILD', child: Text('Mild')),
                  DropdownMenuItem(value: 'MODERATE', child: Text('Moderate')),
                  DropdownMenuItem(value: 'SEVERE', child: Text('Severe')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _reaction = value);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  _followUp == null
                      ? 'Add follow-up date'
                      : 'Follow-up: ${_followUp!.toIso8601String().split('T').first}',
                ),
              ),
              const SizedBox(height: 12),
              Text('Prescribe products', style: AppTypography.labelLarge()),
              ...widget.catalog.map(
                (product) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _products.contains(product.id),
                  title: Text('${product.brandLabel} ${product.typeLabel}'),
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      _products.add(product.id);
                    } else {
                      _products.remove(product.id);
                    }
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _note,
          builder: (context, _) => FilledButton(
            onPressed: !_isDirty
                ? null
                : () => Navigator.of(context).pop(
                    _SessionRecordInput(
                      note: _note.text.trim().isEmpty
                          ? null
                          : _note.text.trim(),
                      skinReaction: _reaction,
                      followUpDate: _followUp
                          ?.toIso8601String()
                          .split('T')
                          .first,
                      prescribedProductIds: _products.toList(),
                    ),
                  ),
            child: const Text('Save session record'),
          ),
        ),
      ],
    );
  }
}
