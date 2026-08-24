import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../network/api_client.dart';
import '../../appointments/data/appointment.dart';
import '../data/admin_analytics_models.dart';
import '../data/doctor_dashboard_models.dart';
import 'widgets/admin_analytics_charts.dart';
import 'widgets/admin_date_filter_bar.dart';

/// Dashboard shared by staff roles and patients.
class DashboardScreen extends StatefulWidget {
  final String activeRole;
  final ValueChanged<String> onViewPatient;
  final ValueChanged<String> onViewDoctor;
  final ApiClient? apiClient;
  final VoidCallback? onBookAppointment;
  final VoidCallback? onCheckInPatient;
  final VoidCallback? onViewDoctors;

  const DashboardScreen({
    super.key,
    required this.activeRole,
    required this.onViewPatient,
    required this.onViewDoctor,
    this.apiClient,
    this.onBookAppointment,
    this.onCheckInPatient,
    this.onViewDoctors,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Admin Dashboard Date Filter State
  AdminDateRangeType _adminDateRange = AdminDateRangeType.days30;
  DateTimeRange? _customDateRange;
  AdminDateRangeType _doctorDateRange = AdminDateRangeType.days30;
  DateTimeRange? _doctorCustomDateRange;
  AdminDashboardData? _adminDashboardData;
  DoctorDashboardData? _doctorDashboardData;
  bool _isLoadingAnalytics = false;
  late Future<List<Appointment>> _receptionAppointments;
  late Future<int> _receptionDoctorCount;
  String _receptionStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    if (widget.activeRole == 'admin') {
      _loadAnalytics();
    } else if (widget.activeRole == 'doctor') {
      _loadDoctorAnalytics();
    } else if (widget.activeRole == 'receptionist') {
      _receptionAppointments = _loadReceptionAppointments();
      _receptionDoctorCount = _loadReceptionDoctorCount();
    }
  }

  Future<List<Appointment>> _loadReceptionAppointments() async {
    final response = await widget.apiClient!.get<Map<String, dynamic>>(
      '/api/appointments/all',
      queryParameters: {'page': 0, 'size': 100},
    );
    return AppointmentPage.fromJson(response.data!).items;
  }

  Future<int> _loadReceptionDoctorCount() async {
    final response = await widget.apiClient!.get<List<dynamic>>('/api/doctors');
    return response.data?.length ?? 0;
  }

  Future<void> _loadDoctorAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    try {
      final data = await DoctorDashboardRepository.fetchDashboardData(
        widget.apiClient,
        rangeType: _doctorDateRange,
        customRange: _doctorCustomDateRange,
      );
      if (!mounted) return;
      setState(() {
        _doctorDashboardData = data;
        _isLoadingAnalytics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAnalytics = false);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    final data = await AdminAnalyticsRepository.fetchDashboardDataAsync(
      rangeType: _adminDateRange,
      customRange: _customDateRange,
      apiClient: widget.apiClient,
    );
    if (!mounted) return;
    setState(() {
      _adminDashboardData = data;
      _isLoadingAnalytics = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Welcome Banner
          _buildWelcomeBanner(),

          const SizedBox(height: 24),

          // Render view based on role
          switch (widget.activeRole) {
            'doctor' => _buildDoctorDashboard(),
            'receptionist' => _buildReceptionistDashboard(),
            'patient' => _buildPatientDashboard(),
            _ => _buildAdminDashboard(),
          },
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    final Map<String, String> titles = {
      'admin': 'Overview Dashboard',
      'doctor': 'Dashboard',
      'receptionist': 'Receptionist Dashboard',
      'patient': 'My Health & Beauty Portal',
    };

    final Map<String, String> subtitles = {
      'admin': 'Real-time clinic analytics, appointments, and operations.',
      'doctor':
          'Your clinical workspace — appointments, analytics, and patient care.',
      'receptionist':
          'Daily operations, appointments, patients, and practitioner schedules.',
      'patient':
          'View upcoming appointments, treatment history, and skin progress.',
    };

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.bgRose, AppColors.bgLavender],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderRose.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.rose.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.rose.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.rose,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[widget.activeRole] ?? 'Clinic Dashboard',
                  style: AppTypography.displaySubtitle(
                    color: AppColors.text,
                  ).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitles[widget.activeRole] ??
                      'Welcome to Yasmine Beauty Clinic',
                  style: AppTypography.bodySmall(color: AppColors.textSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Admin dashboard.
  Widget _buildAdminDashboard() {
    final adminData =
        _adminDashboardData ??
        AdminAnalyticsRepository.fetchDashboardData(
          rangeType: _adminDateRange,
          customRange: _customDateRange,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. DATE RANGE FILTER BAR
        AdminDateFilterBar(
          selectedRangeType: _adminDateRange,
          customDateRange: _customDateRange,
          formattedRange: adminData.formattedDateRange,
          onRangeSelected: (type, customRange) {
            setState(() {
              _adminDateRange = type;
              _customDateRange = customRange;
            });
            _loadAnalytics();
          },
        ),

        if (_isLoadingAnalytics) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(
            color: AppColors.rose,
            backgroundColor: AppColors.bgRose,
            minHeight: 2,
          ),
        ],

        const SizedBox(height: 28),

        // 2. CLINIC OVERVIEW SECTION
        _buildSectionHeader(
          title: 'Clinic Overview',
          subtitle: 'Key clinic performance indicators and real-time activity',
          icon: Icons.dashboard_outlined,
          color: AppColors.rose,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final int crossAxisCount = constraints.maxWidth > 900
                ? 4
                : (constraints.maxWidth > 500 ? 2 : 1);
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: constraints.maxWidth > 900 ? 1.6 : 2.1,
              children: [
                _StatCard(
                  label: "Total Patients",
                  value: NumberFormat(
                    '#,###',
                  ).format(adminData.overview.totalPatients),
                  sub: adminData.overview.patientTrendSub,
                  icon: Icons.people_outline,
                  color: AppColors.rose,
                  trend: adminData.overview.patientTrend,
                ),
                _StatCard(
                  label: "Total Doctors",
                  value: "${adminData.overview.totalDoctors}",
                  sub: adminData.overview.doctorSub,
                  icon: Icons.medical_services_outlined,
                  color: AppColors.sage,
                  trend: "${adminData.overview.activeDoctorsNow} Active",
                ),
                _StatCard(
                  label: "Today's Appointments",
                  value: "${adminData.overview.todayAppointments}",
                  sub:
                      "${adminData.overview.confirmedAppointments} confirmed · ${adminData.overview.inRoomAppointments} in room",
                  icon: Icons.calendar_today_outlined,
                  color: AppColors.lav,
                  trend: "+${adminData.overview.pendingAppointments} new",
                ),
                _StatCard(
                  label: "Today's Sessions",
                  value: "${adminData.overview.todaySessions}",
                  sub:
                      "${adminData.overview.completedSessions} completed · ${adminData.overview.ongoingSessions} ongoing",
                  icon: Icons.spa_outlined,
                  color: AppColors.gold,
                  trend:
                      "${adminData.overview.completedSessions}/${adminData.overview.todaySessions}",
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 36),

        // 3. SERVICE ANALYTICS SECTION
        _buildSectionHeader(
          title: 'Service Analytics',
          subtitle:
              'Treatment popularity, procedure breakdown, and growth trajectory',
          icon: Icons.spa_outlined,
          color: AppColors.roseDark,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 960;
            return Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: ServiceBookingsBarChart(
                    data: adminData.serviceAnalytics,
                  ),
                ),
                if (isDesktop)
                  const SizedBox(width: 20)
                else
                  const SizedBox(height: 20),
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: ServiceGrowthLineChart(
                    data: adminData.serviceAnalytics,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 36),

        // 4. DOCTOR ANALYTICS SECTION
        _buildSectionHeader(
          title: 'Doctor Analytics',
          subtitle: 'Practitioner capacity utilization and schedule occupancy',
          icon: Icons.medical_services_outlined,
          color: AppColors.lavDark,
        ),
        const SizedBox(height: 16),
        DoctorUtilizationChart(data: adminData.doctorAnalytics),

        const SizedBox(height: 36),

        // 5. APPOINTMENT ANALYTICS SECTION
        _buildSectionHeader(
          title: 'Appointment Analytics',
          subtitle: 'Fulfillment outcomes, peak times, and reschedule reasons',
          icon: Icons.event_note_outlined,
          color: AppColors.sageDark,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 960;
            return Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: AppointmentOutcomesDonut(
                    data: adminData.appointmentAnalytics.outcomes,
                  ),
                ),
                if (isDesktop)
                  const SizedBox(width: 20)
                else
                  const SizedBox(height: 20),
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: PeakTimesAndRescheduledWidget(
                    data: adminData.appointmentAnalytics,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 36),

        // 6. PATIENT ANALYTICS SECTION
        _buildSectionHeader(
          title: 'Patient Analytics',
          subtitle: 'Acquisition ratio and database growth curve',
          icon: Icons.people_alt_outlined,
          color: AppColors.gold,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 960;
            return Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: NewVsReturningDonut(
                    data: adminData.patientAnalytics.newVsReturning,
                  ),
                ),
                if (isDesktop)
                  const SizedBox(width: 20)
                else
                  const SizedBox(height: 20),
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: PatientGrowthLineChart(
                    data: adminData.patientAnalytics.growthTimeline,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 36),

        // 7. DAILY LIVE OPERATIONS & STAFF SCHEDULE
        _buildSectionHeader(
          title: 'Live Clinic Operations',
          subtitle: 'Today\'s active patient queue and staff duty list',
          icon: Icons.access_time_filled_outlined,
          color: AppColors.text,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 900;
            return Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Today's Appointments List
                Expanded(
                  flex: isDesktop ? 2 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Today\'s Appointments',
                              style: AppTypography.labelLarge(),
                            ),
                            Text(
                              '${adminData.operations.todayAppointments.length} Scheduled',
                              style: AppTypography.bodySmall(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (adminData.operations.todayAppointments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No appointments scheduled for today.',
                                style: AppTypography.bodySmall(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          )
                        else
                          ...adminData.operations.todayAppointments.map(
                            (appt) => _buildAppointmentRow(
                              time: appt.time,
                              patient: appt.patientName,
                              patientId: appt.patientId,
                              treatment: appt.treatmentName,
                              doctor: appt.doctorName,
                              status: appt.status,
                              isClickable: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                if (isDesktop)
                  const SizedBox(width: 20)
                else
                  const SizedBox(height: 20),

                // Staff On Duty
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Staff Today',
                              style: AppTypography.labelLarge(),
                            ),
                            const SizedBox(height: 16),
                            if (adminData.operations.staffList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    'No specialists registered yet.',
                                    style: AppTypography.bodySmall(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...adminData.operations.staffList.map(
                                (staff) => _buildStaffTile(
                                  staff.name,
                                  staff.role,
                                  '${staff.appointmentsCount} appts',
                                  staff.status,
                                  isDoctor: staff.isDoctor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.displaySubtitle(
                  color: AppColors.text,
                ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: AppTypography.bodySmall(
                  color: AppColors.textMuted,
                ).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Doctor dashboard.
  Widget _buildDoctorDashboard() {
    if (_isLoadingAnalytics || _doctorDashboardData == null) {
      return const SizedBox(height: 500, child: SkeletonGrid(itemCount: 6));
    }

    final todayAppts = _doctorDashboardData!.todayAppointments;
    final now = DateTime.now();
    final doctorStart =
        _doctorCustomDateRange?.start ??
        switch (_doctorDateRange) {
          AdminDateRangeType.days7 => now.subtract(const Duration(days: 7)),
          AdminDateRangeType.days30 => now.subtract(const Duration(days: 30)),
          AdminDateRangeType.months3 => now.subtract(const Duration(days: 90)),
          AdminDateRangeType.custom => now.subtract(const Duration(days: 30)),
        };
    final doctorEnd = _doctorCustomDateRange?.end ?? now;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminDateFilterBar(
          selectedRangeType: _doctorDateRange,
          customDateRange: _doctorCustomDateRange,
          formattedRange:
              '${DateFormat('d MMM yyyy').format(doctorStart)} – ${DateFormat('d MMM yyyy').format(doctorEnd)}',
          onRangeSelected: (type, customRange) {
            setState(() {
              _doctorDateRange = type;
              _doctorCustomDateRange = customRange;
            });
            _loadDoctorAnalytics();
          },
        ),
        if (_isLoadingAnalytics)
          const LinearProgressIndicator(
            color: AppColors.rose,
            backgroundColor: AppColors.bgRose,
            minHeight: 2,
          ),
        const SizedBox(height: 20),
        // Stats and today's appointments, side by side.
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth > 880;
            return Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Cards Column
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: Column(
                    children: [
                      _StatCard(
                        label: "Today's Patients",
                        value: _doctorDashboardData!.todayPatientsCount
                            .toString(),
                        sub:
                            "${todayAppts.where((a) => a.status == 'PLANNED').length} remaining",
                        icon: Icons.calendar_today,
                        color: AppColors.rose,
                        valueBesideLabel: true,
                      ),
                      const SizedBox(height: 16),
                      _StatCard(
                        label: "Active patients under my care",
                        value: _doctorDashboardData!.activePatientsCount
                            .toString(),
                        sub: "",
                        icon: Icons.people,
                        color: AppColors.lav,
                        valueBesideLabel: true,
                      ),
                    ],
                  ),
                ),
                if (isWide)
                  const SizedBox(width: 20)
                else
                  const SizedBox(height: 20),

                // Today's Appointments List
                Expanded(
                  flex: isWide ? 2 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.rose.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.rose,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Today\'s Appointments',
                                    style:
                                        AppTypography.displaySubtitle(
                                          color: AppColors.text,
                                        ).copyWith(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text(
                                    '${todayAppts.length} consultation${todayAppts.length == 1 ? '' : 's'} · Click to open EHR',
                                    style: AppTypography.bodySmall(
                                      color: AppColors.textMuted,
                                    ).copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        if (todayAppts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_available_outlined,
                                    size: 36,
                                    color: AppColors.textMuted.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No consultations scheduled for today.',
                                    style: AppTypography.bodySmall(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...todayAppts.map((appt) {
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => widget.onViewPatient(appt.patientId),
                              child: _buildAppointmentRow(
                                time: appt.time,
                                patient: appt.patientName,
                                patientId: appt.patientId,
                                treatment: appt.treatmentName,
                                doctor: null,
                                status: appt.status,
                                isClickable: true,
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        // 2. MY ANALYTICS SECTION
        _buildSectionHeader(
          title: 'My Analytics',
          subtitle:
              'Fulfillment outcomes, appointment counts, and treatments performed under your care',
          icon: Icons.analytics_outlined,
          color: AppColors.rose,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 960;
            return Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: AppointmentOutcomesDonut(
                    data: _doctorDashboardData!.appointmentOutcomes,
                  ),
                ),
                if (isDesktop)
                  const SizedBox(width: 20)
                else
                  const SizedBox(height: 20),
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: PatientGrowthLineChart(
                    data: _doctorDashboardData!.appointmentsOverTime,
                    title: 'Completed Sessions Over Time',
                    subtitle:
                        'Number of completed patient consultations per day in the selected period',
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
          data: _doctorDashboardData!.treatmentsPerformed,
          showTopService: false,
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // Receptionist dashboard.
  Widget _buildReceptionistDashboard() {
    return FutureBuilder<List<Appointment>>(
      future: _receptionAppointments,
      builder: (context, snapshot) {
        final appointments = snapshot.data ?? const <Appointment>[];
        final today = DateTime.now();
        final todayAllAppointments = appointments.where((appointment) {
          final date = appointment.scheduledAt.toLocal();
          return date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
        }).toList();
        final todayAppointments = todayAllAppointments.where((appointment) {
          return _receptionStatusFilter == 'ALL' ||
              appointment.status == _receptionStatusFilter;
        }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        final weekEnd = today.add(const Duration(days: 7));
        final upcoming = appointments.where((appointment) {
          return appointment.status == 'BOOKED' &&
              appointment.scheduledAt.isAfter(today) &&
              appointment.scheduledAt.isBefore(weekEnd);
        }).length;
        final cancelledToday = todayAllAppointments
            .where((appointment) => appointment.status == 'CANCELLED')
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: _StatCard(
                      label: "Today's appointments",
                      value: '${todayAllAppointments.length}',
                      sub: '',
                      icon: Icons.today_outlined,
                      color: AppColors.rose,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 240,
                    child: _StatCard(
                      label: 'Upcoming this week',
                      value: '$upcoming',
                      sub: 'Booked visits',
                      icon: Icons.date_range_outlined,
                      color: AppColors.lavDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 240,
                    child: _StatCard(
                      label: 'Cancellations today',
                      value: '$cancelledToday',
                      sub: '',
                      icon: Icons.event_busy_outlined,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 240,
                    child: FutureBuilder<int>(
                      future: _receptionDoctorCount,
                      builder: (_, doctorSnapshot) => _StatCard(
                        label: 'Doctors',
                        value: '${doctorSnapshot.data ?? 0}',
                        sub: 'Check availability',
                        icon: Icons.medical_information_outlined,
                        color: AppColors.sageDark,
                        onTap: widget.onViewDoctors,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: widget.onBookAppointment,
                  icon: const Icon(Icons.add),
                  label: const Text('Book appointment'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onCheckInPatient,
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: const Text('Check in patient'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text("Today's schedule", style: AppTypography.displaySubtitle()),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final status in const ['ALL', 'BOOKED', 'CANCELLED'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          status == 'ALL'
                              ? 'All statuses'
                              : status == 'BOOKED'
                              ? 'Confirmed'
                              : 'Cancelled',
                        ),
                        selected: _receptionStatusFilter == status,
                        onSelected: (_) =>
                            setState(() => _receptionStatusFilter = status),
                        selectedColor: AppColors.rose,
                        checkmarkColor: Colors.white,
                        labelStyle: AppTypography.labelMedium(
                          color: _receptionStatusFilter == status
                              ? Colors.white
                              : AppColors.textSub,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done)
              const SizedBox(height: 320, child: SkeletonList(itemCount: 4))
            else if (todayAppointments.isEmpty)
              Text(
                'No appointments scheduled today.',
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
              )
            else
              ...todayAppointments.map(
                (appointment) => _buildAppointmentRow(
                  time: DateFormat(
                    'HH:mm',
                  ).format(appointment.scheduledAt.toLocal()),
                  patient: appointment.patientName,
                  treatment: appointment.sessions.isEmpty
                      ? 'Appointment'
                      : appointment.sessions
                            .map((session) => session.treatmentLabel)
                            .join(', '),
                  doctor: appointment.sessions.isEmpty
                      ? null
                      : appointment.sessions.first.practitionerName,
                  status: appointment.status == 'BOOKED'
                      ? 'Confirmed'
                      : 'Cancelled',
                ),
              ),
          ],
        );
      },
    );
  }

  // Patient dashboard.
  Widget _buildPatientDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
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
                        'Welcome back, Nour',
                        style: AppTypography.displayTitle(),
                      ),
                      Text(
                        'Your next visit is scheduled for Thursday, 7 Aug at 09:15 AM',
                        style: AppTypography.bodySmall(color: AppColors.rose),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => widget.onViewPatient('Nour Al-Khalil'),
                    child: const Text('My Full Profile'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Text('Your Active Care Plan', style: AppTypography.labelLarge()),
              const SizedBox(height: 8),
              Text(
                'Laser Resurfacing (Session 3 of 5) + HydroGlow Hydration Treatment.',
                style: AppTypography.bodyMedium(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentRow({
    required String time,
    required String patient,
    String? patientId,
    required String treatment,
    String? doctor,
    required String status,
    bool isClickable = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              time,
              style: AppTypography.labelSmall(color: AppColors.textMuted),
            ),
          ),
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.bgRose,
            child: Text(
              patient.split(' ').map((w) => w[0]).join(''),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.rose,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: isClickable && patientId != null && patientId.isNotEmpty
                  ? () => widget.onViewPatient(patientId)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient,
                    style: AppTypography.labelMedium(color: AppColors.text)
                        .copyWith(
                          decoration: isClickable
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                  ),
                  Text(
                    treatment,
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          if (doctor != null)
            Text(
              doctor,
              style: AppTypography.bodySmall(color: AppColors.textSub),
            ),
          const SizedBox(width: 12),
          StatusPill(status: status),
        ],
      ),
    );
  }

  Widget _buildStaffTile(
    String name,
    String role,
    String appts,
    String status, {
    required bool isDoctor,
  }) {
    return InkWell(
      onTap: isDoctor ? () => widget.onViewDoctor(name) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.bgRose,
              child: Text(
                name.split(' ').map((w) => w[0]).take(2).join(''),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.rose,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.labelMedium()),
                  Text('$role · $appts', style: AppTypography.bodySmall()),
                ],
              ),
            ),
            StatusPill(status: status),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool valueBesideLabel;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.trend,
    this.valueBesideLabel = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.18),
                        color.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (valueBesideLabel)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelMedium(
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                value,
                                style: AppTypography.displayStat(
                                  color: AppColors.text,
                                ).copyWith(fontSize: 24),
                              ),
                            ],
                          )
                        else ...[
                          Text(
                            label,
                            style: AppTypography.labelSmall(
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                value,
                                style: AppTypography.displayStat(
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  sub,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall(
                                    color: color,
                                  ).copyWith(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (valueBesideLabel && sub.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            sub,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall(
                              color: color,
                            ).copyWith(fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      trend!,
                      style: AppTypography.labelSmall(
                        color: color,
                      ).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
