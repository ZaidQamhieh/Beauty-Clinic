import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/doctor_availability/data/doctor_availability_api.dart';
import 'package:beauty_clinic_app/features/doctor_profile/presentation/doctor_profile_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';
import 'helpers/screen_harness.dart';

void main() {
  const doctorId = '11111111-1111-1111-1111-111111111111';

  ResponseBody healthy(RequestOptions request) {
    if (request.path.contains('/admin/accounts/')) {
      return jsonResponse(200, const {
        'id': doctorId,
        'firstName': 'Lina',
        'lastName': 'Haddad',
        'email': 'lina@test.com',
        'phone': '0590000002',
        'dateOfBirth': '1988-04-22',
        'gender': 'FEMALE',
        'status': 'ACTIVE',
        'doctorProfile': {
          'specializations': ['DERMATOLOGY', 'LASER_THERAPY'],
          'yearsOfExperience': 9,
        },
      });
    }
    if (request.path.contains('/status')) {
      return jsonResponse(200, const {'onDuty': true});
    }
    return jsonListResponse(200, const []);
  }

  // Only the profile read fails; siblings stay healthy.
  ResponseBody profileBroken(RequestOptions request) {
    if (request.path.contains('/admin/accounts/')) {
      return jsonResponse(500, const {'detail': 'boom'});
    }
    return healthy(request);
  }

  Widget screen(AuthSessionHarness b) => DoctorProfileScreen(
    doctorId: doctorId,
    apiClient: b.client,
    appointmentApi: AppointmentApi(b.client),
    availabilityApi: DoctorAvailabilityApi(b.client),
  );

  testWidgets('renders the doctor identity and specializations', (
    tester,
  ) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(12, healthy)),
      screen,
    );

    expect(find.textContaining('Lina'), findsWidgets);
    expect(find.text('Specializations'), findsWidgets);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('a failed profile read shows the profile error card', (
    tester,
  ) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(12, profileBroken)),
      screen,
    );

    expect(
      find.textContaining("Unable to load this doctor's profile."),
      findsWidgets,
    );

    bound.dispose();
    await settle(tester);
  });

  testWidgets('it reads the doctor by id from the admin accounts endpoint', (
    tester,
  ) async {
    final adapter = QueueAdapter(List.filled(12, healthy));
    final bound = await pumpScreen(tester, adapter, screen);

    expect(
      adapter.requests.any((r) => r.path.contains('/admin/accounts/$doctorId')),
      isTrue,
    );

    bound.dispose();
    await settle(tester);
  });
}
