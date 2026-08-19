import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/core/theme/app_colors.dart';
import 'package:beauty_clinic_app/core/theme/app_theme.dart';
import 'package:beauty_clinic_app/core/widgets/floating_petals.dart';
import 'package:beauty_clinic_app/features/shell/presentation/app_shell.dart';
import 'package:beauty_clinic_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:beauty_clinic_app/features/doctor_profile/presentation/doctor_profile_screen.dart';
import 'package:beauty_clinic_app/features/patient_profile/presentation/patient_profile_screen.dart';
import 'package:beauty_clinic_app/features/user_profile/presentation/user_profile_screen.dart';
import 'package:beauty_clinic_app/features/activity_log/presentation/activity_log_screen.dart';
import 'package:beauty_clinic_app/features/landing/presentation/landing_screen.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/clinic_time.dart';
import 'package:beauty_clinic_app/features/appointments/data/doctor_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/treatment_api.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/appointments_screen.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/booking_flow_sheet.dart';
import 'package:beauty_clinic_app/features/chat/data/chat_api.dart';
import 'package:beauty_clinic_app/features/chat/presentation/chat_launcher.dart';
import 'package:beauty_clinic_app/features/forms/data/clinical_intake_api.dart';
import 'package:beauty_clinic_app/features/forms/data/clinical_intake_schema.dart';
import 'package:beauty_clinic_app/features/forms/data/dynamic_form_api.dart';
import 'package:beauty_clinic_app/features/forms/presentation/admin_clinical_intake_screen.dart';
import 'package:beauty_clinic_app/features/forms/presentation/form_builder_admin_screen.dart';
import 'package:beauty_clinic_app/features/patients/presentation/patients_directory_screen.dart';
import 'package:beauty_clinic_app/features/products/data/product_api.dart';
import 'package:beauty_clinic_app/features/products/presentation/product_catalog_screen.dart';
import 'package:beauty_clinic_app/features/staff_management/staff_management_screen.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:beauty_clinic_app/routing/app_routes.dart';
import 'package:beauty_clinic_app/screens/login_screen.dart';
import 'package:beauty_clinic_app/screens/register_screen.dart';

// Root widget; owns the session and router.
class BeautyClinicApp extends StatefulWidget {
  const BeautyClinicApp({super.key, this.authSession});

  // Injectable for tests; production owns its own.
  final AuthSession? authSession;

  @override
  State<BeautyClinicApp> createState() => _BeautyClinicAppState();
}

class _BeautyClinicAppState extends State<BeautyClinicApp> {
  late final AuthSession _session;
  late final bool _ownsSession;
  late final GoRouter _router;

  late final ApiClient _apiClient;
  late final ProductApi _products;
  late final TreatmentApi _treatmentApi;
  late final AppointmentApi _appointmentApi;
  late final DoctorApi _doctorApi;
  late final ClinicalIntakeApi _clinicalApi;
  late final DynamicFormApi _dynamicApi;
  late final ChatApi _chatApi;

  // Ticks so the list reloads without remounting.
  final ValueNotifier<int> _visitsChanged = ValueNotifier<int>(0);

  // Carries a just-booked visit over.
  final ValueNotifier<Appointment?> _bookedSignal = ValueNotifier<Appointment?>(
    null,
  );

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.authSession == null;
    _session = widget.authSession ?? AuthSession.production();

    _apiClient = ApiClient(_session);
    _products = ProductApi(_apiClient);
    _treatmentApi = TreatmentApi(_apiClient);
    _appointmentApi = AppointmentApi(_apiClient);
    _doctorApi = DoctorApi(_apiClient);
    _clinicalApi = ClinicalIntakeApi(_apiClient);
    _dynamicApi = DynamicFormApi(_apiClient);
    _chatApi = ChatApi(_apiClient);

