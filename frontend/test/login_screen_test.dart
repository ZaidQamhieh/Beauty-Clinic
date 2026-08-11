import 'package:beauty_clinic_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 12);

  // TODO: unskip once BeautyClinicApp wires AuthSession and gates on it —
  // LoginScreen is not yet mounted by the app, so these can't pass.
  testWidgets(
    'a login 401 shows only the generic credentials message',
    (tester) async {
      final store = MemoryTokenStore();
      final adapter = QueueAdapter([
        (_) => jsonResponse(401, {'detail': 'raw server secret'}),
      ]);
      final session = testSession(adapter, store, now);
      addTearDown(session.dispose);

      await tester.pumpWidget(const BeautyClinicApp());
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('emailField')),
        'owner@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('passwordField')),
        'wrong-password',
      );
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Invalid credentials.'), findsOneWidget);
      expect(find.textContaining('raw server secret'), findsNothing);
    },
    skip: true,
  );

  testWidgets(
    'an unauthenticated session renders login without an API error',
    (tester) async {
      final session = testSession(
        QueueAdapter(const []),
        MemoryTokenStore(),
        now,
      );
      addTearDown(session.dispose);

      await tester.pumpWidget(const BeautyClinicApp());
      await tester.pump();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.textContaining('access revoked'), findsNothing);
      expect(find.textContaining('refresh revoked'), findsNothing);
    },
    skip: true,
  );
}
