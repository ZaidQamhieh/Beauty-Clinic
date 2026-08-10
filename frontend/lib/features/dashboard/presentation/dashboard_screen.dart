import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_pill.dart';

/// Comprehensive Dashboard Screen supporting Admin, Doctor, Receptionist, and Patient views
class DashboardScreen extends StatefulWidget {
  final String activeRole;
  final ValueChanged<String> onViewPatient;
  final ValueChanged<String> onViewDoctor;

  const DashboardScreen({
    super.key,
    required this.activeRole,
    required this.onViewPatient,
    required this.onViewDoctor,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedPatientQueue = 'Nour Al-Khalil';
  final Set<String> _approvedProducts = {'NovaClear Enzyme Peel'};

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
      'doctor': 'Doctor Portal — Dr. Hana Nasser',
      'receptionist': 'Front Desk & Reception',
      'patient': 'My Health & Beauty Portal',
    };

    final Map<String, String> subtitles = {
      'admin': 'Real-time clinic analytics, appointments, and AI optimization.',
      'doctor': '8 appointments today · 4 remaining · 5 product approvals pending.',
      'receptionist': 'Manage today\'s patient check-ins, queue, and practitioner schedules.',
      'patient': 'View upcoming appointments, treatment history, and skin progress.',
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
            child: const Icon(Icons.auto_awesome, color: AppColors.rose, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[widget.activeRole] ?? 'Clinic Dashboard',
                  style: AppTypography.displaySubtitle(color: AppColors.text)
                      .copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitles[widget.activeRole] ?? 'Welcome to Yasmine Beauty Clinic',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Stat Cards
        LayoutBuilder(builder: (context, constraints) {
          final int crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: constraints.maxWidth > 900 ? 1.6 : 2.1,
            children: const [
              _StatCard(label: "Total Patients", value: "1,284", sub: "48 new this month", icon: Icons.people_outline, color: AppColors.rose, trend: "+12%"),
              _StatCard(label: "Today's Appts", value: "24", sub: "3 pending confirmation", icon: Icons.calendar_today_outlined, color: AppColors.lav, trend: "+3"),
              _StatCard(label: "Monthly Revenue", value: "£29.8k", sub: "vs £24.0k last month", icon: Icons.payments_outlined, color: AppColors.gold, trend: "+24%"),
              _StatCard(label: "Active Doctors", value: "3", sub: "1 currently in session", icon: Icons.medical_services_outlined, color: AppColors.sage),
            ],
          );
        }),

        const SizedBox(height: 24),

        // Revenue Chart & AI Suggestions Row
        LayoutBuilder(builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 900;
          return Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Revenue Bar Chart
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Revenue Overview', style: AppTypography.labelLarge()),
                              Text('Feb – Aug 2026', style: AppTypography.bodySmall()),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.bgRose,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Monthly', style: AppTypography.labelSmall(color: AppColors.rose)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 140,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            _BarItem(month: 'Feb', heightFactor: 0.55, amount: '£18.2k'),
                            _BarItem(month: 'Mar', heightFactor: 0.72, amount: '£23.4k'),
                            _BarItem(month: 'Apr', heightFactor: 0.62, amount: '£20.1k'),
                            _BarItem(month: 'May', heightFactor: 0.81, amount: '£26.3k'),
                            _BarItem(month: 'Jun', heightFactor: 0.74, amount: '£24.0k'),
                            _BarItem(month: 'Jul', heightFactor: 0.92, amount: '£29.8k'),
                            _BarItem(month: 'Aug', heightFactor: 0.68, amount: '£21.9k'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isDesktop) const SizedBox(width: 20) else const SizedBox(height: 20),

              // AI Scheduling Card
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgLavender,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderLav),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppColors.lavDark, size: 18),
                          const SizedBox(width: 8),
                          Text('AI Scheduling Insights', style: AppTypography.labelLarge(color: AppColors.lavDark)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildAISuggestionItem(
                        tag: 'Efficiency',
                        message: 'Move Nour 09:15 → 10:00 to reduce Dr. Hana\'s gap.',
                      ),
                      const SizedBox(height: 12),
                      _buildAISuggestionItem(
                        tag: 'Opportunity',
                        message: 'Dr. Reem has 45-min slot at 14:30 — 2 patients waiting.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),

        const SizedBox(height: 24),

        // Appointments & Staff Roster
        LayoutBuilder(builder: (context, constraints) {
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
                          Text('Today\'s Appointments', style: AppTypography.labelLarge()),
                          TextButton(onPressed: () {}, child: const Text('View All')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildAppointmentRow(time: '09:15', patient: 'Nour Al-Khalil', treatment: 'Laser Resurfacing', doctor: 'Dr. Hana', status: 'In Room', isClickable: true),
                      _buildAppointmentRow(time: '10:00', patient: 'Layla Mansour', treatment: 'HydroGlow Facial', doctor: 'Dr. Reem', status: 'Confirmed'),
                      _buildAppointmentRow(time: '10:30', patient: 'Samia Barakat', treatment: 'Body Contour', doctor: 'Dr. Sana', status: 'Confirmed'),
                      _buildAppointmentRow(time: '11:15', patient: 'Rania Jaber', treatment: 'Chemical Peel', doctor: 'Dr. Hana', status: 'Pending'),
                      _buildAppointmentRow(time: '13:00', patient: 'Maya Al-Hassan', treatment: 'Microneedling', doctor: 'Dr. Reem', status: 'Confirmed'),
                    ],
                  ),
                ),
              ),

              if (isDesktop) const SizedBox(width: 20) else const SizedBox(height: 20),

              // Staff On Duty
              Expanded(
                flex: isDesktop ? 1 : 0,
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
                      Text('Staff Today', style: AppTypography.labelLarge()),
                      const SizedBox(height: 16),
                      _buildStaffTile('Dr. Hana Nasser', 'Dermatologist', '8 appts', 'Available', isDoctor: true),
                      _buildStaffTile('Dr. Reem Khalil', 'Aesthetic Med', '6 appts', 'In Session', isDoctor: true),
                      _buildStaffTile('Dr. Sana Al-Farsi', 'Laser Spec.', '10 appts', 'Available', isDoctor: true),
                      _buildStaffTile('Laila (Reception)', 'Front Desk', '24 check-ins', 'On Duty', isDoctor: false),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgRose,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderRose),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Today\'s Billing', style: AppTypography.labelSmall(color: AppColors.rose)),
                                Text('£2,840', style: AppTypography.displayTitle(color: AppColors.text).copyWith(fontSize: 22)),
                              ],
                            ),
                            const Icon(Icons.account_balance_wallet_outlined, color: AppColors.rose, size: 28),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DOCTOR DASHBOARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDoctorDashboard() {
    final patients = [
      {'name': 'Nour Al-Khalil', 'tx': 'Laser Resurfacing', 'time': '09:15', 'skin': 'Sensitive / Dry', 'status': 'In Room'},
      {'name': 'Layla Mansour', 'tx': 'HydroGlow Facial', 'time': '10:00', 'skin': 'Oily / Combo', 'status': 'Waiting'},
      {'name': 'Samia Barakat', 'tx': 'Body Contour', 'time': '10:30', 'skin': 'Normal', 'status': 'Confirmed'},
      {'name': 'Rania Jaber', 'tx': 'Chemical Peel', 'time': '11:15', 'skin': 'Dry / Mature', 'status': 'Confirmed'},
    ];

    final activePatient = patients.firstWhere(
      (p) => p['name'] == _selectedPatientQueue,
      orElse: () => patients[0],
    );

    return Column(
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final int crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.8,
            children: const [
              _StatCard(label: "Today's Patients", value: "8", sub: "4 remaining", icon: Icons.calendar_today, color: AppColors.rose),
              _StatCard(label: "Under My Care", value: "142", sub: "Active patients", icon: Icons.people, color: AppColors.lav),
              _StatCard(label: "Pending Approvals", value: "5", sub: "Product matches", icon: Icons.auto_awesome, color: AppColors.gold, trend: "!"),
              _StatCard(label: "Avg Rating", value: "4.9", sub: "From 142 reviews", icon: Icons.star, color: AppColors.sage),
            ],
          );
        }),

        const SizedBox(height: 24),

        LayoutBuilder(builder: (context, constraints) {
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
                      Text('Today\'s Consultation Queue', style: AppTypography.labelLarge()),
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
                              color: isSelected ? AppColors.bgRose : AppColors.bgAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.borderRose : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(p['time']!, style: AppTypography.labelSmall()),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['name']!, style: AppTypography.labelMedium()),
                                      Text(p['tx']!, style: AppTypography.bodySmall()),
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

              if (isDesktop) const SizedBox(width: 20) else const SizedBox(height: 20),

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
                              Text(activePatient['name']!, style: AppTypography.displaySubtitle()),
                              Text('Skin Type: ${activePatient['skin']}', style: AppTypography.bodySmall(color: AppColors.rose)),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => widget.onViewPatient(activePatient['name']!),
                            icon: const Icon(Icons.assignment_ind, size: 16),
                            label: const Text('Open Full EHR'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text('Recommended Product Approvals', style: AppTypography.labelLarge()),
                      const SizedBox(height: 12),
                      _buildProductApprovalItem('NovaClear Enzyme Peel', 'Exfoliating serum for sensitive skin'),
                      _buildProductApprovalItem('HydraBoost HA Serum', 'Deep hydration post-laser session'),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
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

        Text('Front Desk Queue (12 Waiting / In Session)', style: AppTypography.displaySubtitle()),
        const SizedBox(height: 16),
        _buildAppointmentRow(time: '09:15', patient: 'Nour Al-Khalil', treatment: 'Laser Resurfacing', doctor: 'Dr. Hana', status: 'In Room', isClickable: true),
        _buildAppointmentRow(time: '10:00', patient: 'Layla Mansour', treatment: 'HydroGlow Facial', doctor: 'Dr. Reem', status: 'Waiting'),
        _buildAppointmentRow(time: '10:30', patient: 'Samia Barakat', treatment: 'Body Contour', doctor: 'Dr. Sana', status: 'Confirmed'),
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
                      Text('Welcome back, Nour', style: AppTypography.displayTitle()),
                      Text('Your next visit is scheduled for Thursday, 7 Aug at 09:15 AM', style: AppTypography.bodySmall(color: AppColors.rose)),
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
              Text('Laser Resurfacing (Session 3 of 5) + HydroGlow Hydration Treatment.', style: AppTypography.bodyMedium()),
            ],
          ),
        ),
      ],
    );
  }

  // Helper widgets
  Widget _buildAISuggestionItem({required String tag, required String message}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.lavPale,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(tag, style: AppTypography.labelSmall(color: AppColors.lavDark)),
          ),
          const SizedBox(height: 6),
          Text(message, style: AppTypography.bodySmall(color: AppColors.textSub)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Apply', style: AppTypography.labelSmall(color: AppColors.white)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Dismiss', style: AppTypography.labelSmall(color: AppColors.textMuted)),
              ),
            ],
          ),
        ],
      ),
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
            child: Text(time, style: AppTypography.labelSmall(color: AppColors.textMuted)),
          ),
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.bgRose,
            child: Text(
              patient.split(' ').map((w) => w[0]).join(''),
              style: const TextStyle(fontSize: 10, color: AppColors.rose, fontWeight: FontWeight.bold),
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
                    style: AppTypography.labelMedium(color: AppColors.text).copyWith(
                      decoration: isClickable ? TextDecoration.underline : TextDecoration.none,
                    ),
                  ),
                  Text(treatment, style: AppTypography.bodySmall(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
          Text(doctor, style: AppTypography.bodySmall(color: AppColors.textSub)),
          const SizedBox(width: 12),
          StatusPill(status: status),
        ],
      ),
    );
  }

  Widget _buildStaffTile(String name, String role, String appts, String status, {required bool isDoctor}) {
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
                style: const TextStyle(fontSize: 10, color: AppColors.rose, fontWeight: FontWeight.bold),
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
          const Icon(Icons.medication_outlined, color: AppColors.rose, size: 20),
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
            child: Text(isApproved ? 'Approved ✓' : 'Approve', style: AppTypography.labelSmall(color: AppColors.white)),
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
      padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend!.startsWith('+') ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trend!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: trend!.startsWith('+') ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.displayStat(color: AppColors.text)),
          Text(label, style: AppTypography.labelSmall(color: AppColors.text)),
          Text(sub, style: AppTypography.labelSmall(color: color).copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final String month;
  final double heightFactor;
  final String amount;

  const _BarItem({
    required this.month,
    required this.heightFactor,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Tooltip(
            message: amount,
            child: Container(
              height: 100 * heightFactor,
              width: 18,
              decoration: BoxDecoration(
                color: AppColors.rose,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(month, style: AppTypography.labelSmall(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
