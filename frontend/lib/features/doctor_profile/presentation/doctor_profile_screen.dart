import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:beauty_clinic_app/core/widgets/profile_avatar.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../network/api_client.dart';
import '../../appointments/data/appointment_api.dart';
import '../../appointments/data/enum_label.dart';
import '../../dashboard/data/doctor_dashboard_models.dart';
import '../../dashboard/presentation/widgets/admin_analytics_charts.dart';
import '../../doctor_availability/data/doctor_availability_api.dart';
import '../../doctor_availability/presentation/doctor_availability_screen.dart';
import '../../doctor_availability/presentation/widgets/availability_sessions_view.dart';
import '../data/doctor_detail_api.dart';

/// Admin doctor detail: overview, booked-session calendar (view-only records),
/// the doctor's availability schedule, and statistics.
class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({
    super.key,
    required this.doctorId,
    required this.apiClient,
    required this.appointmentApi,
    required this.availabilityApi,
    this.onBack,
  });

  final String doctorId;
  final ApiClient apiClient;
  final AppointmentApi appointmentApi;
  final DoctorAvailabilityApi availabilityApi;
  final VoidCallback? onBack;

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final DoctorDetailApi _detailApi;
  late Future<DoctorAccountDetail> _accountFuture;
  late Future<DoctorLiveStatus> _liveStatusFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _detailApi = DoctorDetailApi(widget.apiClient);
    _accountFuture = _detailApi.fetchAccount(widget.doctorId);
    _liveStatusFuture = _detailApi.fetchLiveStatus(widget.doctorId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onBack != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Staff Management'),
              ),
            ),

          FutureBuilder<DoctorAccountDetail>(
            future: _accountFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SkeletonDetail(scrollable: false);
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _ErrorCard(
                  message:
                      "Unable to load this doctor's profile.\n${snapshot.error ?? ''}",
                );
              }
              return _buildDoctorHeaderCard(snapshot.data!);
            },
          ),

          const SizedBox(height: 24),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.rose,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.rose,
            labelStyle: AppTypography.labelMedium(),
            unselectedLabelStyle: AppTypography.labelMedium(),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: "Doctor's Calendar"),
              Tab(text: 'Availability'),
              Tab(text: 'Statistics'),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 700,
            child: TabBarView(
              controller: _tabController,
              children: [
                FutureBuilder<DoctorAccountDetail>(
                  future: _accountFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SkeletonDetail();
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return _ErrorCard(
                        message:
                            'Unable to load overview.\n${snapshot.error ?? ''}',
                      );
                    }
                    return _OverviewTab(account: snapshot.data!);
                  },
                ),
                AvailabilitySessionsView(
                  fetchSessions: (date) =>
                      widget.appointmentApi.scheduleFor(widget.doctorId, date),
                  fetchAvailability: () =>
                      widget.availabilityApi.listForDoctor(widget.doctorId),
                  // apiClient alone (no appointmentApi): admin can view an
                  // existing session record or learn there isn't one yet,
                  // but not mark attended or create/edit one.
                  apiClient: widget.apiClient,
                ),
                DoctorAvailabilityScreen(
                  api: widget.availabilityApi,
                  doctorId: widget.doctorId,
                ),
                _StatisticsTab(
                  doctorId: widget.doctorId,
                  detailApi: _detailApi,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorHeaderCard(DoctorAccountDetail account) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.rose, width: 2),
            ),
            child: ProfileAvatar(
              imageUrl: account.imageUrl,
              color: AppColors.rose,
              radius: 40,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. ${account.fullName}',
                          style: AppTypography.displayTitle(),
                        ),
                        Text(
                          account.specializations.isEmpty
                              ? 'Doctor'
                              : account.specializations
                                    .map(humanizeEnum)
                                    .join(' · '),
                          style: AppTypography.bodyMedium(
                            color: AppColors.rose,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusPill(status: _accountStatusLabel(account.status)),
                        const SizedBox(height: 6),
                        FutureBuilder<DoctorLiveStatus>(
                          future: _liveStatusFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                    ConnectionState.done ||
                                !snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            return StatusPill(status: snapshot.data!.status);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      color: AppColors.lav,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      account.yearsOfExperience == null
                          ? 'Experience not on file'
                          : '${account.yearsOfExperience}+ Yrs Exp',
                      style: AppTypography.labelLarge(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _accountStatusLabel(String status) {
  return switch (status) {
    'ACTIVE' => 'Active',
    'DEACTIVATED' => 'Deactivated',
    _ => status,
  };
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

// OVERVIEW TAB

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.account});

  final DoctorAccountDetail account;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _sectionCard(
          title: 'Contact Information',
          children: [
            _infoRow(
              Icons.email_outlined,
              'Email',
              account.email.isEmpty ? '—' : account.email,
            ),
            _infoRow(
              Icons.phone_outlined,
              'Phone',
              account.phone.isEmpty ? '—' : account.phone,
            ),
            _infoRow(
              Icons.cake_outlined,
              'Date of Birth',
              account.dateOfBirth == null
                  ? '—'
                  : DateFormat('d MMM yyyy').format(account.dateOfBirth!),
            ),
            _infoRow(
              Icons.wc_outlined,
              'Gender',
              account.gender.isEmpty ? '—' : humanizeEnum(account.gender),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Professional Details',
          children: [
            _infoRow(
              Icons.workspace_premium_outlined,
              'Years of Experience',
              account.yearsOfExperience == null
                  ? '—'
                  : '${account.yearsOfExperience} yrs',
            ),
            const SizedBox(height: 16),
            Text('Specializations', style: AppTypography.labelMedium()),
            const SizedBox(height: 8),
            account.specializations.isEmpty
                ? Text(
                    'No specializations on file.',
                    style: AppTypography.bodySmall(),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: account.specializations
                        .map(
                          (spec) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgRose,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              humanizeEnum(spec),
                              style: AppTypography.labelSmall(
                                color: AppColors.roseDark,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.labelLarge()),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: Text(label, style: AppTypography.bodySmall()),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyMedium())),
        ],
      ),
    );
  }
}

// STATISTICS TAB

class _StatisticsTab extends StatefulWidget {
  const _StatisticsTab({required this.doctorId, required this.detailApi});

  final String doctorId;
  final DoctorDetailApi detailApi;

  @override
  State<_StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<_StatisticsTab> {
  late final Future<DoctorDashboardData> _statsFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _statsFuture = widget.detailApi.fetchStatistics(
      widget.doctorId,
      from: now.subtract(const Duration(days: 30)),
      to: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DoctorDashboardData>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SkeletonGrid(itemCount: 4);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorCard(
            message: 'Unable to load statistics.\n${snapshot.error ?? ''}',
          );
        }

        final data = snapshot.data!;
        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    title: 'Active Patients',
                    value: '${data.activePatientsCount}',
                    icon: Icons.groups_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _InfoTile(
                    title: 'Patients Today',
                    value: '${data.todayPatientsCount}',
                    icon: Icons.today_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 700;
                return Flex(
                  direction: isDesktop ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isDesktop ? 1 : 0,
                      child: AppointmentOutcomesDonut(
                        data: data.appointmentOutcomes,
                      ),
                    ),
                    if (isDesktop)
                      const SizedBox(width: 20)
                    else
                      const SizedBox(height: 20),
                    Expanded(
                      flex: isDesktop ? 1 : 0,
                      child: PatientGrowthLineChart(
                        data: data.appointmentsOverTime,
                        title: 'Completed Sessions Over Time',
                        subtitle:
                            'Completed patient consultations per period, over the last 30 days',
                        badgeText: 'Completed only',
                        badgeColor: AppColors.sage,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            ServiceBookingsBarChart(
              data: data.treatmentsPerformed,
              showTopService: false,
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.rose, size: 24),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.displayStat()),
          Text(title, style: AppTypography.bodySmall()),
        ],
      ),
    );
  }
}
