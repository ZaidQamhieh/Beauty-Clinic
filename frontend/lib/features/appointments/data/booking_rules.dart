/// Clinic booking rules the client must honour.
class BookingRules {
  const BookingRules({
    required this.timezone,
    required this.maxHorizonDays,
    required this.cancellationCutoffMinutes,
  });

  final String timezone;
  final int maxHorizonDays;
  final int cancellationCutoffMinutes;

  factory BookingRules.fromJson(Map<String, dynamic> json) {
    return BookingRules(
      timezone: json['timezone'] as String,
      maxHorizonDays: (json['maxHorizonDays'] as num).toInt(),
      cancellationCutoffMinutes:
          (json['cancellationCutoffMinutes'] as num).toInt(),
    );
  }
}
