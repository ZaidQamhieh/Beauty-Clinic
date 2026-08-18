import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../network/api_client.dart';
import '../data/admin_analytics_models.dart';
import 'widgets/admin_analytics_charts.dart';
import 'widgets/admin_date_filter_bar.dart';

/// Comprehensive Dashboard Screen supporting Admin, Doctor, Receptionist, and Patient views
class DashboardScreen extends StatefulWidget {
  final String activeRole;
  final ValueChanged<String> onViewPatient;
  final ValueChanged<String> onViewDoctor;
  final ApiClient? apiClient;

  const DashboardScreen({
    super.key,
    required this.activeRole,
    required this.onViewPatient,
    required this.onViewDoctor,
    this.apiClient,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedPatientQueue = 'Nour Al-Khalil';
  final Set<String> _approvedProducts = {'NovaClear Enzyme Peel'};

  // Admin Dashboard Date Filter State
  AdminDateRangeType _adminDateRange = AdminDateRangeType.days30;
  DateTimeRange? _customDateRange;
  AdminDashboardData? _adminDashboardData;
  bool _isLoadingAnalytics = false;

  @override
  void initState() {
    super.initState();
    if (widget.activeRole == 'admin') {
      _loadAnalytics();
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
      'doctor': 'Doctor Portal',
      'receptionist': 'Front Desk & Reception',
      'patient': 'My Health & Beauty Portal',
    };

    final Map<String, String> subtitles = {
      'admin': 'Real-time clinic analytics, appointments, and operations.',
      'doctor': 'Today\'s clinical schedule, appointments, and patient care.',
      'receptionist':
          'Manage patient check-ins, queue status, and practitioner schedules.',
      'patient':
          'View upcoming appointments, treatment history, and skin progress.',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
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
                  ).copyWith(fontSize: 20),
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

  // ───────────────────────────────────────────────────────────────────────────
  // ADMIN DASHBOARD
  // ───────────────────────────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────────────────────────
  // DOCTOR DASHBOARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDoctorDashboard() {
    final patients = [
      {
        'name': 'Nour Al-Khalil',
        'tx': 'Laser Resurfacing',
        'time': '09:15',
        'skin': 'Sensitive / Dry',
        'status': 'In Room',
      },
      {
        'name': 'Layla Mansour',
        'tx': 'HydroGlow Facial',
        'time': '10:00',
        'skin': 'Oily / Combo',
        'status': 'Waiting',
      },
      {
        'name': 'Samia Barakat',
        'tx': 'Body Contour',
        'time': '10:30',
        'skin': 'Normal',
        'status': 'Confirmed',
      },
      {
        'name': 'Rania Jaber',
        'tx': 'Chemical Peel',
        'time': '11:15',
        'skin': 'Dry / Mature',
        'status': 'Confirmed',
      },
    ];

    final activePatient = patients.firstWhere(
      (p) => p['name'] == _selectedPatientQueue,
      orElse: () => patients[0],
    );

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final int crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.8,
              children: const [
                _StatCard(
                  label: "Today's Patients",
                  value: "8",
                  sub: "4 remaining",
                  icon: Icons.calendar_today,
                  color: AppColors.rose,
                ),
                _StatCard(
                  label: "Under My Care",
                  value: "142",
                  sub: "Active patients",
                  icon: Icons.people,
                  color: AppColors.lav,
                ),
                _StatCard(
                  label: "Pending Approvals",
                  value: "5",
                  sub: "Product matches",
                  icon: Icons.auto_awesome,
                  color: AppColors.gold,
                  trend: "!",
                ),
                _StatCard(
                  label: "Avg Rating",
                  value: "4.9",
                  sub: "From 142 reviews",
                  icon: Icons.star,
                  color: AppColors.sage,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 850;
            return Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Queue Selector
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
                        Text(
                          'Today\'s Consultation Queue',
                          style: AppTypography.labelLarge(),
                        ),
                        const SizedBox(height: 16),
                        ...patients.map((p) {
                          final isSelected = p['name'] == _selectedPatientQueue;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPatientQueue = p['name']!;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.bgRose
                                    : AppColors.bgAlt,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.borderRose
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    p['time']!,
                                    style: AppTypography.labelSmall(),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['name']!,
                                          style: AppTypography.labelMedium(),
                                        ),
                                        Text(
                                          p['tx']!,
                                          style: AppTypography.bodySmall(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusPill(status: p['status']!),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                if (isDesktop)
                  const SizedBox(width: 20)
                else
                  const SizedBox(height: 20),

                // Patient Clinical Summary & Prescriptions
                Expanded(
                  flex: isDesktop ? 3 : 0,
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activePatient['name']!,
                                  style: AppTypography.displaySubtitle(),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Skin Type: ${activePatient['skin']}',
                                      style: AppTypography.bodySmall(
                                        color: AppColors.rose,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgSage,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '✓ Clinic Forms Verified',
                                        style: AppTypography.labelSmall(
                                          color: AppColors.sage,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  widget.onViewPatient(activePatient['name']!),
                              icon: const Icon(
                                Icons.description_outlined,
                                size: 16,
                              ),
                              label: const Text('Open Clinic Forms & EHR'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Recommended Product Approvals',
                          style: AppTypography.labelLarge(),
                        ),
                        const SizedBox(height: 12),
                        _buildProductApprovalItem(
                          'NovaClear Enzyme Peel',
                          'Exfoliating serum for sensitive skin',
                        ),
                        _buildProductApprovalItem(
                          'HydraBoost HA Serum',
                          'Deep hydration post-laser session',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // RECEPTIONIST DASHBOARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildReceptionistDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              Text('Quick Patient Check-in', style: AppTypography.labelLarge()),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Enter Patient Name or Phone Number...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Check In'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Front Desk Queue (12 Waiting / In Session)',
          style: AppTypography.displaySubtitle(),
        ),
        const SizedBox(height: 16),
        _buildAppointmentRow(
          time: '09:15',
          patient: 'Nour Al-Khalil',
          treatment: 'Laser Resurfacing',
          doctor: 'Dr. Hana',
          status: 'In Room',
          isClickable: true,
        ),
        _buildAppointmentRow(
          time: '10:00',
          patient: 'Layla Mansour',
          treatment: 'HydroGlow Facial',
          doctor: 'Dr. Reem',
          status: 'Waiting',
        ),
        _buildAppointmentRow(
          time: '10:30',
          patient: 'Samia Barakat',
          treatment: 'Body Contour',
          doctor: 'Dr. Sana',
          status: 'Confirmed',
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PATIENT DASHBOARD
  // ───────────────────────────────────────────────────────────────────────────
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
    required String treatment,
    required String doctor,
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
              onTap: isClickable ? () => widget.onViewPatient(patient) : null,
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

  Widget _buildProductApprovalItem(String title, String desc) {
    final bool isApproved = _approvedProducts.contains(title);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.medication_outlined,
            color: AppColors.rose,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelMedium()),
                Text(desc, style: AppTypography.bodySmall()),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (isApproved) {
                  _approvedProducts.remove(title);
                } else {
                  _approvedProducts.add(title);
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproved ? AppColors.sage : AppColors.rose,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isApproved ? 'Approved ✓' : 'Approve',
              style: AppTypography.labelSmall(color: AppColors.white),
            ),
          ),
        ],
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

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Grid cells can be fractionally shorter in a browser. Slightly smaller
      // vertical padding keeps the four text rows inside at every zoom level.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: trend!.startsWith('+')
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trend!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: trend!.startsWith('+')
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.displayStat(color: AppColors.text)),
          Text(label, style: AppTypography.labelSmall(color: AppColors.text)),
          Text(
            sub,
            style: AppTypography.labelSmall(
              color: color,
            ).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
