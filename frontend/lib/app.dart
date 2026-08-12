import 'package:flutter/material.dart';
import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/core/theme/app_theme.dart';
import 'package:beauty_clinic_app/core/widgets/floating_petals.dart';
import 'package:beauty_clinic_app/features/shell/presentation/app_shell.dart';
import 'package:beauty_clinic_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:beauty_clinic_app/features/doctor_profile/presentation/doctor_profile_screen.dart';
import 'package:beauty_clinic_app/features/patient_profile/presentation/patient_profile_screen.dart';
import 'package:beauty_clinic_app/features/landing/presentation/landing_screen.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/clinic_time.dart';
import 'package:beauty_clinic_app/features/appointments/data/doctor_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/treatment_api.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/appointments_screen.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/booking_flow_sheet.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:beauty_clinic_app/screens/login_screen.dart';

/// Main Application Entry Widget for Yasmine Beauty Clinic
class BeautyClinicApp extends StatelessWidget {
  const BeautyClinicApp({super.key, this.authSession});

  /// Injectable for tests; when omitted the app owns a production session
  /// backed by the browser's secure storage and the backend API base URL.
  final AuthSession? authSession;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yasmine Beauty & Derma Clinic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(authSession: authSession),
    );
  }
}

/// Switches between the login screen and the clinic shell based on the session.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authSession});

  final AuthSession? authSession;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthSession _session;
  late final bool _ownsSession;

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
        return LoginScreen(authSession: _session);
      case AuthStatus.authenticated:
        return MainRootController(authSession: _session);
    }
  }
}

/// Root State Controller managing Active Role and Selected Navigation View
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
  late final TreatmentApi _treatmentApi;
  late final AppointmentApi _appointmentApi;
  late final DoctorApi _doctorApi;

  // Carries a just-booked visit to the list.
  final ValueNotifier<Appointment?> _bookedSignal = ValueNotifier<Appointment?>(
    null,
  );

  @override
  void initState() {
    super.initState();
    // The shell uses lowercase role names; the backend sends uppercase wire names.
    _activeRole = widget.authSession.role?.wireName.toLowerCase() ?? 'admin';
    _activeView = 'dashboard';

    _apiClient = ApiClient(widget.authSession);
    _treatmentApi = TreatmentApi(_apiClient);
    _appointmentApi = AppointmentApi(_apiClient);
    _doctorApi = DoctorApi(_apiClient);
  }

  @override
  void dispose() {
    _bookedSignal.dispose();
    _apiClient.close();
    // Covers every way the session can end.
    ClinicTime.reset();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await widget.authSession.logout();
    } on AuthException {
      // The session is already cleared locally; AuthGate returns to the login screen.
    }
  }

  void _onRoleChanged(String newRole) {
    setState(() {
      _activeRole = newRole;
      if (newRole == 'patient') {
        _activeView = 'patient_profile';
      } else if (newRole == 'doctor') {
        _activeView = 'doctor_profile';
      } else {
        _activeView = 'dashboard';
      }
    });
  }

  void _onViewChanged(String newView) {
    // "Book" opens the sheet, not a view.
    if (newView == 'book') {
      _openBookingModal();
      return;
    }
    setState(() {
      _activeView = newView;
    });
  }

  void _onViewPatient(String patientName) {
    setState(() {
      _activeView = 'patient_profile';
    });
  }

  void _onViewDoctor(String doctorName) {
    setState(() {
      _activeView = 'doctor_profile';
    });
  }

  void _openBookingModal() {
    showDialog<bool>(
      context: context,
      builder: (context) => BookingFlowSheet(
        treatmentApi: _treatmentApi,
        appointmentApi: _appointmentApi,
        doctorApi: _doctorApi,
        // Hand the new visit to the list.
        onBooked: (appointment) => _bookedSignal.value = appointment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      activeRole: _activeRole,
      activeView: _activeView,
      onRoleChanged: _onRoleChanged,
      onViewChanged: _onViewChanged,
      onBookClick: _openBookingModal,
      onLogout: _logout,
      child: Stack(
        children: [
          const FloatingPetals(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildCurrentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    // Patients get their own list; staff keep dashboard.
    if (_activeRole == 'patient' &&
        (_activeView == 'dashboard' || _activeView == 'appointments')) {
      return AppointmentsScreen(
        key: const ValueKey('my_appointments'),
        appointmentApi: _appointmentApi,
        treatmentApi: _treatmentApi,
        doctorApi: _doctorApi,
        bookedSignal: _bookedSignal,
      );
    }

    switch (_activeView) {
      case 'dashboard':
      case 'appointments':
      case 'patients':
      case 'doctors':
        return DashboardScreen(
          key: ValueKey('dashboard_$_activeRole'),
          activeRole: _activeRole,
          onViewPatient: _onViewPatient,
          onViewDoctor: _onViewDoctor,
        );
      case 'doctor_profile':
        return DoctorProfileScreen(
          key: const ValueKey('doctor_profile'),
          onBack: () => setState(() => _activeView = 'dashboard'),
          onPatientClick: _onViewPatient,
        );
      case 'patient_profile':
        return PatientProfileScreen(
          key: const ValueKey('patient_profile'),
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
