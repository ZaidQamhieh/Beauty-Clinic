import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The clinic's wall clock, shared by screens.
abstract final class ClinicTime {
  static tz.Location? _clinic;
  static bool _databaseReady = false;

  /// Set from booking rules; unknown zones ignored.
  static void use(String timezone) {
    if (!_databaseReady) {
      tzdata.initializeTimeZones();
      _databaseReady = true;
    }
    try {
      _clinic = tz.getLocation(timezone);
    } on tz.LocationNotFoundException {
      // The database has no bare UTC entry.
      _clinic = timezone == 'UTC' ? tz.UTC : null;
    }
  }

  /// Clear the active clinic timezone.
  static void reset() {
    _clinic = null;
  }

  /// The instant as the clinic reads it.
  static DateTime at(DateTime instant) {
    final clinic = _clinic;
    return clinic == null
        ? instant.toLocal()
        : tz.TZDateTime.from(instant, clinic);
  }
}
