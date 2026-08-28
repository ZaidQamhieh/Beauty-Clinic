import '../../../network/api_client.dart';
import 'package:dio/dio.dart';

class DoctorAvailabilityException implements Exception {
  const DoctorAvailabilityException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when a save would have no effect on some dates because a
/// higher-priority rule already covers them there. Not fatal: resubmit the
/// same request with acknowledgeShadow: true to save anyway.
class DoctorAvailabilityShadowedException implements Exception {
  const DoctorAvailabilityShadowedException(
    this.message, {
    required this.shadowedBy,
    required this.affectedDates,
  });

  final String message;

  /// Null when what's shadowing it is "the day's own schedule" (the
  /// EXTRA_DAY case) rather than one named higher-priority kind.
  final AvailabilityKind? shadowedBy;
  final List<DateTime> affectedDates;

  @override
  String toString() => message;
}

/// Thrown when a save would leave an already-booked appointment outside the
/// newly-resolved working hours. Never resubmittable - there is no override.
class DoctorAvailabilityConflictException implements Exception {
  const DoctorAvailabilityConflictException(this.message, this.conflicts);

  final String message;
  final List<Map<String, dynamic>> conflicts;

  @override
  String toString() => message;
}

/// REGULAR is the weekly pattern. VACATION/MODIFIED/EXTRA_DAY are dated
/// exceptions, resolved by priority: VACATION and MODIFIED replace the day
/// outright (VACATION beats MODIFIED); EXTRA_DAY only ever fills a day that
/// would otherwise resolve to no working hours at all.
enum AvailabilityKind { regular, vacation, modified, extraDay }

String _kindWire(AvailabilityKind kind) => switch (kind) {
  AvailabilityKind.regular => 'REGULAR',
  AvailabilityKind.vacation => 'VACATION',
  AvailabilityKind.modified => 'MODIFIED',
  AvailabilityKind.extraDay => 'EXTRA_DAY',
};

// .byName doesn't round-trip EXTRA_DAY (would need .extraDay.name == 'EXTRA_DAY',
// but Dart enum names can't contain underscores in that shape), so kind names are
// mapped explicitly both ways instead of relying on .name/.byName.
AvailabilityKind _kindFromWire(String? value) => switch (value?.toUpperCase()) {
  'VACATION' => AvailabilityKind.vacation,
  'MODIFIED' => AvailabilityKind.modified,
  'EXTRA_DAY' => AvailabilityKind.extraDay,
  _ => AvailabilityKind.regular,
};

enum AvailabilityDay {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

enum DayAvailabilityStatus { available, unavailable, none }

class DoctorAvailabilityDayStatus {
  const DoctorAvailabilityDayStatus({required this.date, required this.status});

  final DateTime date;
  final DayAvailabilityStatus status;

  factory DoctorAvailabilityDayStatus.fromJson(Map<String, dynamic> json) {
    return DoctorAvailabilityDayStatus(
      date: DateTime.parse(json['date'].toString()),
      status: DayAvailabilityStatus.values.byName(
        (json['status'] ?? 'NONE').toString().toLowerCase(),
      ),
    );
  }
}

class DoctorAvailability {
  const DoctorAvailability({
    required this.id,
    required this.kind,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.effectiveFrom,
    required this.effectiveTo,
  });

  final String id;
  final AvailabilityKind kind;
  final AvailabilityDay? dayOfWeek;

  /// Null for VACATION, which carries no time window.
  final String? startTime;
  final String? endTime;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;

  /// True once this entry's effective range has fully ended (its
  /// effective-to date is before today). An ended entry is history: it can
  /// only be viewed, never edited or removed, so what actually happened on
  /// those past dates can't be rewritten after the fact.
  bool get hasEnded {
    final to = effectiveTo;
    if (to == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return to.isBefore(today);
  }

  factory DoctorAvailability.fromJson(Map<String, dynamic> json) {
    return DoctorAvailability(
      id: (json['id'] ?? '').toString(),
      kind: _kindFromWire(json['kind']?.toString()),
      dayOfWeek: _day(json['dayOfWeek']?.toString()),
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      effectiveFrom: DateTime.parse(json['effectiveFrom'].toString()),
      effectiveTo: json['effectiveTo'] == null
          ? null
          : DateTime.parse(json['effectiveTo'].toString()),
    );
  }

  static AvailabilityDay? _day(String? value) {
    if (value == null) return null;
    return AvailabilityDay.values.byName(value.toLowerCase());
  }
}

class DoctorAvailabilityApi {
  DoctorAvailabilityApi(this._client);

  final ApiClient _client;
  Future<String>? _doctorId;

  Future<String> _currentDoctorId() {
    final cached = _doctorId;
    if (cached != null) {
      return cached;
    }
    final pending = _fetchDoctorId();
    _doctorId = pending;
    return pending;
  }