    _router = _createRouter();
    _session.initialize();
  }

  @override
  void dispose() {
    _router.dispose();
    _bookedSignal.dispose();
    _visitsChanged.dispose();
    _apiClient.close();
    if (_ownsSession) {
      _session.dispose();
    }
    // Covers every session ending.
    ClinicTime.reset();
    super.dispose();
  }

  // Shell roles are lowercase, wire names upper.
  String get _activeRole => _session.role?.wireName.toLowerCase() ?? 'admin';

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beauty & Derma Clinic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }

  GoRouter _createRouter() {
    return GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: _session,
      redirect: _redirect,
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (_, _) =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, _) => LoginScreen(
            authSession: _session,
            onRegister: () => context.go(AppRoutes.register),
          ),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, _) => RegisterScreen(
            authSession: _session,
            onSignIn: () => context.go(AppRoutes.login),
          ),
        ),
        ShellRoute(builder: _buildShell, routes: _viewRoutes()),
      ],
    );
  }

  // Survives the splash so a refresh returns.
  String? _pendingLocation;

  // Auth decides the page before views.
  String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.uri.path;

    switch (_session.status) {
      case AuthStatus.initializing:
        if (location == AppRoutes.splash) return null;
        _pendingLocation = state.uri.toString();
        return AppRoutes.splash;

      case AuthStatus.unauthenticated:
        final onAuthPage =
            location == AppRoutes.login || location == AppRoutes.register;
        return onAuthPage ? null : AppRoutes.login;

      case AuthStatus.authenticated:
        return _authenticatedRedirect(location);
    }
  }

  String? _authenticatedRedirect(String location) {
    final resumed = _takePendingLocation();
    if (resumed != null) return resumed;

    final view = AppRoutes.viewForLocation(location);
    if (view == null || !AppRoutes.allows(_activeRole, view)) {
      return AppRoutes.home;
    }
    return null;
  }

  // Consumed once, so the redirect cannot loop.
  String? _takePendingLocation() {
    final pending = _pendingLocation;
    _pendingLocation = null;

    if (pending == null || AppRoutes.viewForLocation(pending) != null) {
      return pending;
    }

    final path = Uri.parse(pending).path;
    return AppRoutes.viewForLocation(path) == null ? null : pending;
  }

  // Routes, guard and menu share one list.
  List<RouteBase> _viewRoutes() {
    final routes = <RouteBase>[
      GoRoute(
        path: AppRoutes.patientDetailPattern,
        builder: _patientDetail,
      ),
    ];

    for (final route in AppRoutes.all) {
      routes.add(GoRoute(path: route.path, builder: _builderFor(route.id)));
    }

    return routes;
  }

  GoRouterWidgetBuilder _builderFor(String id) {
    return switch (id) {
      'dashboard' => (_, _) => _dashboardOrVisits(),
      'appointments' => (_, _) => _dashboardOrVisits(),
      'doctors' => (_, _) => _dashboard(),
      'patients' => (context, _) => PatientsDirectoryScreen(
        key: const ValueKey('patients_directory'),
        clinicalApi: _clinicalApi,
        onSelectPatient: (patientId) =>
            context.go(AppRoutes.patientDetail(patientId)),
      ),
      'clinical_forms' => (_, _) => AdminClinicalIntakeScreen(api: _clinicalApi),
      'form_builder' => (_, _) => FormBuilderAdminScreen(api: _dynamicApi),
      'products' => (_, _) => ProductCatalogScreen(
        key: const ValueKey('products'),
        api: _products,
        canManage: _session.role == Role.admin,
      ),
      'staff_management' => (_, _) => StaffManagementScreen(
        key: const ValueKey('staff_management'),
        apiClient: _apiClient,
        authSession: _session,
      ),
      'activity_log' => (_, _) => ActivityLogScreen(
        key: const ValueKey('activity_log'),
        authSession: _session,
      ),
      'doctor_profile' => (context, _) => DoctorProfileScreen(
        key: const ValueKey('doctor_profile'),
        onBack: () => context.go(AppRoutes.home),
        onPatientClick: (patientId) =>
            context.go(AppRoutes.patientDetail(patientId)),
      ),
      'patient_profile' => _ownClinicalProfile,
      'my_profile' => (context, _) => UserProfileScreen(
        key: const ValueKey('my_profile'),
        role: _session.role ?? Role.patient,
        apiClient: _apiClient,
        onBack: () => context.go(AppRoutes.home),
      ),
      // Consultations has no screen yet.
      'landing' || 'consultations' => (context, _) => _landing(context),
      _ => throw StateError('No builder for route "$id"'),
    };
  }

  Widget _buildShell(BuildContext context, GoRouterState state, Widget child) {
    final view = AppRoutes.viewForLocation(state.uri.path) ?? 'dashboard';

    return AppShell(
      activeRole: _activeRole,
      activeView: view,
      onViewChanged: (next) => _onViewChanged(context, next),
      onProfileTap: () => context.go(AppRoutes.myProfile),
      // Booking lives in chat, not the header.
      onLogout: _logout,
      child: _withChat(
        Stack(
          children: [
            const FloatingPetals(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  void _onViewChanged(BuildContext context, String view) {
    // Book opens the sheet, not a view.
    if (view == 'book') {
      _openBookingModal(context);
      return;
    }

    if (!AppRoutes.allows(_activeRole, view)) return;

    final location = AppRoutes.locationForView(view);
    if (location != null) {
      context.go(location);
    }
  }

  // Patients get their own list.
  Widget _dashboardOrVisits() {
    if (_activeRole != 'patient') {
      return _dashboard();
    }

    return Builder(
      builder: (context) => AppointmentsScreen(
        key: const ValueKey('my_appointments'),
        appointmentApi: _appointmentApi,
        treatmentApi: _treatmentApi,
        doctorApi: _doctorApi,
        bookedSignal: _bookedSignal,
        refreshSignal: _visitsChanged,
        clinicalApi: _clinicalApi,
        onNavigateToForms: () => context.go(
          AppRoutes.ownProfileFromBooking(
            PatientProfileScreen.clinicFormsTabIndex,
          ),
        ),
      ),
    );
  }

  Widget _landing(BuildContext context) {
    return LandingScreen(
      key: const ValueKey('landing'),
      onBookClick: () => _openBookingModal(context),
      onViewDoctor: (_) => context.go(AppRoutes.doctorProfile),
    );
  }

  Widget _dashboard() {
    return Builder(
      builder: (context) => DashboardScreen(
        key: ValueKey('dashboard_$_activeRole'),
        activeRole: _activeRole,
        onViewPatient: (patientId) =>
            context.go(AppRoutes.patientDetail(patientId)),
        onViewDoctor: (_) => context.go(AppRoutes.doctorProfile),
        apiClient: _apiClient,
      ),
    );
  }

  Widget _patientDetail(BuildContext context, GoRouterState state) {
    final patientId = state.pathParameters['id'];

    return PatientProfileScreen(
      key: ValueKey('admin_patient_$patientId'),
      patientId: patientId,
      clinicalApi: _clinicalApi,
      dynamicApi: _dynamicApi,
      appointmentApi: _appointmentApi,
      productApi: _products,
      apiClient: _apiClient,
      onBack: () => context.go(AppRoutes.patients),
    );
  }

  Widget _ownClinicalProfile(BuildContext context, GoRouterState state) {
    final tabIndex = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
    final fromBooking = state.uri.queryParameters['from'] == 'booking';

    return PatientProfileScreen(
      key: ValueKey('patient_profile_${tabIndex}_$fromBooking'),
      clinicalApi: _clinicalApi,
      dynamicApi: _dynamicApi,
      appointmentApi: _appointmentApi,
      productApi: _products,
      apiClient: _apiClient,
      initialTabIndex: tabIndex,
      // Home is visits for patients.
      onBackToAppointments: fromBooking
          ? () => context.go(AppRoutes.home)
          : null,
      onBack: () => context.go(AppRoutes.home),
    );
  }

  // Patients only; staff never see it.
  Widget _withChat(Widget page) {
    if (_activeRole != 'patient') {
      return page;
    }
    return ChatLauncher(
      api: _chatApi,
      onVisitsChanged: _afterChatWrite,
      child: page,
    );
  }

  // Quiet reload, so the chat stays open.
  void _afterChatWrite() {
    _visitsChanged.value++;
  }

  Future<void> _logout() async {
    try {
      await _session.logout();
    } on AuthException {
      // Cleared locally; the router returns to login.
    }
  }

  Future<void> _openBookingModal(BuildContext context) async {
    if (_activeRole == 'patient') {
      try {
        final data = await _clinicalApi.fetchOwn();
        final isComplete = ClinicalIntakeSchema.isComplete(data);
        if (!context.mounted) return;

        if (!isComplete) {
          await _formRequiredDialog(context);
          return;
        }

        final action = await _formVerifiedDialog(context);
        if (action != 'proceed') return;
      } catch (_) {
        // Fallback gracefully on network error.
      }
    }

    if (!context.mounted) return;
    showDialog<bool>(
      context: context,
      builder: (context) => BookingFlowSheet(
        treatmentApi: _treatmentApi,
        appointmentApi: _appointmentApi,
        doctorApi: _doctorApi,
        // Hands the new visit over.
        onBooked: (appointment) => _bookedSignal.value = appointment,
      ),
    );
  }

  // Booking stops here until the form exists.
  Future<void> _formRequiredDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.assignment_late_outlined,
                color: AppColors.rose,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Clinical Form Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'Please complete your clinical health & intake form before booking an appointment. '
          'Our medical team requires this information to ensure your treatment is safe and tailored to you.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSub,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _goToClinicForms(ctx);
            },
            child: const Text('Fill Clinical Form'),
          ),
        ],
      ),
    );
  }

  // Complete form still offers a last review.
  Future<String?> _formVerifiedDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.assignment_turned_in_outlined,
                color: AppColors.sage,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Clinical Form Verified',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your clinical intake form has been completed and verified. Would you like to continue with booking, or review and update your health details first?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSub,
            height: 1.4,
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop('modify');
              _goToClinicForms(ctx);
            },
            child: const Text('Review / Modify Form'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop('proceed'),
            child: const Text('Continue to Booking'),
          ),
        ],
      ),
    );
  }

  void _goToClinicForms(BuildContext context) {
    context.go(
      AppRoutes.ownProfileFromBooking(
        PatientProfileScreen.clinicFormsTabIndex,
      ),
    );
  }
}
