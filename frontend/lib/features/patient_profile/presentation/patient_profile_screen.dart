import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../network/api_client.dart';
import '../../appointments/data/appointment.dart';
import '../../appointments/data/appointment_api.dart';
import '../../appointments/presentation/booking_format.dart';
import '../../forms/data/clinical_intake_api.dart';
import '../../forms/data/dynamic_form_api.dart';
import '../../products/data/product.dart';
import '../../products/data/product_api.dart';
import 'widgets/clinical_intake_tab.dart';

/// Patient EHR & Profile View Screen (100% Database-Driven)
class PatientProfileScreen extends StatefulWidget {
  static const int overviewTabIndex = 0;
  static const int treatmentHistoryTabIndex = 1;
  static const int productsTabIndex = 2;
  static const int clinicFormsTabIndex = 3;

  final VoidCallback? onBack;
  final VoidCallback? onBackToAppointments;
  final ClinicalIntakeApi clinicalApi;
  final DynamicFormApi dynamicApi;
  final AppointmentApi? appointmentApi;
  final ProductApi? productApi;
  final ApiClient? apiClient;
  final String? patientId;
  final int initialTabIndex;

  const PatientProfileScreen({
    super.key,
    this.onBack,
    this.onBackToAppointments,
    required this.clinicalApi,
    required this.dynamicApi,
    this.appointmentApi,
    this.productApi,
    this.apiClient,
    this.patientId,
    this.initialTabIndex = overviewTabIndex,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic>? _patientData;
  bool _loading = true;

  List<Appointment> _treatmentHistory = [];
  bool _loadingHistory = false;
  String? _historyError;

  List<dynamic> _patientProducts = [];
  bool _loadingProducts = false;
  String? _productsError;

  bool get _isOwnProfile => widget.patientId == null;

  @override
  void initState() {
    super.initState();
    final tabCount = _isOwnProfile ? 4 : 3;
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, tabCount - 1),
    );
    _loadPatientData();
    _loadTreatmentHistory();
    _loadProducts();
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

  Future<void> _loadTreatmentHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      if (widget.appointmentApi != null && widget.patientId == null) {
        final page = await widget.appointmentApi!.history(page: 0, size: 50);
        if (!mounted) return;
        setState(() {
          _treatmentHistory = page.items;
          _loadingHistory = false;
        });
      } else if (widget.apiClient != null && widget.patientId != null) {
        final res = await widget.apiClient!.get<Map<String, dynamic>>(
          '/api/appointments/patients/${widget.patientId}/history',
          queryParameters: {'page': 0, 'size': 50},
        );
        final page = AppointmentPage.fromJson(res.data!);
        if (!mounted) return;
        setState(() {
          _treatmentHistory = page.items;
          _loadingHistory = false;
        });
      } else {
        setState(() => _loadingHistory = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = 'Could not load treatment history.';
        _loadingHistory = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });

    try {
      final targetId = widget.patientId ?? _patientData?['id']?.toString();
      if (widget.apiClient != null && targetId != null) {
        final res = await widget.apiClient!.get<List<dynamic>>(
          '/api/patients/$targetId/products',
        );
        if (!mounted) return;
        setState(() {
          _patientProducts = res.data ?? [];
          _loadingProducts = false;
        });
      } else if (widget.productApi != null) {
        final catalog = await widget.productApi!.list();
        if (!mounted) return;
        setState(() {
          _patientProducts = catalog;
          _loadingProducts = false;
        });
      } else {
        setState(() => _loadingProducts = false);
      }
    } catch (e) {
      if (!mounted) return;
      // Fallback to clinic products catalog if patient-specific products 404
      if (widget.productApi != null) {
        try {
          final catalog = await widget.productApi!.list();
          if (!mounted) return;
          setState(() {
            _patientProducts = catalog;
            _loadingProducts = false;
          });
          return;
        } catch (_) {}
      }
      setState(() {
        _productsError = 'Could not load product records.';
        _loadingProducts = false;
      });
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onBack != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: OutlinedButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back to Patients Directory'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rose,
                  side: const BorderSide(color: AppColors.borderRose),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),

          // Patient Header (100% database driven)
          _buildPatientHeader(),

          const SizedBox(height: 24),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.rose,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.rose,
            labelStyle: AppTypography.labelMedium(),
            unselectedLabelStyle: AppTypography.labelMedium(),
            tabs: [
              const Tab(text: 'Overview & Info'),
              const Tab(text: 'Treatment History'),
              const Tab(text: 'Prescriptions & Products'),
              if (_isOwnProfile) const Tab(text: 'Clinic Forms'),
            ],
          ),

          const SizedBox(height: 20),

