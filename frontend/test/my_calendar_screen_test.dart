import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/doctor_availability/data/doctor_availability_api.dart';
import 'package:beauty_clinic_app/features/doctor_availability/presentation/my_calendar_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';
import 'helpers/screen_harness.dart';

void main() {
  final shift = <Map<String, dynamic>>[
    {
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'kind': 'REGULAR',
      'dayOfWeek': 'MONDAY',
      'startTime': '09:00',
      'endTime': '17:00',
      'effectiveFrom': '2026-08-01',
      'effectiveTo': null,
    },
  ];

  ResponseBody healthy(RequestOptions request) {
    if (request.path.contains('/users/me')) {
      return jsonResponse(200, const {
        'id': '11111111-1111-1111-1111-111111111111',
        'firstName': 'Lina',
        'lastName': 'Haddad',
        'email': 'lina@test.com',
        'role': 'DOCTOR',
      });
    }
    if (request.path.contains('/availability')) {
      return jsonListResponse(200, shift);
    }
    return jsonListResponse(200, const []);
  }

  ResponseBody broken(RequestOptions request) =>
      jsonResponse(500, const {'detail': 'boom'});

  Widget screen(AuthSessionHarness b) => MyCalendarScreen(
    appointmentApi: AppointmentApi(b.client),
    availabilityApi: DoctorAvailabilityApi(b.client),
    apiClient: b.client,
  );

  testWidgets('renders the calendar heading', (tester) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(10, healthy)),
      screen,
      role: Role.doctor,
    );

    expect(find.text('My Calendar'), findsOneWidget);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('it reads both the schedule and the availability', (
    tester,
  ) async {
    final adapter = QueueAdapter(List.filled(10, healthy));
    final bound = await pumpScreen(tester, adapter, screen, role: Role.doctor);

    expect(
      adapter.requests.any((r) => r.path.contains('/availability')),
      isTrue,
    );

    bound.dispose();
    await settle(tester);
  });

  testWidgets('a failing fetch does not take the screen down', (tester) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(10, broken)),
      screen,
      role: Role.doctor,
    );

    expect(find.text('My Calendar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    bound.dispose();
    await settle(tester);
  });
}
