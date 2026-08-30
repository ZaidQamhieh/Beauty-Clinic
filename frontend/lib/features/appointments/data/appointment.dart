import 'package:flutter/material.dart';

import 'enum_label.dart';

class TreatmentIcons {
  static const Map<String, IconData> _iconByTreatment = {
    'HYDRAFACIAL': Icons.water_drop_rounded,
    'CHEMICAL_PEEL': Icons.auto_fix_high_rounded,
    'MICRONEEDLING': Icons.face_retouching_natural_rounded,
    'DERMAPLANING': Icons.cleaning_services_rounded,
    'LASER_HAIR_REMOVAL': Icons.flash_on_rounded,
    'LASER_RESURFACING': Icons.flash_on_rounded,
    'IPL_PHOTOFACIAL': Icons.bolt_rounded,
    'BOTOX': Icons.vaccines_rounded,
    'DERMAL_FILLER': Icons.opacity_rounded,
    'BODY_CONTOURING': Icons.fitness_center_rounded,
    'MESOTHERAPY': Icons.healing_rounded,
    'CONSULTATION': Icons.event_available_rounded,
  };

  static IconData iconFor(
    String? treatmentName, {
    IconData fallback = Icons.medical_services_outlined,
  }) {
    final normalized = (treatmentName ?? '')
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return _iconByTreatment[normalized] ?? fallback;
  }

  static Widget avatar(
    String? treatmentName, {
    double size = 34,
    Color backgroundColor = const Color(0xFFF9E9F3),
    Color iconColor = const Color(0xFFAD3B8D),
    IconData fallback = Icons.medical_services_outlined,
  }) {
    final icon = iconFor(treatmentName, fallback: fallback);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.52, color: iconColor),
    );
  }
}

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

  AppointmentSession withStatus(String next) => AppointmentSession(
    id: id,
    appointmentId: appointmentId,
    practitionerUserId: practitionerUserId,
    practitionerName: practitionerName,
    category: category,
    treatmentName: treatmentName,
    priceCharged: priceCharged,
    durationMinutes: durationMinutes,
    status: next,
    startTime: startTime,
    endTime: endTime,
  );

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

  Appointment copyWith({String? status, List<AppointmentSession>? sessions}) =>
      Appointment(
        id: id,
        patientUserId: patientUserId,
        patientName: patientName,
        scheduledAt: scheduledAt,
        status: status ?? this.status,
        replacesAppointmentId: replacesAppointmentId,
        sessions: sessions ?? this.sessions,
      );

  /// Treatments still to happen, soonest first.
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
