import 'package:beauty_clinic_app/features/appointments/data/clinic_time.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/booking_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 22:30 UTC is next day in Hebron.
  final acrossMidnight = DateTime.utc(2026, 8, 11, 22, 30);

  tearDown(ClinicTime.reset);

  group('ClinicTime', () {
    test('reads an instant in the clinic zone, not UTC', () {
      ClinicTime.use('Asia/Hebron');

      expect(acrossMidnight.toUtc().day, 11);
      expect(ClinicTime.at(acrossMidnight).day, 12);
    });

    test('falls back to the device zone when unset', () {
      expect(ClinicTime.at(acrossMidnight), acrossMidnight.toLocal());
    });

    test('ignores an unknown zone rather than throwing', () {
      ClinicTime.use('Not/AZone');

      expect(ClinicTime.at(acrossMidnight), acrossMidnight.toLocal());
    });

    // The backend may configure a bare UTC.
    test('a bare UTC name resolves rather than falling back', () {
      ClinicTime.use('UTC');

      expect(ClinicTime.at(acrossMidnight).hour, 22);
      expect(ClinicTime.at(acrossMidnight).day, 11);
    });

    test('a later reset returns to the device zone', () {
      ClinicTime.use('Asia/Hebron');
      ClinicTime.reset();

      expect(ClinicTime.at(acrossMidnight), acrossMidnight.toLocal());
    });
  });

  group('BookingFormat', () {
    test('day() moves an instant into the clinic day', () {
      ClinicTime.use('Asia/Hebron');

      expect(BookingFormat.day(acrossMidnight), contains('12 Aug'));
    });

    // Picked days are date-only, never shifted.
    test('calendarDay() ignores the clinic zone entirely', () {
      final picked = DateTime(2026, 8, 12);

      ClinicTime.use('Pacific/Kiritimati');
      final farEast = BookingFormat.calendarDay(picked);
      ClinicTime.use('Pacific/Midway');
      final farWest = BookingFormat.calendarDay(picked);

      expect(farEast, contains('12 Aug'));
      expect(farWest, farEast);
    });

    test('hour12 normalises the end of the timeline', () {
      expect(BookingFormat.hour12(9), '9 AM');
      expect(BookingFormat.hour12(18), '6 PM');
      expect(BookingFormat.hour12(24), '12 AM');
    });
  });
}
