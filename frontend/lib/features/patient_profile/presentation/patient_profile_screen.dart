import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../forms/data/clinical_intake_api.dart';
import '../../forms/data/dynamic_form_api.dart';
import 'widgets/clinical_intake_tab.dart';

/// Patient EHR & Profile View Screen
class PatientProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onBackToAppointments;
  final ClinicalIntakeApi clinicalApi;
  final DynamicFormApi dynamicApi;
  final String? patientId;
  final int initialTabIndex;

  const PatientProfileScreen({
    super.key,
    this.onBack,
    this.onBackToAppointments,
    required this.clinicalApi,
    required this.dynamicApi,
    this.patientId,
    this.initialTabIndex = 0,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic>? _patientData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    try {
      final data = widget.patientId != null
          ? await widget.clinicalApi.fetchForPatient(widget.patientId!)
          : await widget.clinicalApi.fetchOwn();
      if (!mounted) return;
      setState(() {
        _patientData = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final allergies = List<String>.from(_patientData?['allergies'] ?? []);

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

          if (allergies.isNotEmpty) ...[
            const SizedBox(height: 20),
            // Medical Alert Banner
            _buildAllergyAlert(allergies),
          ],

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
              Tab(text: 'Treatment History'),
              Tab(text: 'Prescriptions & Products'),
              Tab(text: 'Clinic Forms'),
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
                _buildHistoryTab(),
                _buildPrescriptionsTab(),
                ClinicalIntakeTab(
                  clinicalApi: widget.clinicalApi,
                  dynamicApi: widget.dynamicApi,
                  patientId: widget.patientId,
                  onBackToAppointments: widget.onBackToAppointments,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    final firstName = _patientData?['firstName']?.toString() ?? '';
    final lastName = _patientData?['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final displayName = fullName.isNotEmpty ? fullName : 'Patient Profile';

    final initials = (firstName.isNotEmpty ? firstName[0] : '') +
        (lastName.isNotEmpty ? lastName[0] : '');
    final avatarText = initials.isNotEmpty ? initials.toUpperCase() : 'P';

    final gender = _patientData?['gender']?.toString();
    final dob = _patientData?['dateOfBirth']?.toString();
    final skinType = _patientData?['skinType']?.toString();
    final isPregnant = _patientData?['pregnantBreastfeeding'] == true;

    final subInfo = [
      if (gender != null && gender.isNotEmpty) _humanizeEnum(gender),
      if (dob != null && dob.isNotEmpty) 'DOB: $dob',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.bgRose,
            child: Text(
              avatarText,
              style: const TextStyle(
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
                Text(displayName, style: AppTypography.displayTitle()),
                if (subInfo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subInfo,
                    style: AppTypography.bodySmall(color: AppColors.textSub),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (skinType != null && skinType.isNotEmpty)
                      _buildTag(
                        'Skin: ${_humanizeEnum(skinType)}',
                        AppColors.rose,
                        AppColors.bgRose,
                      ),
                    if (isPregnant)
                      _buildTag(
                        'Pregnant / Nursing',
                        const Color(0xFFDC2626),
                        const Color(0xFFFEF2F2),
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

  Widget _buildAllergyAlert(List<String> allergies) {
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
              'Allergy Alert: Sensitive to ${allergies.map(_humanizeEnum).join(', ')}. Use caution when prescribing treatments.',
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
    final email = _patientData?['email']?.toString() ?? 'Not provided';
    final phone = _patientData?['phone']?.toString() ?? 'Not provided';
    final skinType = _patientData?['skinType'] != null
        ? _humanizeEnum(_patientData!['skinType'].toString())
        : 'Not recorded';
    final smoking = _patientData?['smokingStatus'] != null
        ? _humanizeEnum(_patientData!['smokingStatus'].toString())
        : 'Not recorded';
    final allergies = List<String>.from(_patientData?['allergies'] ?? []);
    final medications = List<String>.from(_patientData?['medications'] ?? []);
    final chronicConditions =
        List<String>.from(_patientData?['chronicConditions'] ?? []);

    return ListView(
      children: [
        _buildInfoRow('Email', email),
        _buildInfoRow('Phone', phone),
        _buildInfoRow('Skin Type', skinType),
        _buildInfoRow('Smoking Status', smoking),
        _buildInfoRow(
          'Allergies',
          allergies.isNotEmpty
              ? allergies.map(_humanizeEnum).join(', ')
              : 'None reported',
        ),
        _buildInfoRow(
          'Current Medications',
          medications.isNotEmpty
              ? medications.map(_humanizeEnum).join(', ')
              : 'None reported',
        ),
        _buildInfoRow(
          'Chronic Conditions',
          chronicConditions.isNotEmpty
              ? chronicConditions.map(_humanizeEnum).join(', ')
              : 'None reported',
        ),
      ],
    );
  }

  static String _humanizeEnum(String text) {
    if (text.isEmpty) return text;
    final words = text.replaceAll('_', ' ').split(' ');
    return words.map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
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
