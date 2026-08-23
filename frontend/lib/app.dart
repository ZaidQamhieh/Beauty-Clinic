import 'package:flutter/material.dart';
import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/core/theme/app_colors.dart';
import 'package:beauty_clinic_app/core/theme/app_theme.dart';
import 'package:beauty_clinic_app/core/widgets/floating_petals.dart';
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
import 'package:beauty_clinic_app/features/forms/data/clinical_intake_schema.dart';
import 'package:beauty_clinic_app/features/forms/data/dynamic_form_api.dart';
import 'package:beauty_clinic_app/features/forms/presentation/admin_clinical_intake_screen.dart';
import 'package:beauty_clinic_app/features/forms/presentation/form_builder_admin_screen.dart';
import 'package:beauty_clinic_app/features/patients/presentation/patients_directory_screen.dart';
import 'package:beauty_clinic_app/features/patients/presentation/reception_patients_screen.dart';
import 'package:beauty_clinic_app/features/products/data/product_api.dart';
import 'package:beauty_clinic_app/features/products/presentation/product_catalog_screen.dart';
import 'package:beauty_clinic_app/features/staff_management/staff_management_screen.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:beauty_clinic_app/screens/login_screen.dart';
import 'package:beauty_clinic_app/screens/register_screen.dart';

/// Main Application Entry Widget for Beauty Clinic
class BeautyClinicApp extends StatelessWidget {
  const BeautyClinicApp({super.key, this.authSession});

  /// Injectable for tests; production owns its own.
  final AuthSession? authSession;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beauty & Derma Clinic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(authSession: authSession),
    );
  }
}

/// Switches between login and the shell.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authSession});

  final AuthSession? authSession;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthSession _session;
  late final bool _ownsSession;
  bool _showRegistration = false;

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.authSession == null;
    _session = widget.authSession ?? AuthSession.production();
    _session.addListener(_handleSessionChanged);
    _session.initialize();
  }

  void _handleSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _session.removeListener(_handleSessionChanged);
    if (_ownsSession) {
      _session.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_session.status) {
      case AuthStatus.initializing:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.unauthenticated:
        return _showRegistration
            ? RegisterScreen(
                authSession: _session,
                onSignIn: () => setState(() => _showRegistration = false),
              )
            : LoginScreen(
                authSession: _session,
                onRegister: () => setState(() => _showRegistration = true),
              );
      case AuthStatus.authenticated:
        return MainRootController(authSession: _session);
    }
  }
}

/// Holds the active role and view.
class MainRootController extends StatefulWidget {
  const MainRootController({super.key, required this.authSession});

  final AuthSession authSession;

  @override
  State<MainRootController> createState() => _MainRootControllerState();
}

class _MainRootControllerState extends State<MainRootController> {
  late String _activeRole; // 'admin' | 'doctor' | 'receptionist' | 'patient'
  late String _activeView; // active view: dashboard, profile, or landing

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

  // Remounts the list after the bot writes.
  int _chatRevision = 0;

  // Carries a just-booked visit over.
  final ValueNotifier<Appointment?> _bookedSignal = ValueNotifier<Appointment?>(
    null,
  );

