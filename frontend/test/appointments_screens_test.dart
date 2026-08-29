import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/doctor_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/treatment_api.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/appointments_screen.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/clinic_appointments_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';
import 'helpers/screen_harness.dart';

void main() {
  Map<String, dynamic> emptyPage() => {
    'content': <dynamic>[],
    'totalPages': 0,
    'totalElements': 0,
    'number': 0,
    'size': 20,
  };

  ResponseBody healthy(RequestOptions request) {
    if (request.path.contains('/me/upcoming') ||
        request.path.contains('/me/history') ||
        request.path.contains('/all')) {
      return jsonResponse(200, emptyPage());
    }
    return jsonListResponse(200, const []);
  }

  ResponseBody broken(RequestOptions request) =>
      jsonResponse(500, const {'detail': 'boom'});

  group('AppointmentsScreen', () {
    Widget screen(AuthSessionHarness b) => AppointmentsScreen(
      appointmentApi: AppointmentApi(b.client),
      treatmentApi: TreatmentApi(b.client),
      doctorApi: DoctorApi(b.client),
      bookedSignal: ValueNotifier(null),
      apiClient: b.client,
    );

    testWidgets('renders without error when the lists are empty', (
      tester,
    ) async {
      final bound = await pumpScreen(
        tester,
        QueueAdapter(List.filled(12, healthy)),
        screen,
        role: Role.patient,
      );

      expect(find.text('Could not load appointments.'), findsNothing);
      expect(tester.takeException(), isNull);

      bound.dispose();
      await settle(tester);
    });

    testWidgets('a failed load reports it could not load appointments', (
      tester,
    ) async {
      final bound = await pumpScreen(
        tester,
        QueueAdapter(List.filled(12, broken)),
        screen,
        role: Role.patient,
      );

      expect(find.text('Could not load appointments.'), findsWidgets);

      bound.dispose();
      await settle(tester);
    });
  });

  group('ClinicAppointmentsScreen', () {
    Widget screen(AuthSessionHarness b) => ClinicAppointmentsScreen(
      appointmentApi: AppointmentApi(b.client),
      treatmentApi: TreatmentApi(b.client),
      doctorApi: DoctorApi(b.client),
      apiClient: b.client,
      canAuthorSessionRecords: true,
    );

    testWidgets('renders without error when the clinic list is empty', (
      tester,
    ) async {
      final bound = await pumpScreen(
        tester,
        QueueAdapter(List.filled(12, healthy)),
        screen,
      );

      expect(find.text('Could not load clinic appointments.'), findsNothing);
      expect(tester.takeException(), isNull);

      bound.dispose();
      await settle(tester);
    });

    testWidgets('a failed load reports it could not load clinic appointments', (
      tester,
    ) async {
      final bound = await pumpScreen(
        tester,
        QueueAdapter(List.filled(12, broken)),
        screen,
      );

      expect(find.text('Could not load clinic appointments.'), findsWidgets);

      bound.dispose();
      await settle(tester);
    });
  });
}
