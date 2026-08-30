import 'package:beauty_clinic_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';
import 'helpers/screen_harness.dart';

void main() {
  ResponseBody healthy(RequestOptions request) {
    if (request.path.contains('/analytics')) {
      return jsonResponse(200, const {
        'rangeType': 'custom',
        'totalAppointments': 0,
        'confirmedAppointments': 0,
        'pendingAppointments': 0,
      });
    }
    if (request.path.contains('/me') || request.path.contains('/patients/')) {
      return jsonResponse(200, const {'content': <dynamic>[]});
    }
    return jsonListResponse(200, const []);
  }

  ResponseBody broken(RequestOptions request) =>
      jsonResponse(500, const {'detail': 'boom'});

  Widget dashboard(AuthSessionHarness b, String role) => DashboardScreen(
    activeRole: role,
    onViewPatient: (_) {},
    onViewDoctor: (_) {},
    apiClient: b.client,
  );

  for (final role in ['admin', 'doctor', 'receptionist', 'patient']) {
    testWidgets('the $role dashboard renders without throwing', (tester) async {
      final bound = await pumpScreen(
        tester,
        QueueAdapter(List.filled(16, healthy)),
        (b) => dashboard(b, role),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardScreen), findsOneWidget);

      bound.dispose();
      await settle(tester);
    });
  }

  testWidgets('the receptionist dashboard offers a full appointments view', (
    tester,
  ) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(16, healthy)),
      (b) => DashboardScreen(
        activeRole: 'receptionist',
        onViewPatient: (_) {},
        onViewDoctor: (_) {},
        apiClient: b.client,
        onViewAppointments: () {},
      ),
    );

    expect(find.text('View All Appointments'), findsWidgets);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('a failing dashboard load still renders the shell', (
    tester,
  ) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(16, broken)),
      (b) => dashboard(b, 'admin'),
    );

    expect(find.byType(DashboardScreen), findsOneWidget);

    bound.dispose();
    await settle(tester);
  });
}