          // Tab Body
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHistoryTab(),
                _buildProductsTab(),
                if (_isOwnProfile)
                  ClinicalIntakeTab(
                    clinicalApi: widget.clinicalApi,
                    dynamicApi: widget.dynamicApi,
                    patientId: widget.patientId,
                    onBackToAppointments: widget.onBackToAppointments,
                    onSaved: () {
                      _loadPatientData();
                      _loadProducts();
                    },
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

    final initials =
        (firstName.isNotEmpty ? firstName[0] : '') +
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

  Widget _buildOverviewTab() {
    final email = _patientData?['email']?.toString() ?? 'Not provided';
    final phone = _patientData?['phone']?.toString() ?? 'Not provided';
    final gender = _patientData?['gender'] != null
        ? _humanizeEnum(_patientData!['gender'].toString())
        : 'Not recorded';
    final dob = _patientData?['dateOfBirth']?.toString() ?? 'Not recorded';
    final skinType = _patientData?['skinType'] != null
        ? _humanizeEnum(_patientData!['skinType'].toString())
        : 'Not recorded';
    final smoking = _patientData?['smokingStatus'] != null
        ? _humanizeEnum(_patientData!['smokingStatus'].toString())
        : 'Not recorded';
    final pregnant = _patientData?['pregnantBreastfeeding'] == true
        ? 'Yes'
        : 'No';
    final allergies = List<String>.from(_patientData?['allergies'] ?? []);
    final medications = List<String>.from(_patientData?['medications'] ?? []);
    final chronicConditions = List<String>.from(
      _patientData?['chronicConditions'] ?? [],
    );

    return ListView(
      children: [
        _buildInfoRow('Email', email),
        _buildInfoRow('Phone', phone),
        _buildInfoRow('Gender', gender),
        _buildInfoRow('Date of Birth', dob),
        _buildInfoRow('Skin Type', skinType),
        _buildInfoRow('Smoking Status', smoking),
        _buildInfoRow('Pregnant / Nursing', pregnant),
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

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.rose),
            const SizedBox(height: 8),
            Text(_historyError!, style: AppTypography.bodySmall()),
            TextButton(
              onPressed: _loadTreatmentHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_treatmentHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No Past Treatments Recorded',
              style: AppTypography.labelLarge(color: AppColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed and historical visits will appear here.',
              style: AppTypography.bodySmall(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _treatmentHistory.length,
      itemBuilder: (context, index) {
        final appt = _treatmentHistory[index];
        final session = appt.sessions.isNotEmpty ? appt.sessions.first : null;
        final txName = session != null
            ? _humanizeEnum(session.treatmentName)
            : 'Treatment Visit';
        final doctorName = session?.practitionerName ?? 'Clinic Specialist';
        final dateStr = session != null
            ? '${BookingFormat.dayWithYear(session.startTime)} · ${BookingFormat.time12(session.startTime)}'
            : BookingFormat.dayWithYear(appt.scheduledAt);
        final status = _humanizeEnum(appt.status);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
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
                  Text(txName, style: AppTypography.labelLarge()),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr · $doctorName',
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                ],
              ),
              _buildTag(
                status,
                appt.status == 'COMPLETED' ? AppColors.sage : AppColors.rose,
                appt.status == 'COMPLETED'
                    ? AppColors.sage.withValues(alpha: 0.12)
                    : AppColors.bgRose,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductsTab() {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_productsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.rose),
            const SizedBox(height: 8),
            Text(_productsError!, style: AppTypography.bodySmall()),
            TextButton(onPressed: _loadProducts, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_patientProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.spa_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No Products Assigned',
              style: AppTypography.labelLarge(color: AppColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              'Prescribed skincare regimens and products will appear here.',
              style: AppTypography.bodySmall(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _patientProducts.length,
      itemBuilder: (context, index) {
        final item = _patientProducts[index];
        String brand = '';
        String type = '';
        String subtitle = '';

        if (item is Product) {
          brand = _humanizeEnum(item.brand);
          type = _humanizeEnum(item.productType);
          subtitle = item.category;
        } else if (item is Map<String, dynamic>) {
          brand = _humanizeEnum(item['brand']?.toString() ?? 'Clinic');
          type = _humanizeEnum(item['productType']?.toString() ?? 'Product');
          final startedOn = item['startedOn']?.toString();
          subtitle = startedOn != null
              ? 'Started on $startedOn'
              : (item['source']?.toString() ?? 'Clinic Prescription');
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgRose,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.spa, color: AppColors.rose, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$brand · $type', style: AppTypography.labelLarge()),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _humanizeEnum(String text) {
    if (text.isEmpty) return text;
    final words = text.replaceAll('_', ' ').split(' ');
    return words
        .map((w) {
          if (w.isEmpty) return w;
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
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
