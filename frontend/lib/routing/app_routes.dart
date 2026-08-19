import 'package:flutter/material.dart';

// How one route appears for one role.
class RouteMenu {
  const RouteMenu({
    required this.label,
    required this.icon,
    required this.order,
    this.badge,
  });

  final String label;
  final IconData icon;
  final int order;
  final String? badge;
}

// One screen: path, roles, menus.
class AppRoute {
  const AppRoute({
    required this.id,
    required this.path,
    this.menu = const {},
    this.reachableBy = const {},
  });

  final String id;
  final String path;

  // Roles showing it in the sidebar.
  final Map<String, RouteMenu> menu;

  // Roles allowed without a menu entry.
  final Set<String> reachableBy;

  bool allows(String role) =>
      menu.containsKey(role) || reachableBy.contains(role);
}

// Single source for paths, roles, and menus.
class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';

  static const dashboard = '/dashboard';
  static const appointments = '/appointments';
  static const doctors = '/doctors';
  static const patients = '/patients';
  static const patientDetailPattern = '/patients/:id';
  static const clinicalForms = '/clinical-forms';
  static const formBuilder = '/form-builder';
  static const products = '/products';
  static const staffManagement = '/staff';
  static const activityLog = '/activity-log';
  static const doctorProfile = '/doctor-profile';
  static const consultations = '/consultations';
  static const ownProfile = '/profile';
  static const myProfile = '/my-profile';
  static const landing = '/landing';

  // Where every role lands after signing in.
  static const home = dashboard;

  static const all = <AppRoute>[
    AppRoute(
      id: 'my_profile',
      path: myProfile,
      menu: {
        'doctor': RouteMenu(
          label: 'My Profile',
          icon: Icons.person_outline,
          order: 0,
        ),
        'patient': RouteMenu(
          label: 'My Profile',
          icon: Icons.person_outline,
          order: 1,
        ),
        'receptionist': RouteMenu(
          label: 'My Profile',
          icon: Icons.person_outline,
          order: 0,
        ),
        'admin': RouteMenu(
          label: 'My Profile',
          icon: Icons.person_outline,
          order: 0,
        ),
      },
    ),
    AppRoute(
      id: 'landing',
      path: landing,
      menu: {
        'patient': RouteMenu(
          label: 'Clinic Homepage',
          icon: Icons.home_outlined,
          order: 0,
        ),
        'admin': RouteMenu(
          label: 'Clinic Landing Page',
          icon: Icons.space_dashboard_outlined,
          order: 1,
        ),
      },
    ),
    AppRoute(
      id: 'dashboard',
      path: dashboard,
      menu: {
        'doctor': RouteMenu(
          label: 'Today\'s Schedule',
          icon: Icons.calendar_today_outlined,
          order: 1,
          badge: '8',
        ),
        'patient': RouteMenu(
          label: 'Treatments & Visits',
          icon: Icons.spa_outlined,
          order: 2,
        ),
        'receptionist': RouteMenu(
          label: 'Front Desk Desk',
          icon: Icons.meeting_room_outlined,
          order: 1,
          badge: '12',
        ),
        'admin': RouteMenu(
          label: 'Overview Dashboard',
          icon: Icons.grid_view_rounded,
          order: 2,
        ),
      },
    ),
    AppRoute(
      id: 'patients',
      path: patients,
      menu: {
        'doctor': RouteMenu(
          label: 'My Patients',
          icon: Icons.people_outline,
          order: 2,
          badge: '24',
        ),
        'receptionist': RouteMenu(
          label: 'Patient Directory',
          icon: Icons.folder_shared_outlined,
          order: 3,
        ),
        'admin': RouteMenu(
          label: 'Patients Directory',
          icon: Icons.people_alt_outlined,
          order: 7,
        ),
      },
    ),
    AppRoute(
      id: 'clinical_forms',
      path: clinicalForms,
      menu: {
        'doctor': RouteMenu(
          label: 'Patient Forms History',
          icon: Icons.assignment_outlined,
          order: 3,
        ),
        'admin': RouteMenu(
          label: 'Patient Forms History',
          icon: Icons.assignment_outlined,
          order: 3,
        ),
      },
    ),
    AppRoute(
      id: 'doctor_profile',
      path: doctorProfile,
      menu: {
        'doctor': RouteMenu(
          label: 'Doctor Profile',
          icon: Icons.badge_outlined,
          order: 4,
        ),
      },
      reachableBy: {'admin'},
    ),
    AppRoute(
      id: 'consultations',
      path: consultations,
      menu: {
        'doctor': RouteMenu(
          label: 'Consultations',
          icon: Icons.video_call_outlined,
          order: 5,
        ),
      },
    ),
    AppRoute(
      id: 'products',
      path: products,
      menu: {
        'doctor': RouteMenu(
          label: 'Products',
          icon: Icons.inventory_2_outlined,
          order: 6,
        ),
        'patient': RouteMenu(
          label: 'Products',
          icon: Icons.inventory_2_outlined,
          order: 3,
        ),
        'receptionist': RouteMenu(
          label: 'Products',
          icon: Icons.inventory_2_outlined,
          order: 5,
        ),
        'admin': RouteMenu(
          label: 'Products',
          icon: Icons.inventory_2_outlined,
          order: 5,
        ),
      },
    ),
    AppRoute(
      id: 'appointments',
      path: appointments,
      menu: {
        'receptionist': RouteMenu(
          label: 'All Appointments',
          icon: Icons.event_note_outlined,
          order: 2,
        ),
        'admin': RouteMenu(
          label: 'Appointments',
          icon: Icons.calendar_today_outlined,
          order: 6,
          badge: '14',
        ),
      },
    ),
    AppRoute(
      id: 'doctors',
      path: doctors,
      menu: {
        'receptionist': RouteMenu(
          label: 'Doctor Rosters',
          icon: Icons.medical_information_outlined,
          order: 4,
        ),
        'admin': RouteMenu(
          label: 'Doctors & Specialists',
          icon: Icons.health_and_safety_outlined,
          order: 8,
        ),
      },
    ),
    AppRoute(
      id: 'form_builder',
      path: formBuilder,
      menu: {
        'admin': RouteMenu(
          label: 'Form Builder',
          icon: Icons.dynamic_form_outlined,
          order: 4,
        ),
      },
    ),
    AppRoute(
      id: 'staff_management',
      path: staffManagement,
      menu: {
        'admin': RouteMenu(
          label: 'Staff Management',
          icon: Icons.groups_rounded,
          order: 9,
        ),
      },
    ),
    AppRoute(
      id: 'activity_log',
      path: activityLog,
      menu: {
        'admin': RouteMenu(
          label: 'Activity Log',
          icon: Icons.history_rounded,
          order: 10,
        ),
      },
    ),
    AppRoute(
      id: 'patient_profile',
      path: ownProfile,
      reachableBy: {'patient', 'admin'},
    ),
  ];

  static String patientDetail(String patientId) => '$patients/$patientId';

  // Carries the tab and the booking origin.
  static String ownProfileFromBooking(int tabIndex) =>
      '$ownProfile?tab=$tabIndex&from=booking';

  static String? viewForLocation(String location) {
    if (location.startsWith('$patients/')) {
      return 'patients';
    }

    for (final route in all) {
      if (route.path == location) {
        return route.id;
      }
    }
    return null;
  }

  static String? locationForView(String view) {
    for (final route in all) {
      if (route.id == view) {
        return route.path;
      }
    }
    return null;
  }

  static bool allows(String role, String view) {
    for (final route in all) {
      if (route.id == view) {
        return route.allows(role);
      }
    }
    return false;
  }

  // Sidebar order is per role, so sort.
  static List<AppRoute> menuFor(String role) {
    final visible = all.where((route) => route.menu.containsKey(role)).toList();
    visible.sort(
      (a, b) => a.menu[role]!.order.compareTo(b.menu[role]!.order),
    );
    return visible;
  }
}
