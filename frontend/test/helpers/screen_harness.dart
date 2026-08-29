import 'package:beauty_clinic_app/auth/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_fakes.dart';

// The test font overflows where real metrics do not.
void relaxLayout(WidgetTester tester) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);

  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

// Decorative animations never settle, so tickers stay off.
Widget wrapScreen(Widget screen) {
  return TickerMode(
    enabled: false,
    child: MaterialApp(home: Scaffold(body: screen)),
  );
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

// Builds the session, pumps the screen and waits for its first load.
Future<AuthSessionHarness> pumpScreen(
  WidgetTester tester,
  QueueAdapter adapter,
  Widget Function(AuthSessionHarness) build, {
  Role role = Role.admin,
}) async {
  relaxLayout(tester);
  final bound = adminHarness(adapter, role: role);
  await bound.session.initialize();
  await tester.pumpWidget(wrapScreen(build(bound)));
  await settle(tester);
  return bound;
}
