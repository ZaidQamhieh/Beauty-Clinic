import 'package:beauty_clinic_app/app.dart';
import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/auth/token_pair.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
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
    await tester.pump();

    expect(find.text('YASMINE'), findsWidgets);
  });
}
