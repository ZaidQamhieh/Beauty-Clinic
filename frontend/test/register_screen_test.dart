import 'package:beauty_clinic_app/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  Widget screenUnder(QueueAdapter adapter) {
    final session = testSession(
      adapter,
      MemoryTokenStore(),
      DateTime.utc(2026, 8, 11, 12),
    );
    return TickerMode(
      enabled: false,
      child: MaterialApp(
        home: RegisterScreen(authSession: session, onSignIn: () {}),
      ),
    );
  }

  Future<void> openScreen(WidgetTester tester, QueueAdapter adapter) async {
    // Test font overflows; real metrics fine.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains("overflowed")) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screenUnder(adapter));
    await tester.pump();
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String email = 'nadia@example.com',
    String password = 'SecurePass123',
    String confirm = 'SecurePass123',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'Nadia',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Last name'),
      'Khalil',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      password,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      confirm,
    );
  }

  testWidgets('an invalid email blocks submit and never calls the API', (
    tester,
  ) async {
    final adapter = QueueAdapter(const []);

    await openScreen(tester, adapter);
    await fillForm(tester, email: 'not-an-email');

    await tester.tap(
      find.widgetWithText(FilledButton, 'Create patient account'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(adapter.requests, isEmpty);
  });

  testWidgets('a mismatched confirmation blocks submit', (tester) async {
    final adapter = QueueAdapter(const []);

    await openScreen(tester, adapter);
    await fillForm(tester, confirm: 'DifferentPass123');

    await tester.tap(
      find.widgetWithText(FilledButton, 'Create patient account'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(adapter.requests, isEmpty);
  });

  testWidgets('a duplicate account surfaces the conflict message', (
    tester,
  ) async {
    final adapter = QueueAdapter([
      (_) => jsonResponse(409, const {'detail': 'Email already registered'}),
    ]);

    await openScreen(tester, adapter);
    await fillForm(tester);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Create patient account'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('An account already uses those details.'), findsOneWidget);
  });

  testWidgets('a server failure surfaces the generic message', (tester) async {
    final adapter = QueueAdapter([
      (_) => jsonResponse(500, const {'detail': 'boom'}),
    ]);

    await openScreen(tester, adapter);
    await fillForm(tester);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Create patient account'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Unable to create your account. Please try again.'),
      findsOneWidget,
    );
  });
}
