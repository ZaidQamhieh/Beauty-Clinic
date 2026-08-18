import '../data/clinic_time.dart';
import '../data/free_slot.dart';

// The clinic day the timeline bar spans.
const int dayStartHour = 9;
const int dayEndHour = 18;

/// Slots per doctor, each in order.
Map<String, List<FreeSlot>> groupByDoctor(List<FreeSlot>? source) {
  final byDoctor = <String, List<FreeSlot>>{};
  for (final slot in source ?? const <FreeSlot>[]) {
    byDoctor.putIfAbsent(slot.practitionerUserId, () => []).add(slot);
  }
  for (final list in byDoctor.values) {
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
  }
  return byDoctor;
}

/// Every hour a slot runs through.
Set<int> freeHours(List<FreeSlot> slots) {
  final hours = <int>{};
  for (final slot in slots) {
    final start = ClinicTime.at(slot.startTime);
    // Last minute worked, so exact ends exclude.
    final lastMinute = ClinicTime.at(
      slot.endTime,
    ).subtract(const Duration(minutes: 1));
    hours.add(start.hour);
    for (var hour = start.hour + 1; hour <= lastMinute.hour; hour++) {
      hours.add(hour);
    }
  }
  return hours;
}

/// The usual bar, widened to cover outliers.
(int, int) timelineSpan(List<FreeSlot>? slots) {
  var start = dayStartHour;
  var end = dayEndHour;
  for (final hour in freeHours(slots ?? const <FreeSlot>[])) {
    if (hour < start) start = hour;
    if (hour >= end) end = hour + 1;
  }
  return (start, end);
}

/// Slots by period, each in start order.
Map<String, List<FreeSlot>> groupByPeriod(List<FreeSlot> slots) {
  final groups = <String, List<FreeSlot>>{
    'MORNING': [],
    'AFTERNOON': [],
    'EVENING': [],
  };
  for (final slot in slots) {
    final hour = ClinicTime.at(slot.startTime).hour;
    if (hour < 12) {
      groups['MORNING']!.add(slot);
    } else if (hour < 17) {
      groups['AFTERNOON']!.add(slot);
    } else {
      groups['EVENING']!.add(slot);
    }
  }
  for (final list in groups.values) {
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
  }
  return groups;
}
