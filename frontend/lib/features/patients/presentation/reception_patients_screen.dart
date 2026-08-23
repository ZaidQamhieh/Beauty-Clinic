import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../network/api_client.dart';
import '../../appointments/data/appointment.dart';
import '../../appointments/data/appointment_api.dart';
import '../../appointments/data/doctor_api.dart';
import '../../appointments/data/treatment_api.dart';
import '../../appointments/presentation/booking_flow_sheet.dart';

class ReceptionPatientsScreen extends StatefulWidget {
  const ReceptionPatientsScreen({
    super.key,
    required this.apiClient,
    required this.appointmentApi,
    required this.treatmentApi,
    required this.doctorApi,
  });

  final ApiClient apiClient;
  final AppointmentApi appointmentApi;
  final TreatmentApi treatmentApi;
  final DoctorApi doctorApi;

  @override
  State<ReceptionPatientsScreen> createState() =>
      _ReceptionPatientsScreenState();
}

class _ReceptionPatientsScreenState extends State<ReceptionPatientsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _patients = const [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

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
      final response = await widget.apiClient.get<Map<String, dynamic>>(
        '/api/patients',
        queryParameters: {
          'q': _searchController.text.trim(),
          'size': 50,
          'sort': 'user.lastName,asc',
        },
      );
      if (!mounted) return;
      setState(() {
        _patients = (response.data?['content'] as List<dynamic>? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final status = error.response?.statusCode;
      setState(() {
        _loading = false;
        _error =
            'Could not load patient directory${status == null ? '' : ' ($status)'}.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load patient directory.';
      });
    }
  }

  Future<void> _bookFor(Map<String, dynamic> patient) async {
    await showDialog<void>(
      context: context,
      builder: (_) => BookingFlowSheet(
        patientUserId: patient['id']?.toString(),
        treatmentApi: widget.treatmentApi,
        appointmentApi: widget.appointmentApi,
        doctorApi: widget.doctorApi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Patients', style: AppTypography.displayTitle()),
          const SizedBox(height: 4),
          Text(
            'Read-only contact and demographic records for front-desk operations.',
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search name, phone, or email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final list = _buildList();
                      final details = _buildDetails();
                      if (constraints.maxWidth < 760) {
                        return ListView(children: [list, details]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 330, child: list),
                          const SizedBox(width: 18),
                          Expanded(child: details),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_patients.isEmpty) {
      return const Center(child: Text('No patients found.'));
    }
    return ListView.separated(
      itemCount: _patients.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final patient = _patients[index];
        return ListTile(
          selected: identical(patient, _selected),
          selectedTileColor: AppColors.bgRose,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.bgLavender,
            child: Text(_initials(patient)),
          ),
          title: Text(_name(patient)),
          subtitle: Text(
            patient['phone']?.toString() ??
                patient['email']?.toString() ??
                'No contact',
          ),
          onTap: () => setState(() => _selected = patient),
        );
      },
    );
  }

  Widget _buildDetails() {
    final patient = _selected;
    if (patient == null) {
      return const Center(
        child: Text('Select a patient to view demographics and appointments.'),
      );
    }
    return Card(
      elevation: 0,
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _name(patient),
                    style: AppTypography.displaySubtitle(),
                  ),
                ),
                IconButton(
                  tooltip: 'Book appointment for patient',
                  onPressed: () => _bookFor(patient),
                  icon: const Icon(Icons.event_available_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _detail('Date of birth', _date(patient['dateOfBirth'])),
                _detail('Gender', _label(patient['gender'])),
                _detail(
                  'Phone',
                  patient['phone']?.toString() ?? 'Not provided',
                ),
                _detail(
                  'Email',
                  patient['email']?.toString() ?? 'Not provided',
                ),
              ],
            ),
            const Divider(height: 32),
            Text('Appointment history', style: AppTypography.labelLarge()),
            const SizedBox(height: 8),
            Expanded(
              child: _AppointmentHistory(
                apiClient: widget.apiClient,
                patientId: patient['id'].toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall(color: AppColors.textMuted),
        ),
        const SizedBox(height: 3),
        Text(value, style: AppTypography.bodyMedium()),
      ],
    ),
  );

  String _name(Map<String, dynamic> patient) =>
      '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim();
  String _initials(Map<String, dynamic> patient) =>
      '${patient['firstName'] ?? ''}${patient['lastName'] ?? ''}'.characters
          .take(2)
          .toString()
          .toUpperCase();
  String _date(dynamic value) => value == null
      ? 'Not provided'
      : DateFormat.yMMMd().format(DateTime.parse(value.toString()));
  String _label(dynamic value) => value == null
      ? 'Not provided'
      : value.toString().split('.').last.toLowerCase();
}

class _AppointmentHistory extends StatelessWidget {
  const _AppointmentHistory({required this.apiClient, required this.patientId});

  final ApiClient apiClient;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Appointment>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text('Appointment history unavailable.');
        }
        final appointments = snapshot.data ?? const <Appointment>[];
        if (appointments.isEmpty) {
          return const Text('No appointments recorded.');
        }
        return ListView.separated(
          itemCount: appointments.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final appointment = appointments[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.event_note_outlined,
                color: AppColors.rose,
              ),
              title: Text(
                DateFormat.yMMMd().add_jm().format(
                  appointment.scheduledAt.toLocal(),
                ),
              ),
              subtitle: Text(
                appointment.status == 'BOOKED' ? 'Booked' : 'Cancelled',
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Appointment>> _load() async {
    final results = await Future.wait([
      apiClient.get<Map<String, dynamic>>(
        '/api/appointments/patients/$patientId/upcoming',
        queryParameters: {'size': 50},
      ),
      apiClient.get<Map<String, dynamic>>(
        '/api/appointments/patients/$patientId/history',
        queryParameters: {'size': 50},
      ),
    ]);
    return [
      ...AppointmentPage.fromJson(results[0].data!).items,
      ...AppointmentPage.fromJson(results[1].data!).items,
    ]..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }
}
