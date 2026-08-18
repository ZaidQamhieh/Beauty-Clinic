import 'dart:convert';

import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/clinic_time.dart';
import 'package:beauty_clinic_app/features/appointments/data/doctor_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/treatment_api.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/appointments_screen.dart';
import 'package:beauty_clinic_app/features/forms/data/clinical_intake_api.dart';
import 'package:beauty_clinic_app/features/forms/data/clinical_intake_schema.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  group('Clinical Intake Schema isComplete', () {
    test('returns false when data is null or empty', () {
      expect(ClinicalIntakeSchema.isComplete(null), isFalse);
      expect(ClinicalIntakeSchema.isComplete({}), isFalse);
    });

    test('returns false when skinType is missing or empty', () {
      expect(
        ClinicalIntakeSchema.isComplete({
          'pregnantBreastfeeding': false,
          'skinType': null,
        }),
        isFalse,
      );
      expect(
        ClinicalIntakeSchema.isComplete({
          'pregnantBreastfeeding': false,
          'skinType': '',
        }),
        isFalse,
      );
    });

    test('returns true when skinType is specified', () {
      expect(
        ClinicalIntakeSchema.isComplete({
          'pregnantBreastfeeding': false,
          'skinType': 'NORMAL',
          'allergies': ['LATEX'],
        }),
        isTrue,
      );
    });
  });

  group('Clinical Form Pre-Booking Guard in AppointmentsScreen', () {
    late AuthSession session;

    setUp(() async {
      final authAdapter = QueueAdapter([
        (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
      ]);
      session = testSession(
        authAdapter,
        MemoryTokenStore(),
        DateTime.utc(2026, 8, 6, 12),
      );
      await session.initialize();
      await session.login(email: 'pat@example.com', password: 'password');
    });

    tearDown(() {
      session.dispose();
      ClinicTime.reset();
    });

    testWidgets(
      'Incomplete form blocks booking and prompts to fill clinical form',
      (tester) async {
        bool navigatedToForms = false;

        final adapter = QueueAdapter(
          List.generate(
            20,
            (_) => (RequestOptions options) {
              Object? body;
              if (options.path == '/api/patients/me') {
                body = {
                  'id': 'pat-1',
                  'firstName': 'Jane',
                  'lastName': 'Doe',
                  'skinType': null,
                  'pregnantBreastfeeding': false,
                  'allergies': [],
                  'medications': [],
                  'chronicConditions': [],
                };
              } else if (options.path == '/api/appointments/me') {
                body = {
                  'content': [],
                  'totalElements': 0,
                  'number': 0,
                  'size': 20,
                  'last': true,
                };
              } else {
                body = <String, dynamic>{};
              }

              return ResponseBody.fromString(
                jsonEncode(body),
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            },
          ),
        );

        final client = ApiClient(session, dio: testDio(adapter));
        final clinicalApi = ClinicalIntakeApi(client);
        final appointmentApi = AppointmentApi(client);
        final treatmentApi = TreatmentApi(client);
        final doctorApi = DoctorApi(client);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppointmentsScreen(
                appointmentApi: appointmentApi,
                treatmentApi: treatmentApi,
                doctorApi: doctorApi,
                bookedSignal: ValueNotifier<Appointment?>(null),
                clinicalApi: clinicalApi,
                onNavigateToForms: () => navigatedToForms = true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap "New appointment" button
        final newApptButton = find.text('New appointment');
        expect(newApptButton, findsOneWidget);
        await tester.tap(newApptButton);
        await tester.pumpAndSettle();

        // Verification: "Clinical Form Required" modal appears
        expect(find.text('Clinical Form Required'), findsOneWidget);
        expect(find.text('Fill Clinical Form'), findsOneWidget);

        // Tap "Fill Clinical Form"
        await tester.tap(find.text('Fill Clinical Form'));
        await tester.pumpAndSettle();

        // Verifies it navigated to forms
        expect(navigatedToForms, isTrue);

        client.close();
      },
    );

    testWidgets(
      'Complete form shows reminder with Review/Modify and Continue buttons',
      (tester) async {
        bool navigatedToForms = false;

        final adapter = QueueAdapter(
          List.generate(
            20,
            (_) => (RequestOptions options) {
              Object? body;
              if (options.path == '/api/patients/me') {
                body = {
                  'id': 'pat-1',
                  'firstName': 'Jane',
                  'lastName': 'Doe',
                  'skinType': 'COMBINATION',
                  'pregnantBreastfeeding': false,
                  'allergies': [],
                  'medications': [],
                  'chronicConditions': [],
                };
              } else if (options.path == '/api/appointments/me') {
                body = {
                  'content': [],
                  'totalElements': 0,
                  'number': 0,
                  'size': 20,
                  'last': true,
                };
              } else {
                body = <String, dynamic>{};
              }

              return ResponseBody.fromString(
                jsonEncode(body),
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            },
          ),
        );

        final client = ApiClient(session, dio: testDio(adapter));
        final clinicalApi = ClinicalIntakeApi(client);
        final appointmentApi = AppointmentApi(client);
        final treatmentApi = TreatmentApi(client);
        final doctorApi = DoctorApi(client);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppointmentsScreen(
                appointmentApi: appointmentApi,
                treatmentApi: treatmentApi,
                doctorApi: doctorApi,
                bookedSignal: ValueNotifier<Appointment?>(null),
                clinicalApi: clinicalApi,
                onNavigateToForms: () => navigatedToForms = true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap "New appointment" button
        final newApptButton = find.text('New appointment');
        expect(newApptButton, findsOneWidget);
        await tester.tap(newApptButton);
        await tester.pumpAndSettle();

        // Verification: "Clinical Form Verified" modal appears
        expect(find.text('Clinical Form Verified'), findsOneWidget);
        expect(
          find.text(
            'Your clinical intake form has been completed and verified. Would you like to continue with booking, or review and update your health details first?',
          ),
          findsOneWidget,
        );
        expect(find.text('Review / Modify Form'), findsOneWidget);
        expect(find.text('Continue to Booking'), findsOneWidget);

        // Tap "Review / Modify Form"
        await tester.tap(find.text('Review / Modify Form'));
        await tester.pumpAndSettle();

        expect(navigatedToForms, isTrue);

        client.close();
      },
    );
  });
}
