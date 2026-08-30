import 'package:beauty_clinic_app/app.dart';
import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/auth/token_pair.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/appointment_card.dart';
import 'package:beauty_clinic_app/features/forms/data/clinical_intake_api.dart';
import 'package:beauty_clinic_app/features/forms/data/dynamic_form_api.dart';
import 'package:beauty_clinic_app/features/patient_profile/presentation/patient_profile_screen.dart';
import 'package:beauty_clinic_app/features/shell/presentation/app_shell.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  test(
    'History status stays planned while another session in the same visit is still planned',
    () {
      final appointment = Appointment(
        id: 'appt-1',
        patientUserId: 'patient-1',
        patientName: 'Test Patient',
        scheduledAt: DateTime(2026, 8, 24, 16, 0),
        status: 'BOOKED',
        replacesAppointmentId: null,
        sessions: [
          AppointmentSession(
            id: 'session-1',
            appointmentId: 'appt-1',
            practitionerUserId: 'doctor-1',
            practitionerName: 'Dr. Smith',
            category: 'LASER',
            treatmentName: 'LASER_HAIR_REMOVAL',
            priceCharged: 0,
            durationMinutes: 60,
            status: 'COMPLETED',
            startTime: DateTime(2026, 8, 24, 16, 0),
            endTime: DateTime(2026, 8, 24, 17, 0),
          ),
          AppointmentSession(
            id: 'session-2',
            appointmentId: 'appt-1',
            practitionerUserId: 'doctor-1',
            practitionerName: 'Dr. Smith',
            category: 'LASER',
            treatmentName: 'LASER_HAIR_REMOVAL',
            priceCharged: 0,
            durationMinutes: 60,
            status: 'PLANNED',
            startTime: DateTime(2026, 8, 25, 16, 0),
            endTime: DateTime(2026, 8, 25, 17, 0),
          ),
        ],
      );

      expect(HistoryCard.historyStatus(appointment), 'Planned');
    },
  );

  testWidgets('Beauty Clinic app shell smoke test', (
    WidgetTester tester,
  ) async {
    final now = DateTime.utc(2026, 8, 6, 12);
    final session = testSession(
      QueueAdapter(const []),
      MemoryTokenStore()
        ..value = TokenPair(
          accessToken: 'test-access-token',
          refreshToken: 'test-refresh-token',
          expiresAt: now.add(const Duration(hours: 1)),
          role: Role.admin,
        ),
      now,
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(BeautyClinicApp(authSession: session));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('YASMINE'), findsWidgets);
  });

  testWidgets('Staff patient profile includes prescriptions and products tab', (
    WidgetTester tester,
  ) async {
    final now = DateTime.utc(2026, 8, 6, 12);
    final session = testSession(
      QueueAdapter([(_) async => jsonResponse(200, <String, dynamic>{})]),
      MemoryTokenStore()
        ..value = TokenPair(
          accessToken: 'test-access-token',
          refreshToken: 'test-refresh-token',
          expiresAt: now.add(const Duration(hours: 1)),
          role: Role.doctor,
        ),
      now,
    );
    addTearDown(session.dispose);

    final client = ApiClient(
      session,
      dio: testDio(
        QueueAdapter([(_) async => jsonResponse(200, <String, dynamic>{})]),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PatientProfileScreen(
          clinicalApi: ClinicalIntakeApi(client),
          dynamicApi: DynamicFormApi(client),
          patientId: 'patient-42',
          canManageProducts: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Prescriptions & Products'), findsOneWidget);
  });

  testWidgets(
    'Products navigation is visible for staff and hidden for patients',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            activeRole: 'admin',
            activeView: 'dashboard',
            onViewChanged: (_) {},
            child: const SizedBox(),
          ),
        ),
      );
      expect(find.text('Products'), findsWidgets);

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            activeRole: 'receptionist',
            activeView: 'dashboard',
            onViewChanged: (_) {},
            child: const SizedBox(),
          ),
        ),
      );
      expect(find.text('Products'), findsWidgets);

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            activeRole: 'patient',
            activeView: 'patient_profile',
            onViewChanged: (_) {},
            child: const SizedBox(),
          ),
        ),
      );
      expect(find.text('Products'), findsNothing);
    },
  );
}
