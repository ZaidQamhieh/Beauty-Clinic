/// One offered slot: doctor and start.
class FreeSlot {
  const FreeSlot({
    required this.practitionerUserId,
    required this.practitionerName,
    required this.startTime,
    required this.endTime,
  });

  final String practitionerUserId;
  final String practitionerName;
  final DateTime startTime;
  final DateTime endTime;

  factory FreeSlot.fromJson(Map<String, dynamic> json) {
    return FreeSlot(
      practitionerUserId: json['practitionerUserId'] as String,
      practitionerName: json['practitionerName'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
    );
  }

  // Doctor and start identify a slot.
  @override
  bool operator ==(Object other) =>
      other is FreeSlot &&
      other.practitionerUserId == practitionerUserId &&
      other.startTime == startTime;

  @override
  int get hashCode => Object.hash(practitionerUserId, startTime);
}
