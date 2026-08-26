import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beauty_clinic_app/features/doctor_availability/data/doctor_availability_api.dart';
import 'package:beauty_clinic_app/features/doctor_availability/presentation/widgets/availability_entry_dialog.dart';

// AlertDialog measures its content's intrinsic dimensions; a GridView (even
// shrinkWrap: true) is a Viewport, which can never report those - it used to
// crash the dialog open on every single use. These guard against that class
// of regression by actually building the dialog inside an AlertDialog/showDialog,
// the way the real screen opens it, for every kind and for both add and edit.
Future<void> _open(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<AvailabilityDraft>(
              context: context,
              builder: (context) => dialog,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'adding a REGULAR slot for a weekday opens and offers only Regular',
    (tester) async {
      await _open(
        tester,
        const AvailabilityEntryDialog(initialDay: AvailabilityDay.wednesday),
      );
      expect(find.text('Add availability'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Vacation / Leave'), findsNothing);
      expect(find.text('Modified Hours'), findsNothing);
      expect(find.text('Extra Working Day'), findsNothing);
    },
  );

  testWidgets(
    'adding an exception opens and offers only the three exception kinds',
    (tester) async {
      await _open(
        tester,
        const AvailabilityEntryDialog(initialKind: AvailabilityKind.vacation),
      );
      expect(find.text('Add availability'), findsOneWidget);
      expect(find.text('Vacation / Leave'), findsOneWidget);
      expect(find.text('Modified Hours'), findsOneWidget);
      expect(find.text('Extra Working Day'), findsOneWidget);
      expect(find.text('Regular'), findsNothing);
    },
  );

  testWidgets('plain add with no locked kind/day opens', (tester) async {
    await _open(tester, const AvailabilityEntryDialog());
    expect(find.text('Add availability'), findsOneWidget);
  });

  testWidgets('editing an existing REGULAR item opens', (tester) async {
    final item = DoctorAvailability(
      id: 'x',
      kind: AvailabilityKind.regular,
      dayOfWeek: AvailabilityDay.monday,
      startTime: '09:00:00',
      endTime: '17:00:00',
      effectiveFrom: DateTime(2026, 1, 1),
      effectiveTo: null,
    );
    await _open(tester, AvailabilityEntryDialog(initial: item));
    expect(find.text('Edit availability'), findsOneWidget);
  });

  testWidgets(
    'a validation failure shows inline in the dialog, not as a SnackBar',
    (tester) async {
      // A SnackBar renders on the root Scaffold, which sits behind this
      // dialog's modal barrier while it's open - it would show up dimmed and
      // hard to read there instead of inside the dialog where it's visible.
      await _open(
        tester,
        const AvailabilityEntryDialog(initialKind: AvailabilityKind.vacation),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Choose an effective-to date.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // Still open - a failed validation must not pop the dialog.
      expect(find.text('Add availability'), findsOneWidget);
    },
  );

  testWidgets('editing an existing VACATION item opens', (tester) async {
    final item = DoctorAvailability(
      id: 'y',
      kind: AvailabilityKind.vacation,
      dayOfWeek: null,
      startTime: null,
      endTime: null,
      effectiveFrom: DateTime(2026, 8, 20),
      effectiveTo: DateTime(2026, 8, 20),
    );
    await _open(tester, AvailabilityEntryDialog(initial: item));
    expect(find.text('Edit availability'), findsOneWidget);
  });
}
