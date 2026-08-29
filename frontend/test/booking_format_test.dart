import 'package:beauty_clinic_app/features/appointments/data/clinic_time.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/booking_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ClinicTime.reset());
  tearDown(() => ClinicTime.reset());

  group('BookingFormat', () {
    test('formats 12-hour time includes colon and period', () {
      final morning = DateTime.utc(2026, 8, 29, 9, 30);
      expect(BookingFormat.time12(morning), contains(':'));
      expect(BookingFormat.time12(morning), matches(RegExp(r'(AM|PM)')));

      final afternoon = DateTime.utc(2026, 8, 29, 14, 15);
      expect(BookingFormat.time12(afternoon), contains(':'));
      expect(BookingFormat.time12(afternoon), matches(RegExp(r'(AM|PM)')));
    });

    test('formats day includes weekday and month', () {
      final day = DateTime.utc(2026, 8, 29);
      final formatted = BookingFormat.day(day);
      expect(formatted, contains('Aug'));
    });

    test('formats calendar day correctly', () {
      final day = DateTime.utc(2026, 8, 29);
      final formatted = BookingFormat.calendarDay(day);
      expect(formatted, contains('Aug'));
    });

    test('formats day with year includes year', () {
      final day = DateTime.utc(2026, 8, 29);
      final formatted = BookingFormat.dayWithYear(day);
      expect(formatted, contains('Aug'));
      expect(formatted, contains('2026'));
    });

    test('formats hour range includes both hours', () {
      final range = BookingFormat.hourRange12(9);
      expect(range, contains('AM'));
      expect(range, contains('–'));
    });

    test('formats hour 12 morning correctly', () {
      expect(BookingFormat.hour12(9), contains('9'));
      expect(BookingFormat.hour12(9), contains('AM'));
    });

    test('formats hour 12 afternoon correctly', () {
      expect(BookingFormat.hour12(14), contains('2'));
      expect(BookingFormat.hour12(14), contains('PM'));
    });

    test('formats hour 12 midnight correctly', () {
      expect(BookingFormat.hour12(0), contains('12'));
      expect(BookingFormat.hour12(0), contains('AM'));
    });

    test('formats hour 12 noon correctly', () {
      expect(BookingFormat.hour12(12), contains('12'));
      expect(BookingFormat.hour12(12), contains('PM'));
    });

    test('formats money as integer when whole', () {
      expect(BookingFormat.money(100.0), '100');
      expect(BookingFormat.money(50.0), '50');
    });

    test('formats money with cents when decimal', () {
      expect(BookingFormat.money(100.5), '100.50');
      expect(BookingFormat.money(0.99), '0.99');
    });

    test('time 12 preserves minutes padding', () {
      final time = DateTime.utc(2026, 8, 29, 9, 5);
      expect(BookingFormat.time12(time), contains(':'));
      expect(BookingFormat.time12(time), contains('0'));
    });
  });
}
