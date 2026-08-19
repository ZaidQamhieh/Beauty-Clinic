import '../data/clinic_time.dart';

/// Date and time formatting for the booking screens.
abstract final class BookingFormat {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String day(DateTime instant) {
    final local = ClinicTime.at(instant);
    return '${_weekdays[local.weekday - 1]} ${local.day} ${_months[local.month - 1]}';
  }

  // A picked day, never zone-shifted.
  static String calendarDay(DateTime day) {
    return '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}';
  }

  static String dayWithYear(DateTime instant) {
    final local = ClinicTime.at(instant);
    return '${day(instant)} ${local.year}';
  }

  // 12-hour clock with AM/PM, e.g. 9:00 AM.
  static String time12(DateTime instant) {
    final local = ClinicTime.at(instant);
    return _clock12(local.hour, local.minute);
  }

  // The hour block a timeline segment covers.
  static String hourRange12(int hour24) {
    return '${_clock12(hour24, 0)} – ${_clock12((hour24 + 1) % 24, 0)}';
  }

  // A bare hour, e.g. "9 AM".
  static String hour12(int hour24) {
    final normalized = hour24 % 24;
    final period = normalized < 12 ? 'AM' : 'PM';
    final hour = normalized % 12;
    return '${hour == 0 ? 12 : hour} $period';
  }

  static String _clock12(int hour24, int minute) {
    final period = hour24 < 12 ? 'AM' : 'PM';
    var hour = hour24 % 12;
    if (hour == 0) hour = 12;
    return '$hour:${minute.toString().padLeft(2, '0')} $period';
  }

  static String money(double amount) {
    // Whole numbers drop trailing zeros.
    final isWhole = amount == amount.roundToDouble();
    return isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  }
}
