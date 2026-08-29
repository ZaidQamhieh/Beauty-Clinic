import 'package:beauty_clinic_app/features/landing/presentation/guest_landing_screen.dart';
import 'package:beauty_clinic_app/features/landing/presentation/landing_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/screen_harness.dart';

void main() {
  group('LandingScreen', () {
    testWidgets('shows the specialists it advertises', (tester) async {
      relaxLayout(tester);
      await tester.pumpWidget(
        wrapScreen(LandingScreen(onBookClick: () {}, onViewDoctor: (_) {})),
      );
      await settle(tester);

      expect(find.text('Meet Our Specialists'), findsOneWidget);
      expect(find.textContaining('Hana Nasser'), findsWidgets);
      expect(find.text('View Profile'), findsNWidgets(3));
    });

    testWidgets('booking calls back to the caller', (tester) async {
      relaxLayout(tester);
      var booked = 0;
      await tester.pumpWidget(
        wrapScreen(
          LandingScreen(onBookClick: () => booked++, onViewDoctor: (_) {}),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Book Your Consultation'));
      await settle(tester);

      expect(booked, 1);
    });

    testWidgets('a profile button reports which doctor was chosen', (
      tester,
    ) async {
      relaxLayout(tester);
      String? chosen;
      await tester.pumpWidget(
        wrapScreen(
          LandingScreen(onBookClick: () {}, onViewDoctor: (d) => chosen = d),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('View Profile').first);
      await settle(tester);

      expect(chosen, 'Dr. Hana Nasser');
    });
  });

  group('GuestLandingScreen', () {
    testWidgets('offers a login route', (tester) async {
      relaxLayout(tester);
      await tester.pumpWidget(wrapScreen(GuestLandingScreen(onLogin: () {})));
      await settle(tester);

      expect(find.text('Login'), findsWidgets);
    });

    testWidgets('login calls back to the caller', (tester) async {
      relaxLayout(tester);
      var logins = 0;
      await tester.pumpWidget(
        wrapScreen(GuestLandingScreen(onLogin: () => logins++)),
      );
      await settle(tester);

      await tester.tap(find.text('Login').first);
      await settle(tester);

      expect(logins, 1);
    });
  });
}
