import 'package:beauty_clinic_app/features/appointments/data/doctor_summary.dart';
import 'package:beauty_clinic_app/features/landing/presentation/guest_landing_screen.dart';
import 'package:beauty_clinic_app/features/landing/presentation/landing_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/screen_harness.dart';

const _doctorSeed = [
  DoctorSummary(
    userId: '1',
    fullName: 'Dr. Hana Nasser',
    specializations: ['DERMATOLOGY'],
    yearsOfExperience: 12,
    imageUrl: 'https://example.com/hana.jpg',
  ),
  DoctorSummary(
    userId: '2',
    fullName: 'Dr. Reem Khalil',
    specializations: ['AESTHETIC_MEDICINE'],
    yearsOfExperience: 9,
    imageUrl: null,
  ),
];

void main() {
  group('LandingScreen', () {
    testWidgets(
      'loads specialists from the doctor API without profile buttons',
      (tester) async {
        relaxLayout(tester);
        await tester.pumpWidget(
          wrapScreen(
            LandingScreen(
              onBookClick: () {},
              onViewDoctor: (_) {},
              doctorsFuture: Future.value(_doctorSeed),
            ),
          ),
        );
        await settle(tester);

        expect(find.text('Meet Our Specialists'), findsOneWidget);
        expect(find.textContaining('Dr. Hana Nasser'), findsOneWidget);
        expect(find.textContaining('Dr. Reem Khalil'), findsOneWidget);
        expect(
          find.text('Expert care tailored to your unique skin profile'),
          findsNothing,
        );
        expect(find.text('View Profile'), findsNothing);
      },
    );

    testWidgets('booking calls back to the caller', (tester) async {
      relaxLayout(tester);
      var booked = 0;
      await tester.pumpWidget(
        wrapScreen(
          LandingScreen(
            onBookClick: () => booked++,
            onViewDoctor: (_) {},
            doctorsFuture: Future.value(_doctorSeed),
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Book Your Consultation'));
      await settle(tester);

      expect(booked, 1);
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
