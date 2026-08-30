// One row per screen.
class AppRouteSpec {
  const AppRouteSpec(this.id, this.path);

  final String id;
  final String path;
}

abstract class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String guestLanding = '/';

  static const String patientDetailPattern = '/patients/:patientId';

  // pathFor() uses the first match.
  static const List<AppRouteSpec> views = [
    AppRouteSpec('landing', '/home'),
    AppRouteSpec('dashboard', '/dashboard'),
    AppRouteSpec('appointments', '/appointments'),
    AppRouteSpec('doctors', '/doctors'),
    AppRouteSpec('patients', '/patients'),
    AppRouteSpec('patients', patientDetailPattern),
    AppRouteSpec('clinical_forms', '/clinical-forms'),
    AppRouteSpec('form_builder', '/form-builder'),
    AppRouteSpec('products', '/products'),
    AppRouteSpec('staff_management', '/staff'),
    AppRouteSpec('activity_log', '/activity-log'),
    AppRouteSpec('doctor_profile', '/doctor-profile'),
    AppRouteSpec('doctor_availability', '/doctor-availability'),
    AppRouteSpec('patient_profile', '/patient-profile'),
    AppRouteSpec('my_profile', '/my-profile'),
    AppRouteSpec('consultations', '/consultations'),
  ];

  static String pathFor(String id) {
    for (final entry in views) {
      if (entry.id == id) return entry.path;
    }
    return '/dashboard';
  }

  // Only /patients/:id needs special handling.
  static String idForLocation(String location) {
    for (final entry in views) {
      if (entry.path == location) return entry.id;
    }
    if (location.startsWith('/patients/')) return 'patients';
    return 'dashboard';
  }

  static String patientDetail(String patientId) => '/patients/$patientId';

  static String ownProfilePath({int? tab, bool fromBooking = false}) {
    final query = <String, String>{
      if (tab != null) 'tab': '$tab',
      if (fromBooking) 'fromBooking': 'true',
    };
    if (query.isEmpty) return pathFor('patient_profile');
    final params = query.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '${pathFor('patient_profile')}?$params';
  }

  static String appointmentsPath({String? focus}) {
    if (focus == null) return pathFor('appointments');
    return '${pathFor('appointments')}?focus=$focus';
  }

  // Which views each role may reach.
  static Set<String> allowedFor(String role) => switch (role) {
    'doctor' => {
      'dashboard',
      'my_profile',
      'doctor_availability',
      'patients',
      'appointments',
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

  static bool allows(String role, String id) => allowedFor(role).contains(id);

  // First view for a freshly authenticated role.
  static String defaultPathFor(String role) => pathFor('dashboard');
}
