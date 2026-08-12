import 'package:dio/dio.dart';

import '../../../network/api_client.dart';
import 'appointment.dart';
import 'booking_exceptions.dart';
import 'booking_patient.dart';
import 'free_slot.dart';

/// A slot chosen earlier, held while searching.
class HeldSlot {
  const HeldSlot({
    required this.practitionerUserId,
    required this.startTime,
    required this.endTime,
  });

  final String practitionerUserId;
  final DateTime startTime;
  final DateTime endTime;

  Map<String, dynamic> toJson() => {
    'practitionerUserId': practitionerUserId,
    'startTime': startTime.toUtc().toIso8601String(),
    'endTime': endTime.toUtc().toIso8601String(),
  };
}

/// One treatment to book: doctor, treatment, start.
class SessionDraft {
  const SessionDraft({
    required this.practitionerUserId,
    required this.treatmentName,
    required this.startTime,
  });

  final String practitionerUserId;
  final String treatmentName;
  final DateTime startTime;

  Map<String, dynamic> toJson() => {
    'practitionerUserId': practitionerUserId,
    'treatmentName': treatmentName,
    'startTime': startTime.toUtc().toIso8601String(),
  };
}

/// Talks to the appointment endpoints.
class AppointmentApi {
  const AppointmentApi(this._client);

  final ApiClient _client;

  /// The signed-in patient's own record.
  Future<BookingPatient> me() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/patients/me',
      );
      return BookingPatient.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  /// Times the booking endpoint will accept.
  Future<List<FreeSlot>> freeSlots({
    required String treatmentName,
    required DateTime date,
    String? patientUserId,
    List<HeldSlot> held = const [],
    String? replacesAppointmentId,
  }) async {
    try {
      final response = await _client.post<List<dynamic>>(
        '/api/appointments/free-slots',
        data: {
          'treatmentName': treatmentName,
          'date': _isoDate(date),
          'patientUserId': patientUserId,
          'held': held.map((h) => h.toJson()).toList(),
          'replacesAppointmentId': replacesAppointmentId,
        },
      );
      final data = response.data ?? const [];
      return data
          .map(
            (json) => FreeSlot.fromJson(Map<String, dynamic>.from(json as Map)),
          )
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  /// Creates the visit; [replacesAppointmentId] reschedules.
  Future<Appointment> book({
    required String patientUserId,
    required List<SessionDraft> sessions,
    String? replacesAppointmentId,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/appointments',
        data: {
          'patientUserId': patientUserId,
          'sessions': sessions.map((s) => s.toJson()).toList(),
          'replacesAppointmentId': replacesAppointmentId,
        },
      );
      return Appointment.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<AppointmentPage> upcoming({int page = 0, int size = 20}) {
    return _page('/api/appointments/me/upcoming', page, size);
  }

  Future<AppointmentPage> history({int page = 0, int size = 20}) {
    return _page('/api/appointments/me/history', page, size);
  }

  /// Cancels the whole visit.
  Future<Appointment> cancel(String appointmentId) async {
    try {
      final response = await _client.put<Map<String, dynamic>>(
        '/api/appointments/$appointmentId/cancel',
      );
      return Appointment.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<AppointmentPage> _page(String path, int page, int size) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        path,
        queryParameters: {'page': page, 'size': size},
      );
      return AppointmentPage.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // Turns transport errors into domain errors.
  Object _mapError(DioException error) {
    final forbidden = error.error;
    if (forbidden is ForbiddenException) {
      return forbidden;
    }

    final status = error.response?.statusCode;
    final message = _messageFrom(error.response?.data);

    if (status == 409) {
      return BookingConflictException(
        message ?? 'That time is no longer available.',
      );
    }
    if (status == 400) {
      return BookingValidationException(
        message ?? 'That booking is not valid.',
      );
    }
    return error;
  }

  String? _messageFrom(Object? data) {
    if (data is Map) {
      final message = data['message'] ?? data['detail'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  String _isoDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
