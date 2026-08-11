import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Patient EHR & Profile View Screen
class PatientProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PatientProfileScreen({super.key, this.onBack});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
                label: const Text('Back'),
              ),
            ),

          // Patient Header
          _buildPatientHeader(),

          const SizedBox(height: 20),

          // Medical Alert Banner
          _buildAllergyAlert(),

          const SizedBox(height: 20),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.rose,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.rose,
            labelStyle: AppTypography.labelMedium(),
            unselectedLabelStyle: AppTypography.labelMedium(),
            tabs: const [
              Tab(text: 'Overview & Info'),
              Tab(text: 'Skin Metrics'),
              Tab(text: 'Treatment History'),
              Tab(text: 'Prescriptions & Products'),
            ],
          ),

          const SizedBox(height: 20),

          // Tab Body
          SizedBox(
            height: 480,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSkinMetricsTab(),
                _buildHistoryTab(),
                _buildPrescriptionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.bgRose,
            child: Text(
              'NK',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.rose,
              ),
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
                    Text('Nour Al-Khalil', style: AppTypography.displayTitle()),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldPale,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '⭐ 840 Loyalty Pts',
                        style: AppTypography.labelSmall(color: AppColors.gold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '33 Yrs (14 Mar 1993) · Fitzpatrick Type III · Female',
                  style: AppTypography.bodySmall(color: AppColors.textSub),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTag(
                      'Skin: Sensitive / Combination',
                      AppColors.rose,
                      AppColors.bgRose,
                    ),
                    const SizedBox(width: 8),
                    _buildTag(
                      '12 Total Sessions',
                      AppColors.sage,
                      AppColors.bgSage,
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

  Widget _buildAllergyAlert() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Allergy Alert: Sensitive to Retinoids & Salicylic Acid above 2%. Use mild soothing formulas.',
              style: AppTypography.bodySmall(
                color: const Color(0xFF991B1B),
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      children: [
        _buildInfoRow(
          'Primary Concern',
          'Hyperpigmentation & Post-acne Redness',
        ),
        _buildInfoRow('Assigned Specialist', 'Dr. Hana Nasser'),
        _buildInfoRow('Email', 'nour@yasmine.clinic'),
        _buildInfoRow('Phone', '+970 59 123 4567'),
        _buildInfoRow('Emergency Contact', 'Hana Al-Khalil (+970 59 765 4321)'),
      ],
    );
  }

  Widget _buildSkinMetricsTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 10),
      children: const [
        _MetricBar(
          label: 'Moisture & Hydration Level',
          progress: 0.78,
          value: '78% (Optimal)',
          color: AppColors.sage,
        ),
        _MetricBar(
          label: 'Barrier Sensitivity Index',
          progress: 0.42,
          value: '42% (Moderate)',
          color: AppColors.gold,
        ),
        _MetricBar(
          label: 'Collagen Density & Elasticity',
          progress: 0.85,
          value: '85% (Excellent)',
          color: AppColors.rose,
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      children: const [
        _HistoryItem(
          date: '7 Aug 2026',
          tx: 'Laser Resurfacing',
          doctor: 'Dr. Hana Nasser',
          status: 'Scheduled',
        ),
        _HistoryItem(
          date: '12 Jul 2026',
          tx: 'HydroGlow Facial',
          doctor: 'Dr. Reem Khalil',
          status: 'Completed',
        ),
        _HistoryItem(
          date: '20 Jun 2026',
          tx: 'Chemical Peel 15%',
          doctor: 'Dr. Hana Nasser',
          status: 'Completed',
        ),
      ],
    );
  }

  Widget _buildPrescriptionsTab() {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.medication, color: AppColors.rose),
          title: Text('NovaClear Gentle Cleanser'),
          subtitle: Text('Apply twice daily after washing face'),
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.spa, color: AppColors.lav),
          title: Text('HydraBoost HA Recovery Gel'),
          subtitle: Text('Apply after laser sessions for 5 days'),
        ),
      ],
    );
  }

  Widget _buildTag(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: AppTypography.labelSmall(color: color)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
          Text(value, style: AppTypography.labelMedium()),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double progress;
  final String value;
  final Color color;

  const _MetricBar({
    required this.label,
    required this.progress,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTypography.labelMedium()),
              Text(value, style: AppTypography.labelSmall(color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.bgAlt,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final String date;
  final String tx;
  final String doctor;
  final String status;

  const _HistoryItem({
    required this.date,
    required this.tx,
    required this.doctor,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx, style: AppTypography.labelLarge()),
              Text(
                '$date · $doctor',
                style: AppTypography.bodySmall(color: AppColors.textMuted),
              ),
            ],
          ),
          Text(status, style: AppTypography.labelSmall(color: AppColors.sage)),
        ],
      ),
    );
  }
}
