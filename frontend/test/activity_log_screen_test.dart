import 'package:beauty_clinic_app/features/activity_log/presentation/activity_log_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';
import 'helpers/screen_harness.dart';

void main() {
  Map<String, dynamic> pageOf(List<Map<String, dynamic>> entries) => {
    'content': entries,
    'totalPages': 1,
    'totalElements': entries.length,
    'number': 0,
    'size': 20,
  };

  final entry = {
    'id': '11111111-1111-1111-1111-111111111111',
    'action': 'PATIENT_REGISTERED_BY_STAFF',
    'createdAt': '2026-08-29T09:00:00Z',
    'category': 'PATIENT',
    'actorName': 'Site Admin',
    'patientName': 'Noor Abadi',
    'entityType': 'patient_profile',
    'attemptedIdentifier': null,
    'correlationId': null,
    'oldValues': null,
    'newValues': null,
  };

  Widget screen(AuthSessionHarness b) =>
      ActivityLogScreen(authSession: b.session, apiClient: b.client);

  testWidgets('renders the entries the server returns', (tester) async {
    final adapter = QueueAdapter(
      List.filled(6, (_) => jsonResponse(200, pageOf([entry]))),
    );

    final bound = await pumpScreen(tester, adapter, screen);

    expect(find.text('Activity Log'), findsOneWidget);
    expect(find.textContaining('Noor Abadi'), findsWidgets);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('an empty page says nothing matched the filters', (tester) async {
    final adapter = QueueAdapter(
      List.filled(6, (_) => jsonResponse(200, pageOf(const []))),
    );

    final bound = await pumpScreen(tester, adapter, screen);

    expect(find.textContaining('No events match'), findsOneWidget);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('a 403 names administrators as the only viewers', (tester) async {
    final adapter = QueueAdapter(
      List.filled(6, (_) => jsonResponse(403, const {'detail': 'forbidden'})),
    );

    final bound = await pumpScreen(tester, adapter, screen);

    expect(find.text('The activity log is admin only'), findsOneWidget);

    bound.dispose();
    await settle(tester);
  });

  testWidgets('a server failure offers a retry', (tester) async {
    final adapter = QueueAdapter(
      List.filled(6, (_) => jsonResponse(500, const {'detail': 'boom'})),
    );

    final bound = await pumpScreen(tester, adapter, screen);

    expect(find.text('Could not reach the server'), findsOneWidget);
    expect(find.text('Try again'), findsWidgets);

    bound.dispose();
    await settle(tester);
  });
}