  Future<String> _fetchDoctorId() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/api/users/me');
      final id = response.data?['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const FormatException('The signed-in doctor has no user id.');
      }
      return id;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<DoctorAvailability>> list() async {
    try {
      final doctorId = await _currentDoctorId();
      final response = await _client.get<List<dynamic>>(
        '/api/doctors/$doctorId/availability',
      );
      return (response.data ?? const [])
          .map(
            (json) => DoctorAvailability.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<DoctorAvailability>> listForDoctor(String doctorId) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/api/doctors/$doctorId/availability',
      );
      return (response.data ?? const [])
          .map(
            (json) => DoctorAvailability.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<DoctorAvailabilityDayStatus>> calendar({
    required DateTime from,
    required DateTime to,
    String? doctorId,
  }) async {
    try {
      final id = doctorId ?? await _currentDoctorId();
      final response = await _client.get<List<dynamic>>(
        '/api/doctors/$id/availability/calendar',
        queryParameters: {'from': _date(from), 'to': _date(to)},
      );
      return (response.data ?? const [])
          .map(
            (json) => DoctorAvailabilityDayStatus.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<DoctorAvailability> create({
    required AvailabilityKind kind,
    required AvailabilityDay? dayOfWeek,
    required String? startTime,
    required String? endTime,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    bool acknowledgeShadow = false,
    String? doctorId,
  }) async {
    final id = doctorId ?? await _currentDoctorId();
    return _write(
      '/api/doctors/$id/availability',
      'POST',
      _body(
        kind,
        dayOfWeek,
        startTime,
        endTime,
        effectiveFrom,
        effectiveTo,
        acknowledgeShadow,
      ),
    );
  }

  Future<DoctorAvailability> update(
    DoctorAvailability item, {
    required AvailabilityKind kind,
    required AvailabilityDay? dayOfWeek,
    required String? startTime,
    required String? endTime,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    bool acknowledgeShadow = false,
    String? doctorId,
  }) async {
    final id = doctorId ?? await _currentDoctorId();
    return _write(
      '/api/doctors/$id/availability/${item.id}',
      'PUT',
      _body(
        kind,
        dayOfWeek,
        startTime,
        endTime,
        effectiveFrom,
        effectiveTo,
        acknowledgeShadow,
      ),
    );
  }

  Future<void> remove(DoctorAvailability item, {String? doctorId}) async {
    try {
      final id = doctorId ?? await _currentDoctorId();
      await _client.delete<void>('/api/doctors/$id/availability/${item.id}');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  /// Truncates [item] to end the day before [splitDate], atomically. When
  /// [newSegment] is given it becomes a fresh record starting on
  /// [splitDate] (an edit to an already-started entry); when it's null,
  /// nothing replaces what's dropped (deleting only the future, history
  /// left untouched). Both rows are checked together against booked
  /// appointments, so a gap that would orphan one is never silently
  /// created between two separate calls.
  Future<List<DoctorAvailability>> split(
    DoctorAvailability item, {
    required DateTime splitDate,
    AvailabilityKind? newKind,
    AvailabilityDay? newDayOfWeek,
    String? newStartTime,
    String? newEndTime,
    DateTime? newEffectiveTo,
    bool acknowledgeShadow = false,
    String? doctorId,
  }) async {
    final id = doctorId ?? await _currentDoctorId();
    try {
      final response = await _client.post<dynamic>(
        '/api/doctors/$id/availability/${item.id}/split',
        data: {
          'splitDate': _date(splitDate),
          'newSegment': newKind == null
              ? null
              : _body(
                  newKind,
                  newDayOfWeek,
                  newStartTime,
                  newEndTime,
                  splitDate,
                  newEffectiveTo,
                  acknowledgeShadow,
                ),
        },
      );
      return (response.data as List)
          .map(
            (json) => DoctorAvailability.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Map<String, dynamic> _body(
    AvailabilityKind kind,
    AvailabilityDay? day,
    String? start,
    String? end,
    DateTime from,
    DateTime? to,
    bool acknowledgeShadow,
  ) => {
    'kind': _kindWire(kind),
    'dayOfWeek': day?.name.toUpperCase(),
    'startTime': start,
    'endTime': end,
    'effectiveFrom': _date(from),
    'effectiveTo': to == null ? null : _date(to),
    'acknowledgeShadow': acknowledgeShadow,
  };

  Future<DoctorAvailability> _write(
    String path,
    String method,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = method == 'POST'
          ? await _client.post<dynamic>(path, data: body)
          : await _client.put<dynamic>(path, data: body);
      return DoctorAvailability.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Exception _mapError(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map) {
      final code = data['code']?.toString();
      final detail = data['detail']?.toString();

      if (status == 422 && code == 'AVAILABILITY_SHADOWED') {
        final dates = data['affectedDates'];
        return DoctorAvailabilityShadowedException(
          detail ?? "This won't take effect on some dates.",
          shadowedBy: data['shadowedBy'] == null
              ? null
              : _kindFromWire(data['shadowedBy'].toString()),
          affectedDates: dates is List
              ? dates.map((d) => DateTime.parse(d.toString())).toList()
              : const [],
        );
      }
      if (status == 409 && code == 'AVAILABILITY_BOOKED_CONFLICT') {
        final conflicts = data['conflicts'];
        return DoctorAvailabilityConflictException(
          detail ?? 'Booked appointments would be affected.',
          conflicts is List
              ? conflicts
                    .map((c) => Map<String, dynamic>.from(c as Map))
                    .toList()
              : const [],
        );
      }

      if (detail != null && detail.isNotEmpty) {
        return DoctorAvailabilityException(detail);
      }
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        return DoctorAvailabilityException(
          errors.values.map((value) => value.toString()).join(' '),
        );
      }
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return DoctorAvailabilityException(message);
      }
    }
    return DoctorAvailabilityException(
      'Request failed${status == null ? '' : ' ($status)'}.',
    );
  }

  String _date(DateTime value) => value.toIso8601String().split('T').first;
}
