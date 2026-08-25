import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:beauty_clinic_app/core/widgets/profile_avatar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../network/api_client.dart';
import '../../appointments/data/appointment.dart';
import '../../appointments/data/appointment_api.dart';
import '../../appointments/presentation/booking_format.dart';
import '../../forms/data/clinical_intake_api.dart';
import '../../forms/data/dynamic_form_api.dart';
import '../../products/data/product.dart';
import '../../products/data/product_api.dart';
import '../data/session_record_api.dart';
import '../data/session_record.dart';
import 'widgets/clinical_intake_tab.dart';

/// Patient EHR and profile view.
class PatientProfileScreen extends StatefulWidget {
  static const int overviewTabIndex = 0;
  static const int productsTabIndex = 0;
  static const int clinicFormsTabIndex = 1;

  final VoidCallback? onBack;
  final VoidCallback? onBackToAppointments;
  final VoidCallback? onOpenVisits;
  final ClinicalIntakeApi clinicalApi;
  final DynamicFormApi dynamicApi;
  final AppointmentApi? appointmentApi;
  final ProductApi? productApi;
  final ApiClient? apiClient;
  final String? patientId;
  final int initialTabIndex;
  final bool canManageProducts;
  final bool canChooseOwnProducts;
  final bool canAuthorSessionRecords;
  final String? doctorUserId;

