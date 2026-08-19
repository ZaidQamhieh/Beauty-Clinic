import 'enum_label.dart';

/// One treatment within a visit.
class AppointmentSession {
  const AppointmentSession({
    required this.id,
    required this.appointmentId,
    required this.practitionerUserId,
    required this.practitionerName,
    required this.category,
    required this.treatmentName,
    required this.priceCharged,
    required this.durationMinutes,
    required this.status,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String appointmentId;
  final String practitionerUserId;
  final String practitionerName;
  final String category;
  final String treatmentName;
  final double priceCharged;
  final int durationMinutes;
  final String status; // PLANNED | COMPLETED | CANCELLED | NO_SHOW
  final DateTime startTime;
  final DateTime endTime;

  bool get isPlanned => status == 'PLANNED';

  String get treatmentLabel => humanizeEnum(treatmentName);

  factory AppointmentSession.fromJson(Map<String, dynamic> json) {
    return AppointmentSession(
      id: json['id'] as String,
      appointmentId: json['appointmentId'] as String,
      practitionerUserId: json['practitionerUserId'] as String,
      practitionerName: json['practitionerName'] as String,
      category: json['category'] as String,
      treatmentName: json['treatmentName'] as String,
      priceCharged: (json['priceCharged'] as num).toDouble(),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      status: json['status'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
    );
  }
}

/// A visit: who is treated, and when.
class Appointment {
  const Appointment({
    required this.id,
    required this.patientUserId,
    required this.patientName,
    required this.scheduledAt,
    required this.status,
    required this.replacesAppointmentId,
    required this.sessions,
  });

  final String id;
  final String patientUserId;
  final String patientName;
  final DateTime scheduledAt;
  final String status; // BOOKED | CANCELLED
  final String? replacesAppointmentId;
  final List<AppointmentSession> sessions;

  bool get isBooked => status == 'BOOKED';

  /// The treatments still to happen, in start order.
  List<AppointmentSession> get plannedSessions {
    final planned = sessions.where((s) => s.isPlanned).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return planned;
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final rawSessions = (json['sessions'] as List?) ?? const [];
    return Appointment(
      id: json['id'] as String,
      patientUserId: json['patientUserId'] as String,
      patientName: json['patientName'] as String? ?? '',
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      status: json['status'] as String,
      replacesAppointmentId: json['replacesAppointmentId'] as String?,
      sessions: rawSessions
          .map(
            (s) => AppointmentSession.fromJson(
              Map<String, dynamic>.from(s as Map),
            ),
          )
          .toList(),
    );
  }
}

/// One page of appointments, mirroring Spring's Page.
class AppointmentPage {
  const AppointmentPage({required this.items, required this.isLast});

  final List<Appointment> items;
  final bool isLast;

  factory AppointmentPage.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] as List?) ?? const [];
    return AppointmentPage(
      items: content
          .map((a) => Appointment.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
      isLast: json['last'] as bool? ?? true,
    );
  }
}
