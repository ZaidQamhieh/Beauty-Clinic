import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../network/api_client.dart';
import '../../appointments/data/appointment.dart';
import '../../appointments/data/appointment_api.dart';
import '../../appointments/presentation/booking_format.dart';
import '../../forms/data/clinical_intake_api.dart';
import '../../forms/data/clinical_intake_schema.dart';

// Survives route disposal; revisit paints at once.
class _DashboardSnapshot {
  const _DashboardSnapshot(this.patient, this.upcoming);

  final Map<String, dynamic> patient;
  final List<Appointment> upcoming;
}

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({
    super.key,
    required this.appointmentApi,
    required this.clinicalApi,
    required this.onOpenProfile,
    required this.onOpenClinicalForm,
    required this.onOpenAppointments,
    required this.onBookTreatment,
    this.refreshSignal,
    this.apiClient,
  });

  final AppointmentApi appointmentApi;
  final ClinicalIntakeApi clinicalApi;

  /// Holds parsed data across route disposal.
  final ApiClient? apiClient;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenClinicalForm;
  final ValueChanged<String> onOpenAppointments;
  final VoidCallback onBookTreatment;

  /// Chatbot wrote; reload without a skeleton.
  final Listenable? refreshSignal;

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  Map<String, dynamic>? _patient;
  List<Appointment> _upcoming = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    widget.refreshSignal?.addListener(_reloadQuietly);
  }

  @override
  void didUpdateWidget(PatientDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_reloadQuietly);
      widget.refreshSignal?.addListener(_reloadQuietly);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_reloadQuietly);
    super.dispose();
  }

  // Swaps data in place, keeping scroll.
  void _reloadQuietly() => _load(quiet: true);

  static const _stateKey = 'patientDashboard';

  Future<void> _load({bool quiet = false}) async {
    // Repaint last result, refresh behind it.
    if (_patient == null) {
      final kept = widget.apiClient?.readViewState<_DashboardSnapshot>(
        _stateKey,
      );
      if (kept != null) {
        _patient = kept.patient;
        _upcoming = kept.upcoming;
      }
    }

    if (!quiet && _patient == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (_loading) {
      setState(() => _loading = false);
    }
    try {
      final results = await Future.wait([
        widget.clinicalApi.fetchOwn(),
        widget.appointmentApi.upcoming(page: 0, size: 10),
      ]);
      final patient = results[0] as Map<String, dynamic>;
      final upcoming = (results[1] as AppointmentPage).items;
      widget.apiClient?.writeViewState(
        _stateKey,
        _DashboardSnapshot(patient, upcoming),
      );
      if (!mounted) return;
      setState(() {
        _patient = patient;
        _upcoming = upcoming;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Silent reload keeps what is shown.
      if (quiet) return;
      setState(() {
        _error = 'Unable to load your dashboard.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SkeletonGrid(itemCount: 4);
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: AppTypography.bodyMedium()),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Try Again')),
          ],
        ),
      );
    }

    final firstName = _patient?['firstName']?.toString() ?? 'there';
    final imageUrl = _patient?['imageUrl']?.toString();
    final skinType = _patient?['skinType']?.toString();
    final formComplete = ClinicalIntakeSchema.isComplete(_patient ?? {});
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.rose,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcome(firstName, imageUrl),
            const SizedBox(height: 16),
            _buildSnapshot(skinType, formComplete),
            const SizedBox(height: 16),
            _buildUpcomingTreatments(),
            const SizedBox(height: 16),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(String firstName, String? imageUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.bgRose, AppColors.bgLavender],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        children: [
          ProfileAvatar(radius: 27, color: AppColors.rose, imageUrl: imageUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $firstName',
                  style: AppTypography.displayTitle(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your care plan, visits, and skin progress in one place.',
                  style: AppTypography.bodySmall(color: AppColors.textSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshot(String? skinType, bool formComplete) {
    return _section(
      title: 'Your Health Snapshot',
      icon: Icons.favorite_outline,
      child: Row(
        children: [
          Expanded(
            child: _snapshotItem(
              'Skin Type',
              skinType == null ? 'Not recorded' : _humanize(skinType),
              Icons.face_retouching_natural,
              AppColors.rose,
              AppColors.rosePale,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _clickable(
              onTap: widget.onOpenClinicalForm,
              child: _snapshotItem(
                'Clinical Form',
                formComplete ? 'Complete' : 'Needs attention',
                formComplete
                    ? Icons.verified_outlined
                    : Icons.assignment_late_outlined,
                formComplete ? AppColors.sage : AppColors.gold,
                formComplete ? AppColors.sagePale : AppColors.goldPale,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _snapshotItem(
              'Upcoming Visits',
              '${_upcoming.length}',
              Icons.calendar_today_outlined,
              AppColors.lav,
              AppColors.lavPale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTreatments() {
    return _section(
      title: 'Upcoming Treatments',
      icon: Icons.auto_awesome_outlined,
      child: _upcoming.isEmpty
          ? _emptyText('Your upcoming treatments will appear here.')
          : Column(
              children: [
                for (final appointment in _upcoming.take(3))
                  for (final session in appointment.plannedSessions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _clickable(
                        onTap: () => widget.onOpenAppointments(appointment.id),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          tileColor: AppColors.bgAlt,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: const Icon(
                            Icons.spa_outlined,
                            color: AppColors.rose,
                          ),
                          title: Text(
                            session.treatmentLabel,
                            style: AppTypography.labelMedium(),
                          ),
                          subtitle: Text(
                            '${BookingFormat.dayWithYear(session.startTime)} · ${BookingFormat.time12(session.startTime)} · ${session.practitionerName}',
                            style: AppTypography.bodySmall(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onOpenProfile,
            icon: const Icon(Icons.person_outline),
            label: const Text('My Medical Profile'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: widget.onBookTreatment,
            icon: const Icon(Icons.add),
            label: const Text('Book Treatment'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
          ),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
              Icon(icon, color: AppColors.rose, size: 20),
              const SizedBox(width: 10),
              Text(title, style: AppTypography.labelLarge()),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _snapshotItem(
    String label,
    String value,
    IconData icon,
    Color color,
    Color chipColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
          const SizedBox(height: 3),
          Text(value, style: AppTypography.labelLarge().copyWith(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _clickable({required VoidCallback onTap, required Widget child}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }

  Widget _emptyText(String text) =>
      Text(text, style: AppTypography.bodySmall(color: AppColors.textMuted));

  String _humanize(String value) => value
      .toLowerCase()
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