  const PatientProfileScreen({
    super.key,
    this.onBack,
    this.onBackToAppointments,
    this.onOpenVisits,
    required this.clinicalApi,
    required this.dynamicApi,
    this.appointmentApi,
    this.productApi,
    this.apiClient,
    this.patientId,
    this.initialTabIndex = 0,
    this.canManageProducts = false,
    this.canChooseOwnProducts = false,
    this.canAuthorSessionRecords = false,
    this.doctorUserId,
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
  List<Appointment> _upcomingTreatments = [];
  bool _loadingHistory = false;
  String? _historyError;
  List<SessionRecord> _sessionRecords = [];
  List<Appointment> _todayAppointments = [];
  bool _loadingTodayAppointments = false;

  String _productFilter = 'ALL';
  List<dynamic> _patientProducts = [];
  List<Product> _prescribedProducts = [];
  bool _loadingProducts = false;
  String? _productsError;

  bool get _isOwnProfile => widget.patientId == null;

  bool _isAssignedDoctor(AppointmentSession session) {
    return widget.doctorUserId == null ||
        session.practitionerUserId == widget.doctorUserId;
  }

  @override
  void initState() {
    super.initState();
    final tabCount = _isOwnProfile ? 2 : 4;
    final resolvedInitialIndex = widget.initialTabIndex.clamp(0, tabCount - 1);

    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: resolvedInitialIndex,
    );
    _loadPatientData();
    _loadUpcomingTreatments();
    _loadTreatmentHistory();
    _loadSessionRecords();
    _loadTodayAppointments();
    _loadProducts();
  }

  Future<void> _loadUpcomingTreatments() async {
    if (widget.appointmentApi == null || widget.patientId != null) return;
    try {
      final page = await widget.appointmentApi!.upcoming(page: 0, size: 50);
      if (!mounted) return;
      setState(() => _upcomingTreatments = page.items);
    } catch (_) {
      // Tile falls back to "None booked".
    }
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
      _loadSessionRecords();
      _loadProducts();
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

  Future<void> _loadSessionRecords() async {
    final patientId = widget.patientId ?? _patientData?['id']?.toString();
    final apiClient = widget.apiClient;
    if (patientId == null || apiClient == null) return;
    try {
      final records = await SessionRecordApi(
        apiClient,
      ).listForPatient(patientId);
      if (!mounted) return;
      setState(() => _sessionRecords = records);
    } catch (_) {
      // History stays useful without records.
    }
  }

  Future<void> _loadTodayAppointments() async {
    final patientId = widget.patientId;
    final apiClient = widget.apiClient;
    if (patientId == null || apiClient == null) return;
    setState(() => _loadingTodayAppointments = true);
    try {
      final responses = await Future.wait([
        apiClient.get<Map<String, dynamic>>(
          '/api/appointments/patients/$patientId/upcoming',
          queryParameters: {'page': 0, 'size': 50},
        ),
        apiClient.get<Map<String, dynamic>>(
          '/api/appointments/patients/$patientId/history',
          queryParameters: {'page': 0, 'size': 50},
        ),
      ]);
      final all = [
        ...AppointmentPage.fromJson(responses[0].data!).items,
        ...AppointmentPage.fromJson(responses[1].data!).items,
      ];
      final now = DateTime.now();
      final today = <Appointment>[];
      for (final appointment in all) {
        final date = appointment.scheduledAt.toLocal();
        if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day &&
            today.every((item) => item.id != appointment.id)) {
          today.add(appointment);
        }
      }
      if (!mounted) return;
      setState(() {
        _todayAppointments = today;
        _loadingTodayAppointments = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTodayAppointments = false);
    }
  }

  Widget _buildTodayAppointmentsTab() {
    if (_loadingTodayAppointments) {
      return const SkeletonList(itemCount: 3);
    }
    if (_todayAppointments.isEmpty) {
      return Center(
        child: Text(
          'No appointments scheduled for today.',
          style: AppTypography.bodySmall(color: AppColors.textMuted),
        ),
      );
    }
    return ListView(
      children: [
        Text('Today\'s Appointments', style: AppTypography.labelLarge()),
        const SizedBox(height: 12),
        for (final appointment in _todayAppointments)
          for (final session in appointment.sessions)
            if (session.status != 'CANCELLED' && session.status != 'NO_SHOW')
              _todaySessionTile(appointment, session),
      ],
    );
  }

  Widget _todaySessionTile(
    Appointment appointment,
    AppointmentSession session,
  ) {
    final record = _sessionRecords.cast<SessionRecord?>().firstWhere(
      (item) => item?.sessionId == session.id,
      orElse: () => null,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: session.status == 'COMPLETED'
                      ? AppColors.sagePale
                      : AppColors.bgRose,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  session.status == 'COMPLETED'
                      ? Icons.check_circle_outline
                      : Icons.spa_outlined,
                  color: session.status == 'COMPLETED'
                      ? AppColors.sage
                      : AppColors.rose,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.treatmentLabel,
                      style: AppTypography.labelLarge(),
                    ),
                    Text(
                      '${BookingFormat.time12(session.startTime)} · ${session.practitionerName}',
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTag(
                session.status == 'COMPLETED' ? 'Completed' : 'Scheduled',
                session.status == 'COMPLETED' ? AppColors.sage : AppColors.rose,
                session.status == 'COMPLETED'
                    ? AppColors.sagePale
                    : AppColors.bgRose,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.canAuthorSessionRecords &&
              _isAssignedDoctor(session) &&
              record == null &&
              session.status == 'COMPLETED')
            FilledButton.icon(
              onPressed: () => _openSessionRecord(session),
              icon: const Icon(Icons.note_add_outlined, size: 16),
              label: const Text('Add session record'),
            )
          else if (record != null &&
              (widget.canAuthorSessionRecords && _isAssignedDoctor(session)))
            OutlinedButton.icon(
              onPressed: () => _openSessionRecord(session, record: record),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('View / edit session record'),
            ),
        ],
      ),
    );
  }

