import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/doctor_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/treatment_api.dart';
import 'package:beauty_clinic_app/features/doctor_availability/data/doctor_availability_api.dart';
import 'package:beauty_clinic_app/features/doctor_directory/presentation/doctor_directory_screen.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  Widget screenUnder(ApiClient client) {
    return MaterialApp(
      home: Scaffold(
        body: DoctorDirectoryScreen(
          doctorApi: DoctorApi(client),
          availabilityApi: DoctorAvailabilityApi(client),
          apiClient: client,
          appointmentApi: AppointmentApi(client),
          treatmentApi: TreatmentApi(client),
        ),
      ),
    );
  }

  testWidgets('lists doctors returned by the roster', (tester) async {
    final adapter = QueueAdapter([
      (_) => jsonListResponse(200, [
        {
          'userId': '11111111-1111-1111-1111-111111111111',
          'fullName': 'Dr Lina Haddad',
          'specializations': ['DERMATOLOGY'],
        },
        {
          'userId': '22222222-2222-2222-2222-222222222222',
          'fullName': 'Dr Yara Saleh',
          'specializations': ['LASER'],
        },
      ]),
      (_) => jsonListResponse(200, const []),
      (_) => jsonListResponse(200, const []),
    ]);
    final bound = adminHarness(adapter);

    await tester.pumpWidget(screenUnder(bound.client));
    await tester.pumpAndSettle();

    expect(find.text('Dr Lina Haddad'), findsOneWidget);
    expect(find.text('Dr Yara Saleh'), findsOneWidget);

    bound.dispose();
  });

  testWidgets('search narrows the roster to a matching doctor', (tester) async {
    final adapter = QueueAdapter([
      (_) => jsonListResponse(200, [
        {
          'userId': '11111111-1111-1111-1111-111111111111',
          'fullName': 'Dr Lina Haddad',
          'specializations': ['DERMATOLOGY'],
        },
        {
          'userId': '22222222-2222-2222-2222-222222222222',
          'fullName': 'Dr Yara Saleh',
          'specializations': ['LASER'],
        },
      ]),
      (_) => jsonListResponse(200, const []),
      (_) => jsonListResponse(200, const []),
    ]);
    final bound = adminHarness(adapter);

    await tester.pumpWidget(screenUnder(bound.client));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Yara');
    await tester.pumpAndSettle();

    expect(find.text('Dr Lina Haddad'), findsNothing);
    expect(find.text('Dr Yara Saleh'), findsOneWidget);

    bound.dispose();
  });

  testWidgets('a failed roster read surfaces the error card and retry', (
    tester,
  ) async {
    final adapter = QueueAdapter([
      (_) => jsonResponse(500, const {'detail': 'boom'}),
    ]);
    final bound = adminHarness(adapter);

    await tester.pumpWidget(screenUnder(bound.client));
    await tester.pumpAndSettle();

    expect(find.text('Could not load doctor profiles.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

    bound.dispose();
  });

  testWidgets('an empty roster explains that nothing matched', (tester) async {
    final adapter = QueueAdapter([(_) => jsonListResponse(200, const [])]);
    final bound = adminHarness(adapter);

    await tester.pumpWidget(screenUnder(bound.client));
    await tester.pumpAndSettle();

    expect(find.text('No doctors match that search.'), findsOneWidget);

    bound.dispose();
  });
}
