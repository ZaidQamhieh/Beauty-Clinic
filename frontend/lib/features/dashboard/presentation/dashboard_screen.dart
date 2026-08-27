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
  String? _adminAnalyticsError;
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
      // Resolved futures survive, so FutureBuilder never re-waits.
      _receptionAppointments = _keepFuture(
        'receptionAppointments',
        _loadReceptionAppointments,
      );
      _receptionDoctorCount = _keepFuture(
        'receptionDoctorCount',
        _loadReceptionDoctorCount,
      );
    }
  }

  Future<T> _keepFuture<T>(String key, Future<T> Function() load) {
    final kept = widget.apiClient?.readViewState<Future<T>>(key);
    if (kept != null) return kept;

    final started = load();
    widget.apiClient?.writeViewState(key, started);
    return started;
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

  String get _doctorAnalyticsKey =>
      'doctorAnalytics:${_doctorDateRange.name}:${_doctorCustomDateRange?.start}-${_doctorCustomDateRange?.end}';

  Future<void> _loadDoctorAnalytics() async {
    // Repaint last result, refresh behind it.
    _doctorDashboardData ??= widget.apiClient
        ?.readViewState<DoctorDashboardData>(_doctorAnalyticsKey);

    setState(() => _isLoadingAnalytics = _doctorDashboardData == null);
    try {
      final data = await DoctorDashboardRepository.fetchDashboardData(
        widget.apiClient,
        rangeType: _doctorDateRange,
        customRange: _doctorCustomDateRange,
      );
      widget.apiClient?.writeViewState(_doctorAnalyticsKey, data);
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

  String get _analyticsKey =>
      'adminAnalytics:${_adminDateRange.name}:${_customDateRange?.start}-${_customDateRange?.end}';

  Future<void> _loadAnalytics() async {
    // Repaint last result, refresh behind it.
    _adminDashboardData ??= widget.apiClient?.readViewState<AdminDashboardData>(
      _analyticsKey,
    );

    setState(() {
      _isLoadingAnalytics = _adminDashboardData == null;
      _adminAnalyticsError = null;
    });
    try {
      final data = await AdminAnalyticsRepository.fetchDashboardDataAsync(
        rangeType: _adminDateRange,
        customRange: _customDateRange,
        apiClient: widget.apiClient,
      );
      widget.apiClient?.writeViewState(_analyticsKey, data);
      if (!mounted) return;
      setState(() {
        _adminDashboardData = data;
        _isLoadingAnalytics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // Keep showing the last good figures.
        if (_adminDashboardData == null) {
          _adminAnalyticsError = 'Could not load live clinic analytics.';
        }
        _isLoadingAnalytics = false;
      });
    }
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
              ],
            ),
          ),
          if (widget.activeRole == 'receptionist') ...[
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: widget.onBookAppointment,
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Book appointment'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.roseDark,
                backgroundColor: AppColors.bgCard,
                side: const BorderSide(color: AppColors.borderRose),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Admin dashboard.
  Widget _buildAdminDashboard() {
    final adminData = _adminDashboardData;

    if (adminData == null) {
      if (_isLoadingAnalytics) {
        return const SkeletonGrid(
          itemCount: 6,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...[
                Text(
                  _adminAnalyticsError ?? 'Live analytics are unavailable.',
                  style: AppTypography.bodyMedium(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loadAnalytics,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }

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
              // Belongs to the old range; drop it.
              _adminDashboardData = null;
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

        const SizedBox(height: 20),

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
              childAspectRatio: constraints.maxWidth > 900
                  ? 2.35
                  : (constraints.maxWidth > 500 ? 2.2 : 2.5),
              children: [
                _StatCard(
                  label: "Total Patients",
                  value: NumberFormat(
                    '#,###',
                  ).format(adminData.overview.totalPatients),
                  sub: '',
                  icon: Icons.people_outline,
                  color: AppColors.rose,
                  trend: null,
                ),
                _StatCard(
                  label: "Total Doctors",
                  value: "${adminData.overview.totalDoctors}",
                  sub: '',
                  icon: Icons.medical_services_outlined,
                  color: AppColors.sage,
                  trend: null,
                ),
                _StatCard(
                  label: "Today's Appointments",
                  value: "${adminData.overview.todayAppointments}",
                  sub: '',
                  icon: Icons.calendar_today_outlined,
                  color: AppColors.lav,
                  trend: null,
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

        const SizedBox(height: 24),

        // 3. ANALYTICS
        _buildSectionHeader(
          title: 'Analytics',
          subtitle:
              'Services, appointments, and patients over the selected window',
          icon: Icons.insights_outlined,
          color: AppColors.roseDark,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Three across reclaims vertical space.
            final int columns = constraints.maxWidth > 1180
                ? 3
                : (constraints.maxWidth > 780 ? 2 : 1);
            final List<Widget> cards = [
              ServiceGrowthLineChart(data: adminData.serviceAnalytics),
              AppointmentOutcomesDonut(
                data: adminData.appointmentAnalytics.outcomes,
              ),
              PeakTimesAndRescheduledWidget(
                data: adminData.appointmentAnalytics,
              ),
              NewVsReturningDonut(
                data: adminData.patientAnalytics.newVsReturning,
              ),
              PatientGrowthLineChart(
                data: adminData.patientAnalytics.growthTimeline,
                valueLabel: 'Patients',
              ),
              AvailableSlotsWidget(data: adminData.doctorAnalytics),
            ];

            final Widget bookings = ServiceBookingsBarChart(
              data: adminData.serviceAnalytics,
            );

            if (columns == 1) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bookings,
                  for (final card in cards) ...[
                    const SizedBox(height: 16),
                    card,
                  ],
                ],
              );
            }

            final List<Widget> rows = [];
            for (int start = 0; start < cards.length; start += columns) {
              final slice = cards.skip(start).take(columns).toList();
              rows.add(
                // Row cards match the tallest card.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < columns; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(
                          child: i < slice.length
                              ? slice[i]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bookings,
                for (final row in rows) ...[const SizedBox(height: 16), row],
              ],
            );
          },
        ),

        const SizedBox(height: 24),

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
            final Flex row = Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: isDesktop
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
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
                      _fill(
                        isDesktop,
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
                                    doctorId: staff.userId,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            // Bounds row so cards match height.
            return isDesktop ? IntrinsicHeight(child: row) : row;
          },
        ),
      ],
    );
  }

  /// Fills row height only when bounded.
  Widget _fill(bool bounded, Widget child) =>
      bounded ? Expanded(child: child) : child;

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
            final Flex row = Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: isDesktop
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
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
                    valueLabel: 'Completed Sessions',
                    subtitle:
                        'Number of completed patient consultations per day in the selected period',
                    badgeText: 'Completed only',
                    badgeColor: AppColors.sage,
                    fillHeight: isDesktop,
                  ),
                ),
              ],
            );

            // Bounds row so cards match height.
            return isDesktop ? IntrinsicHeight(child: row) : row;
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
            _receptionSection(
              title: 'Today at a glance',
              icon: Icons.query_stats_outlined,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _receptionTile(
                        "Today's appointments",
                        '${todayAllAppointments.length}',
                        Icons.today_outlined,
                        AppColors.rose,
                        AppColors.rosePale,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _receptionTile(
                        'Upcoming this week',
                        '$upcoming',
                        Icons.date_range_outlined,
                        AppColors.lavDark,
                        AppColors.lavPale,
                        sub: 'Booked visits',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _receptionTile(
                        'Cancellations today',
                        '$cancelledToday',
                        Icons.event_busy_outlined,
                        AppColors.gold,
                        AppColors.goldPale,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<int>(
                        future: _receptionDoctorCount,
                        builder: (_, doctorSnapshot) => _receptionClickable(
                          onTap: widget.onViewDoctors,
                          child: _receptionTile(
                            'Doctors',
                            '${doctorSnapshot.data ?? 0}',
                            Icons.medical_information_outlined,
                            AppColors.sageDark,
                            AppColors.sagePale,
                            sub: 'Check availability',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _receptionSection(
              title: "Today's schedule",
              icon: Icons.spa_outlined,
              action: FilledButton.icon(
                onPressed: widget.onCheckInPatient,
                icon: const Icon(Icons.how_to_reg_outlined, size: 17),
                label: const Text('Check in patient'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final status in const [
                          'ALL',
                          'BOOKED',
                          'CANCELLED',
                        ])
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
                              onSelected: (_) => setState(
                                () => _receptionStatusFilter = status,
                              ),
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
                  const SizedBox(height: 14),
                  if (snapshot.connectionState != ConnectionState.done)
                    const SizedBox(
                      height: 300,
                      child: SkeletonList(itemCount: 4),
                    )
                  else if (todayAppointments.isEmpty)
                    Text(
                      'No appointments scheduled today.',
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    ...todayAppointments.map(
                      (appointment) => _receptionScheduleRow(
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
              ),
            ),
          ],
        );
      },
    );
  }

  // Card shell matching the patient dashboard.
  Widget _receptionSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
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
              Expanded(child: Text(title, style: AppTypography.labelLarge())),
              ?action,
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _receptionTile(
    String label,
    String value,
    IconData icon,
    Color color,
    Color chipColor, {
    String? sub,
  }) {
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTypography.displayStat().copyWith(fontSize: 26),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: AppTypography.bodySmall(color: color)),
          ],
        ],
      ),
    );
  }

  Widget _receptionScheduleRow({
    required String time,
    required String patient,
    required String treatment,
    String? doctor,
    required String status,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                time,
                style: AppTypography.numeric(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.spa_outlined,
                color: AppColors.rose,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$patient — $treatment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium(),
                  ),
                  if (doctor != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      doctor,
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusPill(status: status),
          ],
        ),
      ),
    );
  }

  Widget _receptionClickable({
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
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
    String? doctorId,
  }) {
    return InkWell(
      onTap: isDoctor && doctorId != null
          ? () => widget.onViewDoctor(doctorId)
          : null,
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

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.trend,
    this.valueBesideLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
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