  Future<void> _openSessionRecord(
    AppointmentSession session, {
    SessionRecord? record,
  }) async {
    final patientId = widget.patientId;
    final productApi = widget.productApi;
    final apiClient = widget.apiClient;
    if (patientId == null || productApi == null || apiClient == null) return;

    try {
      final catalog = await productApi.list();
      if (!mounted) return;
      final input = await showDialog<_SessionRecordInput>(
        context: context,
        builder: (_) => _SessionRecordDialog(
          session: session,
          catalog: catalog,
          initial: record,
        ),
      );
      if (input == null) return;

      final recordsApi = SessionRecordApi(apiClient);
      if (record == null) {
        await recordsApi.create(
          patientId: patientId,
          sessionId: session.id,
          note: input.note,
          skinReaction: input.skinReaction,
          followUpDate: input.followUpDate,
          prescribedProductIds: input.prescribedProductIds,
        );
      } else {
        await recordsApi.amend(
          patientId: patientId,
          recordId: record.id,
          note: input.note,
          skinReaction: input.skinReaction,
          followUpDate: input.followUpDate,
          prescribedProductIds: input.prescribedProductIds,
        );
      }
      await _loadSessionRecords();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Session record saved.')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the session record.')),
      );
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });

    try {
      final targetId = widget.patientId ?? _patientData?['id']?.toString();
      if (widget.productApi != null && targetId != null) {
        final results = await Future.wait([
          widget.productApi!.listForPatient(targetId),
          widget.productApi!.prescribedForPatient(targetId),
        ]);
        if (!mounted) return;
        setState(() {
          _patientProducts = results[0] as List<PatientProductRecord>;
          _prescribedProducts = results[1] as List<Product>;
          _loadingProducts = false;
        });
      } else {
        setState(() => _loadingProducts = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productsError = 'Could not load product records.';
        _loadingProducts = false;
      });
    }
  }

  Future<void> _addPatientProduct() async {
    final targetId = widget.patientId ?? _patientData?['id']?.toString();
    final productApi = widget.productApi;
    if ((!widget.canManageProducts && !widget.canChooseOwnProducts) ||
        targetId == null ||
        productApi == null) {
      return;
    }
    final catalog = await productApi.list();
    if (!mounted) return;
    final selection = await showDialog<({Product product, String source})>(
      context: context,
      builder: (context) => _ProductAssignmentDialog(
        catalog: catalog,
        ownProductsOnly:
            widget.canChooseOwnProducts && !widget.canManageProducts,
      ),
    );
    if (selection == null) return;
    try {
      await productApi.addForPatient(
        targetId,
        productId: selection.product.id,
        source: selection.source,
        startedOn: DateTime.now().toIso8601String().split('T').first,
      );
      _loadProducts();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not assign product.')),
        );
      }
    }
  }

  Future<void> _discontinuePatientProduct(PatientProductRecord item) async {
    final targetId = widget.patientId ?? _patientData?['id']?.toString();
    final productApi = widget.productApi;
    if ((!widget.canManageProducts && !widget.canChooseOwnProducts) ||
        targetId == null ||
        productApi == null) {
      return;
    }
    try {
      await productApi.discontinueForPatient(targetId, item.id);
      _loadProducts();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not discontinue product.')),
        );
      }
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
      return const SkeletonDetail();
    }

    // Only the open tab scrolls.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient Header (100% database driven)
          if (_isOwnProfile) ...[
            _buildIdentityStrip(),
            const SizedBox(height: 10),
            _buildSummaryTiles(),
          ] else
            _buildPatientHeader(),

          const SizedBox(height: 12),

          if (_isOwnProfile)
            Expanded(child: _buildOwnSections())
          else ...[
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.rose,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.rose,
              labelStyle: AppTypography.labelMedium(),
              unselectedLabelStyle: AppTypography.labelMedium(),
              tabs: const [
                Tab(text: 'Today\'s Appointments'),
                Tab(text: 'Overview & Info'),
                Tab(text: 'Treatment History'),
                Tab(text: 'Prescriptions & Products'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTodayAppointmentsTab(),
                  _buildOverviewTab(),
                  _buildHistoryTab(),
                  buildProductsTab(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Two panes side by side, like Treatments.
  Widget _buildOwnSections() {
    final products = _pane(
      'PRESCRIPTIONS & PRODUCTS',
      '${_patientProducts.whereType<PatientProductRecord>().where((item) => item.discontinuedOn == null).length} active',
      buildProductsTab(),
    );
    final forms = _pane(
      'CLINIC FORMS',
      null,
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              const SizedBox(height: 4),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.rose,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.rose,
                labelStyle: AppTypography.labelMedium(),
                unselectedLabelStyle: AppTypography.labelMedium(),
                tabs: const [
                  Tab(text: 'Products'),
                  Tab(text: 'Clinic Forms'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [products, forms],
                ),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: products),
            const SizedBox(width: 28),
            Expanded(child: forms),
          ],
        );
      },
    );
  }

  /// Label, count, hairline, then the body.
  Widget _pane(String label, String? count, Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppTypography.labelSmall()),
            if (count != null) ...[
              const SizedBox(width: 8),
              Text(
                count,
                style: AppTypography.labelSmall(color: AppColors.textSub),
              ),
            ],
            const SizedBox(width: 12),
            Expanded(child: Container(height: 1, color: AppColors.hairline)),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(child: body),
      ],
    );
  }

  /// One-line identity, own profile only.
  Widget _buildIdentityStrip() {
    final firstName = _patientData?['firstName']?.toString() ?? '';
    final lastName = _patientData?['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final skinType = _patientData?['skinType']?.toString();
    final isPregnant = _patientData?['pregnantBreastfeeding'] == true;

    return Row(
      children: [
        ProfileAvatar(
          radius: 15,
          color: AppColors.rose,
          imageUrl: _patientData?['imageUrl']?.toString(),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            fullName.isNotEmpty ? fullName : 'My Medical Profile',
            style: AppTypography.displaySubtitle().copyWith(fontSize: 17),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (skinType != null && skinType.isNotEmpty) ...[
          const SizedBox(width: 10),
          _buildTag(
            'Skin: ${_humanizeEnum(skinType)}',
            AppColors.rose,
            AppColors.bgRose,
          ),
        ],
        if (isPregnant) ...[
          const SizedBox(width: 8),
          _buildTag(
            'Pregnant / Nursing',
            const Color(0xFFDC2626),
            const Color(0xFFFEF2F2),
          ),
        ],
      ],
    );
  }

  /// Next visit, sessions done, form state.
  Widget _buildSummaryTiles() {
    final next = _nextPlannedSession();
    final completed = _treatmentHistory
        .where((appointment) => _historyStatus(appointment) == 'COMPLETED')
        .length;
    final active = _patientProducts
        .whereType<PatientProductRecord>()
        .where((item) => item.discontinuedOn == null)
        .length;

    return Row(
      children: [
        Expanded(
          child: _summaryTile(
            'NEXT VISIT',
            next == null
                ? 'None booked'
                : BookingFormat.dayWithYear(next.startTime),
            next == null
                ? 'Open Treatments & Visits'
                : '${BookingFormat.time12(next.startTime)} · ${_humanizeEnum(next.treatmentName)}',
            AppColors.rosePale,
            onTap: widget.onOpenVisits,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryTile(
            'SESSIONS DONE',
            '$completed',
            completed == 0 ? 'No visits yet' : 'Across your treatment plan',
            AppColors.lavPale,
            onTap: widget.onOpenVisits,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryTile(
            'MY PRODUCTS',
            '$active',
            active == 0 ? 'Nothing prescribed yet' : 'In your current routine',
            AppColors.sagePale,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile(
    String label,
    String value,
    String hint,
    Color color, {
    VoidCallback? onTap,
  }) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelSmall().copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.displayStat().copyWith(fontSize: 16),
          ),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall(
              color: AppColors.textSub,
            ).copyWith(fontSize: 11),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return tile;
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: tile,
      ),
    );
  }

  AppointmentSession? _nextPlannedSession() {
    final sessions = <AppointmentSession>[
      for (final appointment in _upcomingTreatments)
        ...appointment.sessions.where((session) => session.isPlanned),
    ]..sort((a, b) => a.startTime.compareTo(b.startTime));
    return sessions.isEmpty ? null : sessions.first;
  }

  Widget _buildPatientHeader() {
    final firstName = _patientData?['firstName']?.toString() ?? '';
    final lastName = _patientData?['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final displayName = fullName.isNotEmpty ? fullName : 'Patient Profile';

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
          ProfileAvatar(
            radius: 36,
            color: AppColors.rose,
            imageUrl: _patientData?['imageUrl']?.toString(),
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
      return const SkeletonList();
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

    final filteredHistory = _treatmentHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: filteredHistory.isEmpty
              ? Center(
                  child: Text(
                    'No visits match this status.',
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredHistory.length,
                  itemBuilder: (context, index) {
                    final appt = filteredHistory[index];
                    final firstSession = appt.sessions.isNotEmpty
                        ? appt.sessions.first
                        : null;
                    final txName = firstSession != null
                        ? _humanizeEnum(firstSession.treatmentName)
                        : 'Treatment Visit';
                    final doctorName =
                        firstSession?.practitionerName ?? 'Clinic Specialist';
                    final dateStr = firstSession != null
                        ? '${BookingFormat.dayWithYear(firstSession.startTime)} · ${BookingFormat.time12(firstSession.startTime)}'
                        : BookingFormat.dayWithYear(appt.scheduledAt);
                    final status = _historyStatus(appt);
                    final sessionRecords = appt.sessions
                        .map((session) {
                          final record = _sessionRecords
                              .cast<SessionRecord?>()
                              .firstWhere(
                                (item) => item?.sessionId == session.id,
                                orElse: () => null,
                              );
                          return (session: session, record: record);
                        })
                        .where((entry) => entry.record != null)
                        .toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      txName,
                                      style: AppTypography.labelLarge(),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$dateStr · $doctorName',
                                      style: AppTypography.bodySmall(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildTag(
                                status,
                                status == 'COMPLETED'
                                    ? AppColors.sage
                                    : AppColors.rose,
                                status == 'COMPLETED'
                                    ? AppColors.sage.withValues(alpha: 0.12)
                                    : AppColors.bgRose,
                              ),
                            ],
                          ),
                          if (widget.canAuthorSessionRecords &&
                              firstSession != null &&
                              _isAssignedDoctor(firstSession))
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final session in appt.sessions)
                                    if (session.status == 'COMPLETED')
                                      FilledButton.icon(
                                        onPressed: () =>
                                            _openSessionRecord(session),
                                        icon: const Icon(
                                          Icons.note_add_outlined,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Complete session record',
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          if (sessionRecords.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            for (final entry in sessionRecords)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgAlt,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Session record · ${entry.record!.createdAt.toLocal().toIso8601String().split('T').first}',
                                        style: AppTypography.labelMedium(),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (entry.record!.note == null ||
                                                entry.record!.note!
                                                    .trim()
                                                    .isEmpty)
                                            ? 'No clinical note added.'
                                            : entry.record!.note!,
                                        style: AppTypography.bodySmall(),
                                      ),
                                      if (entry.record!.skinReaction != null &&
                                          entry.record!.skinReaction != 'NONE')
                                        Text(
                                          'Skin reaction: ${_humanizeEnum(entry.record!.skinReaction!)}',
                                          style: AppTypography.bodySmall(
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      if (entry.record!.followUpDate != null)
                                        Text(
                                          'Follow-up: ${entry.record!.followUpDate}',
                                          style: AppTypography.bodySmall(
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      if (entry
                                          .record!
                                          .prescribedProductIds
                                          .isNotEmpty)
                                        Text(
                                          'Prescribed products: ${entry.record!.prescribedProductIds.map((id) {
                                            final product = _prescribedProducts.firstWhere(
                                              (item) => item.id == id,
                                              orElse: () => Product(id: id, name: 'Unknown', brand: 'Unknown', productType: 'PRODUCT', stockQuantity: 0, ingredients: const []),
                                            );
                                            return '${product.brandLabel} ${product.typeLabel}';
                                          }).join(', ')}',
                                          style: AppTypography.bodySmall(
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _historyStatus(Appointment appointment) {
    if (appointment.status == 'CANCELLED') return 'CANCELLED';

    if (appointment.sessions.isEmpty) return 'PENDING';

    final sessions = appointment.sessions;
    if (sessions.every((s) => s.status == 'COMPLETED')) return 'COMPLETED';
    if (sessions.every((s) => s.status == 'CANCELLED')) return 'CANCELLED';
    if (sessions.every((s) => s.status == 'NO_SHOW')) return 'MISSED';

    final hasAnyCancelled = sessions.any(
      (session) => session.status == 'CANCELLED',
    );
    final hasAnyCompleted = sessions.any(
      (session) => session.status == 'COMPLETED',
    );
    final hasAnyPlanned = sessions.any((session) => session.isPlanned);
    final hasAnyNoShow = sessions.any((session) => session.status == 'NO_SHOW');

    if (hasAnyCompleted && !hasAnyPlanned) {
      return 'COMPLETED';
    }
    if (hasAnyCancelled && !hasAnyCompleted && !hasAnyPlanned) {
      return 'CANCELLED';
    }
    if (hasAnyNoShow && !hasAnyCompleted && !hasAnyPlanned) {
      return 'MISSED';
    }
    return 'PENDING';
  }

  Widget buildProductsTab() {
    if (_loadingProducts) {
      return const SkeletonList();
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

    final routine = _patientProducts.whereType<PatientProductRecord>().toList();
    if (routine.isEmpty && _prescribedProducts.isEmpty) {
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
              'Products prescribed or added to the patient routine will appear here.',
              style: AppTypography.bodySmall(color: AppColors.textMuted),
            ),
            if (widget.canChooseOwnProducts || widget.canManageProducts) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _addPatientProduct,
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  widget.canChooseOwnProducts && !widget.canManageProducts
                      ? 'Add current product'
                      : 'Assign product',
                ),
              ),
            ],
          ],
        ),
      );
    }

    final ownRoutine = routine
        .where((item) => item.source != 'PRESCRIBED')
        .toList();
    final prescribedRoutine = routine
        .where((item) => item.source == 'PRESCRIBED')
        .toList();
    final prescribedCount =
        _prescribedProducts.length + prescribedRoutine.length;
    final showPrescribed = _productFilter != 'OWN';
    final showOwn = _productFilter != 'PRESCRIBED';

    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _productFilterChip(
                    'ALL',
                    'All ${prescribedCount + ownRoutine.length}',
                  ),
                  _productFilterChip(
                    'PRESCRIBED',
                    'Prescribed $prescribedCount',
                  ),
                  _productFilterChip(
                    'OWN',
                    _isOwnProfile
                        ? 'Mine ${ownRoutine.length}'
                        : 'Patient\'s own ${ownRoutine.length}',
                  ),
                ],
              ),
            ),
            if (widget.canManageProducts || widget.canChooseOwnProducts) ...[
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _addPatientProduct,
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  widget.canChooseOwnProducts && !widget.canManageProducts
                      ? 'Add product'
                      : 'Assign product',
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (showPrescribed)
          _productGroup(
            title: _isOwnProfile
                ? 'From your doctor'
                : 'Prescribed by the clinic',
            icon: Icons.medical_services_outlined,
            accent: AppColors.roseDark,
            background: AppColors.bgRose,
            border: AppColors.borderRose,
            count: prescribedCount,
            emptyText: 'Nothing prescribed yet.',
            children: [
              ..._prescribedProducts.map(
                (product) => _productTile(
                  '${_humanizeEnum(product.brand)} · ${_humanizeEnum(product.productType)}',
                  product.name,
                ),
              ),
              ...prescribedRoutine.map(
                (item) => _productTile(
                  '${_humanizeEnum(item.brand)} · ${_humanizeEnum(item.productType)}',
                  item.startedOn == null
                      ? 'In the routine'
                      : 'Started ${item.startedOn}',
                  trailing: _routineTrailing(item),
                ),
              ),
            ],
          ),
        if (showPrescribed && showOwn) const SizedBox(height: 14),
        if (showOwn)
          _productGroup(
            title: _isOwnProfile ? 'Added by you' : 'Patient\'s own products',
            icon: Icons.person_outline,
            accent: AppColors.lavDark,
            background: AppColors.bgCard,
            border: AppColors.border,
            count: ownRoutine.length,
            emptyText: _isOwnProfile
                ? 'You have not added anything.'
                : 'Nothing added by the patient.',
            children: ownRoutine
                .map(
                  (item) => _productTile(
                    '${_humanizeEnum(item.brand)} · ${_humanizeEnum(item.productType)}',
                    item.discontinuedOn != null
                        ? 'Stopped ${item.discontinuedOn}'
                        : item.startedOn == null
                        ? 'Not clinic advice'
                        : 'Started ${item.startedOn} · not clinic advice',
                    trailing: _routineTrailing(item),
                    dimmed: item.discontinuedOn != null,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget? _routineTrailing(PatientProductRecord item) {
    if (item.discontinuedOn != null) {
      return Text(
        'Stopped',
        style: AppTypography.labelSmall(color: AppColors.textMuted),
      );
    }
    if (widget.canManageProducts || widget.canChooseOwnProducts) {
      return TextButton(
        onPressed: () => _discontinuePatientProduct(item),
        child: const Text('Discontinue'),
      );
    }
    return null;
  }

  Widget _productFilterChip(String value, String label) {
    final selected = _productFilter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _productFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.rosePale : AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.rose : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style:
                AppTypography.labelSmall(
                  color: selected ? AppColors.roseDark : AppColors.textMuted,
                ).copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }

  /// Tinted panel, so the source reads instantly.
  Widget _productGroup({
    required String title,
    required IconData icon,
    required Color accent,
    required Color background,
    required Color border,
    required int count,
    required String emptyText,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelMedium(color: accent),
                ),
              ),
              Text(
                '$count',
                style: AppTypography.labelSmall(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                emptyText,
                style: AppTypography.bodySmall(color: AppColors.textMuted),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _productTile(
    String title,
    String subtitle, {
    Widget? trailing,
    bool dimmed = false,
  }) {
    return Opacity(
      opacity: dimmed ? .6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.bgAlt,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.spa_outlined,
                color: AppColors.textSub,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.labelLarge()),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
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

class _ProductAssignmentDialog extends StatefulWidget {
  const _ProductAssignmentDialog({
    required this.catalog,
    this.ownProductsOnly = false,
  });

  final List<Product> catalog;
  final bool ownProductsOnly;

  @override
  State<_ProductAssignmentDialog> createState() =>
      _ProductAssignmentDialogState();
}

class _ProductAssignmentDialogState extends State<_ProductAssignmentDialog> {
  Product? _selectedProduct;
  String _source = 'PRESCRIBED';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.ownProductsOnly
            ? 'Add current product'
            : 'Assign product to patient',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Product>(
              initialValue: _selectedProduct,
              decoration: const InputDecoration(labelText: 'Product'),
              items: widget.catalog
                  .map(
                    (product) => DropdownMenuItem(
                      value: product,
                      child: Text('${product.brandLabel} ${product.typeLabel}'),
                    ),
                  )
                  .toList(),
              onChanged: (product) =>
                  setState(() => _selectedProduct = product),
            ),
            const SizedBox(height: 12),
            if (widget.ownProductsOnly)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Source: Patient owned'),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _source,
                decoration: const InputDecoration(labelText: 'Source'),
                items: const [
                  DropdownMenuItem(
                    value: 'PRESCRIBED',
                    child: Text('Clinic prescribed'),
                  ),
                  DropdownMenuItem(
                    value: 'PATIENT_OWN',
                    child: Text('Patient owned'),
                  ),
                ],
                onChanged: (source) {
                  if (source != null) setState(() => _source = source);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedProduct == null
              ? null
              : () => Navigator.of(context).pop((
                  product: _selectedProduct!,
                  source: widget.ownProductsOnly ? 'PATIENT_OWN' : _source,
                )),
          child: Text(widget.ownProductsOnly ? 'Confirm' : 'Assign'),
        ),
      ],
    );
  }
}

class _SessionRecordInput {
  const _SessionRecordInput({
    required this.note,
    required this.skinReaction,
    required this.followUpDate,
    required this.prescribedProductIds,
  });

  final String? note;
  final String? skinReaction;
  final String? followUpDate;
  final List<String> prescribedProductIds;
}

class _SessionRecordDialog extends StatefulWidget {
  const _SessionRecordDialog({
    required this.session,
    required this.catalog,
    this.initial,
  });

  final AppointmentSession session;
  final List<Product> catalog;
  final SessionRecord? initial;

  @override
  State<_SessionRecordDialog> createState() => _SessionRecordDialogState();
}

class _SessionRecordDialogState extends State<_SessionRecordDialog> {
  late final TextEditingController _noteController;
  late final Set<String> _selectedProductIds;
  late String _skinReaction;
  DateTime? _followUpDate;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initial?.note ?? '');
    _selectedProductIds = {...?widget.initial?.prescribedProductIds};
    _skinReaction = widget.initial?.skinReaction ?? 'NONE';
    _followUpDate = widget.initial?.followUpDate == null
        ? null
        : DateTime.tryParse(widget.initial!.followUpDate!);
    _initialSnapshot = _snapshot();
  }

  late List<Object?> _initialSnapshot;

  List<Object?> _snapshot() => [
    _noteController.text,
    _skinReaction,
    _followUpDate,
    ..._selectedProductIds.toList()..sort(),
  ];

  bool get _isDirty => !listEquals(_snapshot(), _initialSnapshot);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    // A past follow-up would break the picker.
    final start = _followUpDate == null || _followUpDate!.isBefore(now)
        ? now
        : _followUpDate!;
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _followUpDate = picked);
  }

  void _submit() {
    Navigator.of(context).pop(
      _SessionRecordInput(
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        skinReaction: _skinReaction,
        followUpDate: _followUpDate?.toIso8601String().split('T').first,
        prescribedProductIds: _selectedProductIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Session record · ${widget.session.treatmentLabel}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _noteController,
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Clinical note',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _skinReaction,
                decoration: const InputDecoration(labelText: 'Skin reaction'),
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text('None')),
                  DropdownMenuItem(value: 'MILD', child: Text('Mild')),
                  DropdownMenuItem(value: 'MODERATE', child: Text('Moderate')),
                  DropdownMenuItem(value: 'SEVERE', child: Text('Severe')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _skinReaction = value);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickFollowUpDate,
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  _followUpDate == null
                      ? 'Add follow-up date'
                      : 'Follow-up: ${_followUpDate!.toIso8601String().split('T').first}',
                ),
              ),
              const SizedBox(height: 16),
              Text('Prescribe products', style: AppTypography.labelLarge()),
              if (widget.catalog.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No catalogue products available.',
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                )
              else
                ...widget.catalog.map(
                  (product) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _selectedProductIds.contains(product.id),
                    title: Text('${product.brandLabel} ${product.typeLabel}'),
                    subtitle: Text(product.name),
                    onChanged: (selected) => setState(() {
                      if (selected == true) {
                        _selectedProductIds.add(product.id);
                      } else {
                        _selectedProductIds.remove(product.id);
                      }
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _noteController,
          builder: (context, _) => FilledButton(
            onPressed: _isDirty ? _submit : null,
            child: const Text('Save session record'),
          ),
        ),
      ],
    );
  }
}