  @override
  void initState() {
    super.initState();
    // Shell roles are lowercase, wire names upper.
    _activeRole = widget.authSession.role?.wireName.toLowerCase() ?? 'admin';
    _activeView = 'dashboard';

    _apiClient = ApiClient(widget.authSession);
    _products = ProductApi(_apiClient);
    _treatmentApi = TreatmentApi(_apiClient);
    _appointmentApi = AppointmentApi(_apiClient);
    _doctorApi = DoctorApi(_apiClient);
    _availabilityApi = DoctorAvailabilityApi(_apiClient);
    _clinicalApi = ClinicalIntakeApi(_apiClient);
    _dynamicApi = DynamicFormApi(_apiClient);
    _chatApi = ChatApi(_apiClient);
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final profile = await UserProfileApi(_apiClient).me();
      if (!mounted) return;
      setState(() {
        _userName = '${profile.firstName} ${profile.lastName}'.trim();
      });
    } catch (_) {
      // Keep the shared header usable when the profile request fails.
    }
  }

  void _afterChatWrite() {
    setState(() => _chatRevision++);
  }

  @override
  void dispose() {
    _bookedSignal.dispose();
    _apiClient.close();
    // Covers every session ending.
    ClinicTime.reset();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await widget.authSession.logout();
    } on AuthException {
      // Cleared locally; AuthGate returns to login.
    }
  }

  @override
  void didUpdateWidget(covariant MainRootController oldWidget) {
    super.didUpdateWidget(oldWidget);
    final authenticatedRole =
        widget.authSession.role?.wireName.toLowerCase() ?? 'patient';
    if (authenticatedRole != _activeRole) {
      _activeRole = authenticatedRole;
      _activeView = authenticatedRole == 'patient'
          ? 'patient_profile'
          : 'dashboard';
    }
  }

  String? _selectedPatientId;
  int _patientProfileTabIndex = 0;
  bool _fromBookingFlow = false;
  String? _focusedAppointmentId;

  void _onViewChanged(String newView) {
    // Book opens the sheet, not a view.
    if (newView == 'book') {
      _openBookingModal();
      return;
    }
    if (!_allowedViews.contains(newView)) return;
    setState(() {
      _fromBookingFlow = false;
      _activeView = newView;
      if (newView != 'patients') {
        _selectedPatientId = null;
      }
    });
  }

  Set<String> get _allowedViews => switch (_activeRole) {
    'doctor' => {
      'dashboard',
      'my_profile',
      'doctor_availability',
      'patients',
      'clinical_forms',
      'consultations',
      'products',
    },
    'patient' => {
      'landing',
      'dashboard',
      'my_profile',
      'patient_profile',
      'appointments',
      'products',
    },
    'receptionist' => {
      'dashboard',
      'my_profile',
      'appointments',
      'patients',
      'doctors',
      'products',
    },
    _ => {
      'dashboard',
      'my_profile',
      'patients',
      'clinical_forms',
      'form_builder',
      'appointments',
      'staff_management',
      'doctors',
      'activity_log',
      'patient_profile',
      'doctor_profile',
      'products',
      'landing',
    },
  };

  void _onViewPatient(String patientId) {
    setState(() {
      _selectedPatientId = patientId;
      _activeView = 'patients';
    });
  }

  void _onViewDoctor(String doctorName) {
    setState(() {
      _activeView = 'doctor_profile';
    });
  }

  Future<void> _openBookingModal() async {
    if (_activeRole == 'patient') {
      try {
        final data = await _clinicalApi.fetchOwn();
        final isComplete = ClinicalIntakeSchema.isComplete(data);
        if (!mounted) return;

        if (!isComplete) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
                    setState(() {
                      _fromBookingFlow = true;
                      _patientProfileTabIndex =
                          PatientProfileScreen.clinicFormsTabIndex;
                      _activeView = 'patient_profile';
                    });
                  },
                  child: const Text('Fill Clinical Form'),
                ),
              ],
            ),
          );
          return;
        } else {
          final action = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
                    setState(() {
                      _fromBookingFlow = true;
                      _patientProfileTabIndex =
                          PatientProfileScreen.clinicFormsTabIndex;
                      _activeView = 'patient_profile';
                    });
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
          if (action != 'proceed') return;
        }
      } catch (_) {
        // Fallback gracefully on network error
      }
    }

    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return AppShell(
      activeRole: _activeRole,
      activeView: _activeView,
      onViewChanged: _onViewChanged,
      onProfileTap: () => _onViewChanged('my_profile'),
      userName: _userName,
      // Booking lives in chat, not the header.
      onLogout: _logout,
      child: _withChat(
        Stack(
          children: [
            const FloatingPetals(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCurrentView(),
            ),
          ],
        ),
      ),
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

  Widget _buildCurrentView() {
    switch (_activeView) {
      case 'dashboard':
        if (_activeRole == 'patient') {
          return PatientDashboardScreen(
            key: ValueKey('patient_dashboard_$_chatRevision'),
            appointmentApi: _appointmentApi,
            clinicalApi: _clinicalApi,
            onOpenProfile: () => setState(() {
              _patientProfileTabIndex = PatientProfileScreen.overviewTabIndex;
              _activeView = 'patient_profile';
            }),
            onOpenClinicalForm: () => setState(() {
              _fromBookingFlow = false;
              _patientProfileTabIndex =
                  PatientProfileScreen.clinicFormsTabIndex;
              _activeView = 'patient_profile';
            }),
            onOpenAppointments: (appointmentId) {
              _focusedAppointmentId = appointmentId;
              _onViewChanged('appointments');
            },
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
          );
        }
        if (_activeRole == 'patient') {
          return AppointmentsScreen(
            key: ValueKey('my_appointments_$_chatRevision'),
            appointmentApi: _appointmentApi,
            treatmentApi: _treatmentApi,
            doctorApi: _doctorApi,
            bookedSignal: _bookedSignal,
            clinicalApi: _clinicalApi,
            focusedAppointmentId: _focusedAppointmentId,
            onNavigateToForms: () => setState(() {
              _fromBookingFlow = true;
              _patientProfileTabIndex =
                  PatientProfileScreen.clinicFormsTabIndex;
              _activeView = 'patient_profile';
            }),
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
        if (_selectedPatientId != null) {
          return PatientProfileScreen(
            key: ValueKey('admin_patient_$_selectedPatientId'),
            patientId: _selectedPatientId,
            clinicalApi: _clinicalApi,
            dynamicApi: _dynamicApi,
            appointmentApi: _appointmentApi,
            productApi: _products,
            apiClient: _apiClient,
            onBack: () => setState(() => _selectedPatientId = null),
          );
        }
        return PatientsDirectoryScreen(
          key: const ValueKey('patients_directory'),
          clinicalApi: _clinicalApi,
          onSelectPatient: (patientId) => setState(() {
            _selectedPatientId = patientId;
          }),
          title: _activeRole == 'doctor' ? 'My Patients' : null,
          subtitle: _activeRole == 'doctor'
              ? 'Review patient intake status, treatment context, and clinical records.'
              : null,
        );
      case 'clinical_forms':
        return AdminClinicalIntakeScreen(
          api: _clinicalApi,
          title: _activeRole == 'doctor' ? 'Patient Forms History' : null,
          subtitle: _activeRole == 'doctor'
              ? 'Review the latest patient form revisions and clinical activity.'
              : null,
        );
      case 'form_builder':
        return FormBuilderAdminScreen(api: _dynamicApi);
      case 'products':
        return ProductCatalogScreen(
          key: const ValueKey('products'),
          api: _products,
          canManage:
              widget.authSession.role == Role.admin ||
              widget.authSession.role == Role.doctor,
        );
      case 'staff_management':
        return StaffManagementScreen(
          key: const ValueKey('staff_management'),
          apiClient: _apiClient,
          authSession: widget.authSession,
        );
      case 'activity_log':
        return ActivityLogScreen(
          key: const ValueKey('activity_log'),
          authSession: widget.authSession,
        );
      case 'doctor_profile':
        return DoctorProfileScreen(
          key: const ValueKey('doctor_profile'),
          onBack: () => setState(() => _activeView = 'dashboard'),
          onPatientClick: _onViewPatient,
        );
      case 'doctor_availability':
        return DoctorAvailabilityScreen(
          key: const ValueKey('doctor_availability'),
          api: _availabilityApi,
          onBack: () => setState(() => _activeView = 'dashboard'),
        );
      case 'patient_profile':
        return PatientProfileScreen(
          key: ValueKey(
            'patient_profile_${_patientProfileTabIndex}_$_fromBookingFlow',
          ),
          clinicalApi: _clinicalApi,
          dynamicApi: _dynamicApi,
          appointmentApi: _appointmentApi,
          productApi: _products,
          apiClient: _apiClient,
          initialTabIndex: _patientProfileTabIndex,
          onBackToAppointments: _fromBookingFlow
              ? () => setState(() {
                  _fromBookingFlow = false;
                  _patientProfileTabIndex = 0;
                  _activeView = _activeRole == 'patient'
                      ? 'appointments'
                      : 'dashboard';
                })
              : null,
          onBack: () => setState(() {
            _fromBookingFlow = false;
            _patientProfileTabIndex = 0;
            _activeView = 'dashboard';
          }),
        );
      case 'my_profile':
        return UserProfileScreen(
          key: const ValueKey('my_profile'),
          role: widget.authSession.role ?? Role.patient,
          apiClient: _apiClient,
          onBack: () => setState(() => _activeView = 'dashboard'),
        );
      case 'landing':
      default:
        return LandingScreen(
          key: const ValueKey('landing'),
          onBookClick: _openBookingModal,
          onViewDoctor: _onViewDoctor,
        );
    }
  }
}
