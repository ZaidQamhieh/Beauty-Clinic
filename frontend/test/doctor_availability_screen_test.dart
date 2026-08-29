import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/doctor_availability/data/doctor_availability_api.dart';
import 'package:beauty_clinic_app/features/doctor_availability/presentation/doctor_availability_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';
import 'helpers/screen_harness.dart';

void main() {
  const doctorId = '11111111-1111-1111-1111-111111111111';

  final schedule = <Map<String, dynamic>>[
    {
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'kind': 'REGULAR',
      'dayOfWeek': 'MONDAY',
      'startTime': '09:00',
      'endTime': '17:00',
      'effectiveFrom': '2026-08-01',
      'effectiveTo': null,
    },
    {
      'id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'kind': 'VACATION',
      'dayOfWeek': null,
      'startTime': null,
      'endTime': null,
      'effectiveFrom': '2026-09-10',
      'effectiveTo': '2026-09-14',
    },
  ];

  // The day view fetches too, so answer by path rather than by order.
  QueueAdapter adapterFor(ResponseBody Function(RequestOptions) handler) {
    return QueueAdapter(List.filled(8, handler));
  }

  ResponseBody healthy(RequestOptions request) {
    if (request.path.contains('/availability')) {
      return jsonListResponse(200, schedule);
    }
    return jsonListResponse(200, const []);
  }

  ResponseBody broken(RequestOptions request) {
    return jsonResponse(500, const {'detail': 'The schedule could not be read.'});
  }

  Widget screen(AuthSessionHarness b) => DoctorAvailabilityScreen(
    api: DoctorAvailabilityApi(b.client),
    appointmentApi: AppointmentApi(b.client),
    doctorId: doctorId,
  );

  testWidgets('loads the schedule for the named doctor', (tester) async {
    final adapter = adapterFor(healthy);
    final bound = await pumpScreen(tester, adapter, screen);

    expect(adapter.requests.first.path, contains('/availability'));
    expect(find.text('Unable to load availability.'), findsNothing);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('a failed load surfaces the server reason and a retry', (
    tester,
  ) async {
    final bound = await pumpScreen(tester, adapterFor(broken), screen);

    expect(find.text('The schedule could not be read.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('an exception can be added from the schedule', (tester) async {
    final bound = await pumpScreen(tester, adapterFor(healthy), screen);

    expect(find.text('Add Exception'), findsWidgets);

    bound.dispose();
    await settle(tester);
  });
}
