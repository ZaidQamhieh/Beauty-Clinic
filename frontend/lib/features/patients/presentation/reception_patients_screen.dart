import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../network/api_client.dart';
import '../../appointments/data/appointment.dart';
import '../../appointments/data/appointment_api.dart';
import '../../appointments/data/doctor_api.dart';
import '../../appointments/data/treatment_api.dart';
import '../../appointments/presentation/booking_flow_sheet.dart';

/// Front-desk patient directory; demographics only.
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
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _loadGeneration = 0;
  List<Map<String, dynamic>> _patients = const [];
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
    _searchDebounce?.cancel();
    super.dispose();
  }

  // Reception reads /api/patients, never the clinical list.
  Future<void> _load([String query = '']) async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.apiClient.get<Map<String, dynamic>>(
        '/api/patients',
        queryParameters: {'q': query, 'size': 50, 'sort': 'user.lastName,asc'},
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _patients = (response.data?['content'] as List<dynamic>? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      final status = error.response?.statusCode;
      setState(() {
        _loading = false;
        _error =
            'Could not load the patient directory${status == null ? '' : ' ($status)'}.';
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the patient directory.';
      });
    }
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(_searchController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(),
          const SizedBox(height: 24),
          _buildSearchBar(),
          const SizedBox(height: 20),
          if (_loading)
            const SizedBox(height: 420, child: SkeletonList())
          else if (_error != null)
            _buildErrorState()
          else if (_patients.isEmpty)
            _buildEmptyState()
          else
            _buildPatientsGrid(),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: AppColors.rose,
              size: 28,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('Patients', style: AppTypography.displayTitle())],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.folder_shared_outlined,
                  size: 16,
                  color: AppColors.rose,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_patients.length} Patients',
                  style: AppTypography.labelLarge(color: AppColors.roseDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: AppSearchField(
            hintText: 'Search by patient name, email, or phone number...',
            controller: _searchController,
            onSubmitted: (query) => _load(query.trim()),
            onChanged: (value) {
              _scheduleSearch();
              setState(() {});
            },
            onClear: () {
              _searchController.clear();
              _load();
            },
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _load(_searchController.text.trim()),
          icon: const Icon(Icons.search, size: 18),
          label: const Text('Search'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.rose,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1000
            ? 3
            : constraints.maxWidth > 650
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 180,
          ),
          itemCount: _patients.length,
          itemBuilder: (_, index) => _buildPatientCard(_patients[index]),
        );
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final fullName = _name(patient);
    final email = patient['email']?.toString() ?? 'No email';
    final phone = patient['phone']?.toString() ?? 'No phone';
    final gender = _label(patient['gender']);
    final age = _age(patient['dateOfBirth']);

    return Material(
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openPatientSheet(patient),
        hoverColor: AppColors.bgRose.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.bgRose,
                    child: Text(
                      _initials(patient),
                      style: AppTypography.labelLarge(
                        color: AppColors.roseDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isEmpty ? 'Unnamed Patient' : fullName,
                          style: AppTypography.displaySubtitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          email,
                          style: AppTypography.bodySmall(
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      phone,
                      style: AppTypography.bodySmall(color: AppColors.textSub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (age != null)
                    _badge(age, AppColors.bgLavender, AppColors.lavDark),
                  if (gender != null)
                    _badge(gender, AppColors.bgSage, AppColors.sageDark),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _bookFor(patient),
                    icon: const Icon(Icons.event_available_outlined, size: 15),
                    label: const Text('Book'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.roseDark,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View details',
                        style: AppTypography.labelSmall(
                          color: AppColors.rose,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.rose,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(
          color: foreground,
        ).copyWith(fontSize: 10),
      ),
    );
  }

  Future<void> _openPatientSheet(Map<String, dynamic> patient) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.bgRose,
              child: Text(
                _initials(patient),
                style: AppTypography.labelLarge(color: AppColors.roseDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _name(patient),
                style: AppTypography.displaySubtitle(),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 18,
                runSpacing: 12,
                children: [
                  _detail('Date of birth', _date(patient['dateOfBirth'])),
                  _detail(
                    'Gender',
                    _label(patient['gender']) ?? 'Not provided',
                  ),
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
              const Divider(height: 28),
              Text('Appointment history', style: AppTypography.labelLarge()),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: _AppointmentHistory(
                  apiClient: widget.apiClient,
                  patientId: patient['id'].toString(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _bookFor(patient);
            },
            icon: const Icon(Icons.event_available_outlined, size: 16),
            label: const Text('Book appointment'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
          ),
        ],
      ),
    );
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

  Widget _detail(String label, String value) => SizedBox(
    width: 210,
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

  Widget _buildEmptyState() {
    return _stateCard(
      Icons.person_search_outlined,
      'No patients found.',
      'Try a different name, phone number, or email.',
    );
  }

  Widget _buildErrorState() {
    return _stateCard(
      Icons.error_outline,
      _error ?? 'Something went wrong.',
      'Check the connection and try again.',
      action: FilledButton(
        onPressed: () => _load(_searchController.text.trim()),
        style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
        child: const Text('Retry'),
      ),
    );
  }

  Widget _stateCard(
    IconData icon,
    String title,
    String subtitle, {
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(title, style: AppTypography.labelLarge()),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }

  String _name(Map<String, dynamic> patient) =>
      '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim();

  String _initials(Map<String, dynamic> patient) {
    final first = patient['firstName']?.toString() ?? '';
    final last = patient['lastName']?.toString() ?? '';
    final initials =
        (first.isNotEmpty ? first[0] : '') + (last.isNotEmpty ? last[0] : '');
    return initials.isEmpty ? '?' : initials.toUpperCase();
  }

  String _date(dynamic value) => value == null
      ? 'Not provided'
      : DateFormat.yMMMd().format(DateTime.parse(value.toString()));

  String? _age(dynamic value) {
    if (value == null) return null;
    final born = DateTime.tryParse(value.toString());
    if (born == null) return null;
    final now = DateTime.now();
    var years = now.year - born.year;
    if (now.month < born.month ||
        (now.month == born.month && now.day < born.day)) {
      years--;
    }
    return years < 0 ? null : '$years years';
  }

  String? _label(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().split('.').last.toLowerCase();
    if (raw.isEmpty) return null;
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }
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
          return const Column(
            children: [
              SkeletonListTile(),
              SkeletonListTile(),
              SkeletonListTile(),
            ],
          );
        }
        if (snapshot.hasError) {
          return Text(
            'Appointment history unavailable.',
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          );
        }
        final appointments = snapshot.data ?? const <Appointment>[];
        if (appointments.isEmpty) {
          return Text(
            'No appointments recorded.',
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          );
        }
        return ListView.separated(
          itemCount: appointments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final appointment = appointments[index];
            final cancelled = appointment.status == 'CANCELLED';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_note_outlined,
                    size: 17,
                    color: AppColors.rose,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMd().add_jm().format(
                        appointment.scheduledAt.toLocal(),
                      ),
                      style: AppTypography.labelMedium(),
                    ),
                  ),
                  Text(
                    cancelled ? 'Cancelled' : 'Booked',
                    style: AppTypography.labelSmall(
                      color: cancelled
                          ? AppColors.textMuted
                          : AppColors.sageDark,
                    ),
                  ),
                ],
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
