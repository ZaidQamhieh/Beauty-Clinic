import 'package:beauty_clinic_app/features/forms/data/clinical_intake_api.dart';
import 'package:beauty_clinic_app/features/forms/presentation/admin_clinical_intake_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';
import 'helpers/screen_harness.dart';

void main() {
  final patients = <Map<String, dynamic>>[
    {
      'id': '11111111-1111-1111-1111-111111111111',
      'firstName': 'Noor',
      'lastName': 'Abadi',
      'email': 'noor@test.com',
      'phone': '0591111111',
      'skinType': 'COMBINATION',
      'smokingStatus': 'NEVER',
      'pregnantBreastfeeding': false,
      'allergies': ['NUTS'],
      'medications': <String>[],
      'chronicConditions': <String>[],
    },
  ];

  ResponseBody healthy(RequestOptions request) =>
      jsonResponse(200, {'content': patients});

  ResponseBody broken(RequestOptions request) =>
      jsonResponse(500, const {'detail': 'boom'});

  Widget screen(AuthSessionHarness b) =>
      AdminClinicalIntakeScreen(api: ClinicalIntakeApi(b.client));

  testWidgets('lists the patients returned by the clinical search', (
    tester,
  ) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(6, healthy)),
      screen,
    );

    expect(find.textContaining('Noor'), findsWidgets);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('a failed load explains itself and offers a retry', (
    tester,
  ) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(6, broken)),
      screen,
    );

    expect(
      find.textContaining('Unable to load clinical records'),
      findsOneWidget,
    );
    expect(find.text('Try Again'), findsOneWidget);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('it offers a search field over the records', (tester) async {
    final bound = await pumpScreen(
      tester,
      QueueAdapter(List.filled(6, healthy)),
      screen,
    );

    expect(find.byType(TextField), findsWidgets);

    bound.dispose();
    await settle(tester);
  });
}
