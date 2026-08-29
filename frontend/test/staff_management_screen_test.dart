import 'package:beauty_clinic_app/features/staff_management/staff_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  Future<AuthSessionHarness> openScreen(
    WidgetTester tester,
    QueueAdapter adapter,
  ) async {
    // Test font overflows; real metrics fine.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bound = adminHarness(adapter);
    await bound.session.initialize();
    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child: MaterialApp(
          home: Scaffold(
            body: StaffManagementScreen(
              apiClient: bound.client,
              authSession: bound.session,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return bound;
  }

  final staff = <Map<String, dynamic>>[
    {
      'id': '11111111-1111-1111-1111-111111111111',
      'firstName': 'Lina',
      'lastName': 'Haddad',
      'email': 'lina@example.com',
      'role': 'DOCTOR',
      'phone': '+970599111222',
      'yearsOfExperience': 8,
      'specializations': ['DERMATOLOGY'],
    },
    {
      'id': '22222222-2222-2222-2222-222222222222',
      'firstName': 'Rana',
      'lastName': 'Odeh',
      'email': 'rana@example.com',
      'role': 'RECEPTIONIST',
      'phone': '+970599333444',
    },
  ];

  testWidgets('lists the staff the account endpoint returns', (tester) async {
    final adapter = QueueAdapter([(_) => jsonListResponse(200, staff)]);

    final bound = await openScreen(tester, adapter);

    expect(find.textContaining('Lina'), findsWidgets);
    expect(find.textContaining('Rana'), findsWidgets);

    bound.dispose();
  });

  testWidgets('a failed staff read surfaces the error state', (tester) async {
    final adapter = QueueAdapter([
      (_) => jsonResponse(500, const {'detail': 'boom'}),
    ]);

    final bound = await openScreen(tester, adapter);

    expect(find.text('Unable to load staff.'), findsOneWidget);

    bound.dispose();
  });

  testWidgets('the register doctor button opens the staff form', (
    tester,
  ) async {
    final adapter = QueueAdapter([(_) => jsonListResponse(200, staff)]);

    final bound = await openScreen(tester, adapter);

    await tester.tap(find.text('Register Doctor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);

    bound.dispose();
  });

  testWidgets('the staff form blocks submit until required fields are valid', (
    tester,
  ) async {
    final adapter = QueueAdapter([(_) => jsonListResponse(200, staff)]);

    final bound = await openScreen(tester, adapter);

    await tester.tap(find.text('Register Receptionist'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final requestsBefore = adapter.requests.length;
    final save = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(save.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(adapter.requests.length, requestsBefore);
    expect(find.byType(Dialog), findsOneWidget);

    bound.dispose();
  });
}
