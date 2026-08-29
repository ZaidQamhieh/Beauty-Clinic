import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/patient_calendar_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';
import 'helpers/screen_harness.dart';

void main() {
  ResponseBody empty(RequestOptions request) => jsonListResponse(200, const []);

  ResponseBody broken(RequestOptions request) =>
      jsonResponse(500, const {'detail': 'boom'});

  testWidgets('renders the patient calendar heading', (tester) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(8, empty)),
      (b) => PatientCalendarScreen(appointmentApi: AppointmentApi(b.client)),
    );

    expect(find.text('My Calendar'), findsOneWidget);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('a failing day fetch does not take the screen down', (
    tester,
  ) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(8, broken)),
      (b) => PatientCalendarScreen(appointmentApi: AppointmentApi(b.client)),
    );

    expect(find.text('My Calendar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('the day fetch asks for the patient own sessions', (
    tester,
  ) async {
    final adapter = QueueAdapter(List.filled(8, empty));
    final bound = await pumpScreen(
      tester,
      adapter,
      (b) => PatientCalendarScreen(appointmentApi: AppointmentApi(b.client)),
    );

    expect(adapter.requests, isNotEmpty);
    expect(
      adapter.requests.any((r) => r.path.contains('/api/appointments')),
      isTrue,
    );

    bound.dispose();
    await settle(tester);
  });
}
