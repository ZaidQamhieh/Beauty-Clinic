import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/core/theme/app_theme.dart';
import 'package:beauty_clinic_app/core/widgets/floating_petals.dart';
import 'package:beauty_clinic_app/core/widgets/skeleton.dart';
import 'package:beauty_clinic_app/features/shell/presentation/app_shell.dart';
import 'package:beauty_clinic_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:beauty_clinic_app/features/doctor_profile/presentation/doctor_profile_screen.dart';
import 'package:beauty_clinic_app/features/doctor_availability/data/doctor_availability_api.dart';
import 'package:beauty_clinic_app/features/doctor_availability/presentation/doctor_availability_screen.dart';
import 'package:beauty_clinic_app/features/doctor_directory/presentation/doctor_directory_screen.dart';
import 'package:beauty_clinic_app/features/patient_profile/presentation/patient_profile_screen.dart';
import 'package:beauty_clinic_app/features/patient_dashboard/presentation/patient_dashboard_screen.dart';
import 'package:beauty_clinic_app/features/user_profile/presentation/user_profile_screen.dart';
import 'package:beauty_clinic_app/features/user_profile/data/user_profile_api.dart';
import 'package:beauty_clinic_app/features/activity_log/presentation/activity_log_screen.dart';
import 'package:beauty_clinic_app/features/landing/presentation/landing_screen.dart';
import 'package:beauty_clinic_app/features/landing/presentation/guest_landing_screen.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/clinic_time.dart';
import 'package:beauty_clinic_app/features/appointments/data/doctor_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/treatment_api.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/appointments_screen.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/clinic_appointments_screen.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/booking_flow_sheet.dart';
import 'package:beauty_clinic_app/features/chat/data/chat_api.dart';
import 'package:beauty_clinic_app/features/chat/presentation/chat_launcher.dart';
import 'package:beauty_clinic_app/features/forms/data/clinical_intake_api.dart';
import 'package:beauty_clinic_app/features/forms/data/dynamic_form_api.dart';
import 'package:beauty_clinic_app/features/forms/presentation/admin_clinical_intake_screen.dart';
import 'package:beauty_clinic_app/features/forms/presentation/form_builder_admin_screen.dart';
import 'package:beauty_clinic_app/features/patients/presentation/patients_directory_screen.dart';
import 'package:beauty_clinic_app/features/patients/presentation/reception_patients_screen.dart';
import 'package:beauty_clinic_app/features/products/data/product_api.dart';
import 'package:beauty_clinic_app/features/products/presentation/patient_products_screen.dart';
import 'package:beauty_clinic_app/features/products/presentation/product_catalog_screen.dart';
import 'package:beauty_clinic_app/features/staff_management/staff_management_screen.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:beauty_clinic_app/routing/app_routes.dart';
import 'package:beauty_clinic_app/screens/login_screen.dart';
import 'package:beauty_clinic_app/screens/register_screen.dart';

/// Main Application Entry Widget for Beauty Clinic
class BeautyClinicApp extends StatefulWidget {
  const BeautyClinicApp({super.key, this.authSession});

  /// Injectable for tests; production owns its own.
  final AuthSession? authSession;

  @override
  State<BeautyClinicApp> createState() => _BeautyClinicAppState();
}

class _BeautyClinicAppState extends State<BeautyClinicApp> {
  late final AuthSession _session;
  late final bool _ownsSession;
  late final GoRouter _router;

  // Dialogs need a context inside the Navigator.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final ApiClient _apiClient;
  late final ProductApi _products;
  late final TreatmentApi _treatmentApi;
  late final AppointmentApi _appointmentApi;
  late final DoctorApi _doctorApi;
  late final DoctorAvailabilityApi _availabilityApi;
  late final ClinicalIntakeApi _clinicalApi;
  late final DynamicFormApi _dynamicApi;
  late final ChatApi _chatApi;
  String? _userName;
  String? _userImageUrl;
  String? _userGender;
  String? _selectedDoctorId;

  // Guards re-fetching on later session events.
  bool _clinicTimeRequested = false;

  // Where a refresh started, before auth loaded.
  String? _pendingLocation;

  // Bot wrote; screens reload quietly.
  final ValueNotifier<int> _chatWrote = ValueNotifier<int>(0);

