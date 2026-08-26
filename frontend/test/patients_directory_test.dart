import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/auth/token_pair.dart';
import 'package:beauty_clinic_app/features/forms/data/clinical_intake_api.dart';
import 'package:beauty_clinic_app/features/patients/presentation/patients_directory_screen.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  testWidgets('PatientsDirectoryScreen lists patients and handles selection', (
    tester,
  ) async {
    final session = testSession(
      QueueAdapter(const []),
      MemoryTokenStore()
        ..value = TokenPair(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.utc(2026, 8, 11, 13),
          role: Role.admin,
        ),
      DateTime.utc(2026, 8, 11, 12),
    );

    final adapter = QueueAdapter([
      (_) => jsonResponse(200, {
        'content': [
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'firstName': 'Lina',
            'lastName': 'Haddad',
            'email': 'lina@example.com',
            'phone': '+970599111222',
            'skinType': 'OILY',
            'smokingStatus': 'NEVER',
            'pregnantBreastfeeding': false,
            'allergies': ['NUTS'],
            'medications': [],
            'chronicConditions': [],
          },
          {
            'id': '22222222-2222-2222-2222-222222222222',
            'firstName': 'Yara',
            'lastName': 'Saleh',
            'email': 'yara@example.com',
            'phone': '+970599333444',
            'skinType': null,
            'smokingStatus': null,
            'pregnantBreastfeeding': false,
            'allergies': [],
            'medications': [],
            'chronicConditions': [],
          },
        ],
      }),
    ]);

    final client = ApiClient(session, dio: testDio(adapter));
    final clinicalApi = ClinicalIntakeApi(client);

    String? selectedId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatientsDirectoryScreen(
            clinicalApi: clinicalApi,
            onSelectPatient: (id) => selectedId = id,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header and patients loaded
    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Lina Haddad'), findsOneWidget);
    expect(find.text('Yara Saleh'), findsOneWidget);

    // Check badges
    expect(find.text('Intake Complete'), findsOneWidget);
    expect(find.text('Intake Pending'), findsOneWidget);

    // Tap on Lina's card
    await tester.tap(find.text('Lina Haddad'));
    await tester.pumpAndSettle();

    expect(selectedId, '11111111-1111-1111-1111-111111111111');

    client.close();
    session.dispose();
  });
}