  // Carries a just-booked visit over.
  final ValueNotifier<Appointment?> _bookedSignal = ValueNotifier<Appointment?>(
    null,
  );

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.authSession == null;
    _session = widget.authSession ?? AuthSession.production();
    _session.initialize();

    _apiClient = ApiClient(_session);
    _products = ProductApi(_apiClient);
    _treatmentApi = TreatmentApi(_apiClient);
    _appointmentApi = AppointmentApi(_apiClient);
    _doctorApi = DoctorApi(_apiClient);
    _availabilityApi = DoctorAvailabilityApi(_apiClient);
    _clinicalApi = ClinicalIntakeApi(_apiClient);
    _dynamicApi = DynamicFormApi(_apiClient);
    _chatApi = ChatApi(_apiClient);
    _session.addListener(_handleSessionChanged);

    _router = _buildRouter();
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    if (!_session.isAuthenticated) {
      // Backend sign-out leaves no name behind.
      if (_userName != null || _userImageUrl != null || _userGender != null) {
        setState(() {
          _userName = null;
          _userImageUrl = null;
          _userGender = null;
        });
      }
      _selectedDoctorId = null;
      return;
    }
    if (_userName == null) {
      _loadUserName();
    }
    if (!_clinicTimeRequested) {
      _clinicTimeRequested = true;
      _loadClinicTime();
    }
  }

  // Clinic zone for screens skipping Appointments.
  Future<void> _loadClinicTime() async {
    try {
      final rules = await _treatmentApi.rules();
      ClinicTime.use(rules.timezone);
    } catch (_) {
      // The device zone stands in.
    }
  }

  Future<void> _loadUserName() async {
    try {
      final profile = await UserProfileApi(_apiClient).me();
      if (!mounted) return;
      setState(() {
        _userName = '${profile.firstName} ${profile.lastName}'.trim();
        _userImageUrl = profile.imageUrl;
        _userGender = profile.gender;
      });
    } catch (_) {
      // Keep the header usable if this fails.
    }
  }

  // Chat writes bypass ApiClient.post, so evict here.
  void _afterChatWrite() {
    _apiClient.invalidateCache();
    _chatWrote.value++;
  }

  @override
  void dispose() {
    _session.removeListener(_handleSessionChanged);
    _bookedSignal.dispose();
    _chatWrote.dispose();
    _apiClient.close();
    // Covers every session ending.
    ClinicTime.reset();
    if (_ownsSession) {
      _session.dispose();
    }
    super.dispose();
  }

  Future<void> _logout() async {
    _userName = null;
    _userImageUrl = null;
    try {
      await _session.logout();
    } on AuthException {
      // Cleared locally; the redirect returns to login.
    }
  }

  // Least privilege while signed out; never admin.
  String get _activeRole => _session.role?.wireName.toLowerCase() ?? 'patient';

  // Nav and routes share one table.
  GoRouter _buildRouter() {
    return GoRouter(
      navigatorKey: _navigatorKey,
      initialLocation: AppRoutes.splash,
      refreshListenable: _session,
      redirect: _redirect,
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const Scaffold(body: SkeletonDetail()),
          ),
        ),
        GoRoute(
          path: AppRoutes.guestLanding,
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: GuestLandingScreen(
              onLogin: () => _router.go(AppRoutes.login),
              treatmentApi: _treatmentApi,
              doctorApi: _doctorApi,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: LoginScreen(
              authSession: _session,
              onRegister: () => context.go(AppRoutes.register),
              onBack: () => context.go(AppRoutes.guestLanding),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.register,
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: RegisterScreen(
              authSession: _session,
              onSignIn: () => context.go(AppRoutes.login),
              onBack: () => context.go(AppRoutes.guestLanding),
            ),
          ),
        ),
        ShellRoute(
          builder: _buildShell,
          routes: [
            for (final entry in AppRoutes.views)
              GoRoute(
                path: entry.path,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: _viewFor(entry.id, context, state),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.uri.path;

    const publicOnly = {
      AppRoutes.splash,
      AppRoutes.guestLanding,
      AppRoutes.login,
      AppRoutes.register,
    };

    switch (_session.status) {
      case AuthStatus.initializing:
        if (location == AppRoutes.splash) return null;
        // Held across the bounce, restored once authenticated.
        if (!publicOnly.contains(location)) {
          _pendingLocation = state.uri.toString();
        }
        return AppRoutes.splash;

      case AuthStatus.unauthenticated:
        const guestPaths = {
          AppRoutes.guestLanding,
          AppRoutes.login,
          AppRoutes.register,
        };
        return guestPaths.contains(location) ? null : AppRoutes.guestLanding;

      case AuthStatus.authenticated:
        final pending = _pendingLocation;
        if (pending != null) {
          _pendingLocation = null;
          final pendingPath = Uri.parse(pending).path;
          if (pendingPath != location &&
              AppRoutes.allows(
                _activeRole,
                AppRoutes.idForLocation(pendingPath),
              )) {
            return pending;
          }
        }
        if (publicOnly.contains(location)) {
          return AppRoutes.defaultPathFor(_activeRole);
        }
        final id = AppRoutes.idForLocation(location);
        if (!AppRoutes.allows(_activeRole, id)) {
          return AppRoutes.defaultPathFor(_activeRole);
        }
        return null;
    }
  }

  Widget _buildShell(BuildContext context, GoRouterState state, Widget child) {
    final activeView = AppRoutes.idForLocation(state.uri.path);
    return AppShell(
      activeRole: _activeRole,
      activeView: activeView,
      onViewChanged: _onViewChanged,
      onProfileTap: () => context.go(AppRoutes.pathFor('my_profile')),
      userName: _userName,
      userImageUrl: _userImageUrl,
      userGender: _userGender,
      // Booking lives in chat, not the header.
      onLogout: _logout,
      child: _withChat(
        Stack(
          children: [
            const FloatingPetals(),
            PageSwitcher(child: child),
          ],
        ),
      ),
    );
  }

  void _onViewChanged(String newView) {
    // Book opens the sheet, not a route.
    if (newView == 'book') {
      _openBookingModal();
      return;
    }
    if (!AppRoutes.allows(_activeRole, newView)) return;
    _router.go(AppRoutes.pathFor(newView));
  }

  void _onViewPatient(String patientId) {
    _router.go(AppRoutes.patientDetail(patientId));
  }

  void _onViewDoctor(String doctorId) {
    _selectedDoctorId = doctorId;
    _router.go(AppRoutes.pathFor('doctor_profile'));
  }

  // Goes to appointments, then opens the sheet.
  void _openBookingModal() {
    if (AppRoutes.allows(_activeRole, 'appointments')) {
      _router.go(AppRoutes.pathFor('appointments'));
    }

    final bookingContext = _navigatorKey.currentContext;
    if (bookingContext == null || !bookingContext.mounted) return;
    showDialog<bool>(
      context: bookingContext,
      builder: (context) => BookingFlowSheet(
        treatmentApi: _treatmentApi,
        appointmentApi: _appointmentApi,
        doctorApi: _doctorApi,
        // Hands the new visit over.
        onBooked: (appointment) => _bookedSignal.value = appointment,
        onEditClinicalForm: _activeRole == 'patient'
            ? () {
                Navigator.of(context).pop();
                _router.go(
                  AppRoutes.ownProfilePath(
                    tab: PatientProfileScreen.clinicFormsTabIndex,
                    fromBooking: true,
                  ),
                );
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beauty & Derma Clinic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
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

  Widget _viewFor(String id, BuildContext context, GoRouterState state) {
    switch (id) {
      case 'dashboard':
        if (_activeRole == 'patient') {
          return PatientDashboardScreen(
            key: const ValueKey('patient_dashboard'),
            refreshSignal: _chatWrote,
            apiClient: _apiClient,
            appointmentApi: _appointmentApi,
            clinicalApi: _clinicalApi,
            onOpenProfile: () => _router.go(
              AppRoutes.ownProfilePath(
                tab: PatientProfileScreen.overviewTabIndex,
              ),
            ),
            onOpenClinicalForm: () => _router.go(
              AppRoutes.ownProfilePath(
                tab: PatientProfileScreen.clinicFormsTabIndex,
              ),
            ),
            onOpenAppointments: (appointmentId) =>
                _router.go(AppRoutes.appointmentsPath(focus: appointmentId)),
            onBookTreatment: _openBookingModal,
          );
        }
        return DashboardScreen(
          key: ValueKey('dashboard_$_activeRole'),
          activeRole: _activeRole,
          onViewPatient: _onViewPatient,
          onViewDoctor: _onViewDoctor,
          apiClient: _apiClient,
          onBookAppointment: _activeRole == 'receptionist'
              ? () => _onViewChanged('appointments')
              : _openBookingModal,
          onViewAppointments: () => _onViewChanged('appointments'),
          onCheckInPatient: () => _onViewChanged('appointments'),
          onViewDoctors: () => _onViewChanged('doctors'),
        );
      case 'appointments':
        if (_activeRole == 'admin' || _activeRole == 'receptionist') {
          return ClinicAppointmentsScreen(
            key: const ValueKey('clinic_appointments'),
            appointmentApi: _appointmentApi,
            treatmentApi: _treatmentApi,
            doctorApi: _doctorApi,
            apiClient: _apiClient,
            onViewPatient: _onViewPatient,
            showCalendarTab: true,
            availabilityApi: _availabilityApi,
            // Admin can read a completed session's clinical record;
            // reception has no clinical need to. Neither can author one -
            // that stays doctor-only via canAuthorSessionRecords.
            canViewSessionRecords: _activeRole == 'admin',
          );
        }
        if (_activeRole == 'doctor') {
          return ClinicAppointmentsScreen(
            key: const ValueKey('doctor_appointments'),
            appointmentApi: _appointmentApi,
            treatmentApi: _treatmentApi,
            doctorApi: _doctorApi,
            apiClient: _apiClient,
            canAuthorSessionRecords: true,
            doctorUserId: _session.userId,
            onViewPatient: _onViewPatient,
            showCalendarTab: true,
            availabilityApi: _availabilityApi,
          );
        }
        if (_activeRole == 'patient') {
          return AppointmentsScreen(
            key: const ValueKey('my_appointments'),
            refreshSignal: _chatWrote,
            apiClient: _apiClient,
            patientId: _session.userId,
            appointmentApi: _appointmentApi,
            treatmentApi: _treatmentApi,
            doctorApi: _doctorApi,
            bookedSignal: _bookedSignal,
            focusedAppointmentId: state.uri.queryParameters['focus'],
            onNavigateToForms: () => _router.go(
              AppRoutes.ownProfilePath(
                tab: PatientProfileScreen.clinicFormsTabIndex,
                fromBooking: true,
              ),
            ),
          );
        }
        return DashboardScreen(
          key: ValueKey('dashboard_$_activeRole'),
          activeRole: _activeRole,
          onViewPatient: _onViewPatient,
          onViewDoctor: _onViewDoctor,
          apiClient: _apiClient,
        );
      case 'doctors':
        if (_activeRole == 'receptionist') {
          return DoctorDirectoryScreen(
            key: const ValueKey('doctor_directory'),
            doctorApi: _doctorApi,
            availabilityApi: _availabilityApi,
            apiClient: _apiClient,
            appointmentApi: _appointmentApi,
            treatmentApi: _treatmentApi,
          );
        }
        return DashboardScreen(
          key: ValueKey('dashboard_$_activeRole'),
          activeRole: _activeRole,
          onViewPatient: _onViewPatient,
          onViewDoctor: _onViewDoctor,
          apiClient: _apiClient,
        );
      case 'patients':
        if (_activeRole == 'receptionist') {
          return ReceptionPatientsScreen(
            key: const ValueKey('reception_patients'),
            apiClient: _apiClient,
            appointmentApi: _appointmentApi,
            treatmentApi: _treatmentApi,
            doctorApi: _doctorApi,
          );
        }
        final selectedPatientId = state.pathParameters['patientId'];
        if (selectedPatientId != null) {
          return PatientProfileScreen(
            key: ValueKey('admin_patient_$selectedPatientId'),
            patientId: selectedPatientId,
            clinicalApi: _clinicalApi,
            dynamicApi: _dynamicApi,
            appointmentApi: _appointmentApi,
            productApi: _products,
            apiClient: _apiClient,
            canManageProducts:
                _activeRole == 'admin' || _activeRole == 'doctor',
            canAuthorSessionRecords: _activeRole == 'doctor',
            doctorUserId: _session.userId,
            onBack: () => _router.go(AppRoutes.pathFor('patients')),
          );
        }
        return PatientsDirectoryScreen(
          key: const ValueKey('patients_directory'),
          clinicalApi: _clinicalApi,
          onSelectPatient: _onViewPatient,
          title: _activeRole == 'doctor' ? 'Patients' : null,
        );
      case 'clinical_forms':
        return AdminClinicalIntakeScreen(
          api: _clinicalApi,
          title: _activeRole == 'doctor'
              ? 'Patient History & Activity Log'
              : null,
          subtitle: _activeRole == 'doctor'
              ? 'Review the latest patient form revisions and clinical activity.'
              : null,
        );
      case 'form_builder':
        return FormBuilderAdminScreen(api: _dynamicApi);
      case 'products':
        if (_activeRole == 'patient') {
          return PatientProductsScreen(
            key: const ValueKey('my_products'),
            productApi: _products,
            apiClient: _apiClient,
            patientId: _session.userId,
          );
        }
        return ProductCatalogScreen(
          key: const ValueKey('products'),
          api: _products,
          canManage:
              _session.role == Role.admin || _session.role == Role.doctor,
        );
      case 'staff_management':
        return StaffManagementScreen(
          key: const ValueKey('staff_management'),
          apiClient: _apiClient,
          authSession: _session,
          onOpenDoctor: _onViewDoctor,
        );
      case 'activity_log':
        return ActivityLogScreen(
          key: const ValueKey('activity_log'),
          authSession: _session,
        );
      case 'doctor_profile':
        final doctorId = _selectedDoctorId;
        if (doctorId == null) {
          return Center(
            child: TextButton(
              onPressed: () =>
                  _router.go(AppRoutes.pathFor('staff_management')),
              child: const Text(
                'No doctor selected. Back to Staff Management.',
              ),
            ),
          );
        }
        return DoctorProfileScreen(
          key: ValueKey('doctor_profile_$doctorId'),
          doctorId: doctorId,
          apiClient: _apiClient,
          appointmentApi: _appointmentApi,
          availabilityApi: _availabilityApi,
          onBack: () {
            _selectedDoctorId = null;
            _router.go(AppRoutes.pathFor('staff_management'));
          },
        );
      case 'doctor_availability':
        return DoctorAvailabilityScreen(
          key: const ValueKey('doctor_availability'),
          api: _availabilityApi,
          appointmentApi: _appointmentApi,
        );
      case 'patient_profile':
        final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
        final fromBooking = state.uri.queryParameters['fromBooking'] == 'true';
        return PatientProfileScreen(
          key: ValueKey('patient_profile_${tab}_$fromBooking'),
          clinicalApi: _clinicalApi,
          dynamicApi: _dynamicApi,
          appointmentApi: _appointmentApi,
          productApi: _products,
          apiClient: _apiClient,
          initialTabIndex: tab,
          canChooseOwnProducts: _activeRole == 'patient',
          canAuthorSessionRecords: _activeRole == 'doctor',
          doctorUserId: _session.userId,
          onBackToAppointments: fromBooking
              ? () => _router.go(
                  AppRoutes.pathFor(
                    _activeRole == 'patient' ? 'appointments' : 'dashboard',
                  ),
                )
              : null,
          onOpenVisits: () => _router.go(AppRoutes.pathFor('appointments')),
          onBack: () => _router.go(AppRoutes.pathFor('dashboard')),
        );
      case 'my_profile':
        return UserProfileScreen(
          key: const ValueKey('my_profile'),
          role: _session.role ?? Role.patient,
          apiClient: _apiClient,
          onBack: () => _router.go(AppRoutes.pathFor('dashboard')),
          onProfileUpdated: _loadUserName,
          onPasswordChanged: _logout,
        );
      case 'landing':
      case 'consultations':
      default:
        return LandingScreen(
          key: const ValueKey('landing'),
          onBookClick: _openBookingModal,
          onViewDoctor: _onViewDoctor,
          treatmentApi: _treatmentApi,
          doctorApi: _doctorApi,
        );
    }
  }
}

// Plain crossfade; cheapest transition available.
class PageSwitcher extends StatelessWidget {
  const PageSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(duration: duration, child: child);
  }
}
