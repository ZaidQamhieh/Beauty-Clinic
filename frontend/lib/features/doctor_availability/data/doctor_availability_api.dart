import '../../../network/api_client.dart';
import 'package:dio/dio.dart';

class DoctorAvailabilityException implements Exception {
  const DoctorAvailabilityException(this.message);

  final String message;
}

enum AvailabilityKind { recurring, override }

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
    required this.available,
    required this.effectiveFrom,
    required this.effectiveTo,
  });

  final String id;
  final AvailabilityKind kind;
  final AvailabilityDay? dayOfWeek;
  final String startTime;
  final String endTime;
  final bool available;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;

  factory DoctorAvailability.fromJson(Map<String, dynamic> json) {
    return DoctorAvailability(
      id: (json['id'] ?? '').toString(),
      kind: AvailabilityKind.values.byName(
        (json['kind'] ?? 'RECURRING').toString().toLowerCase(),
      ),
      dayOfWeek: _day(json['dayOfWeek']?.toString()),
      startTime: (json['startTime'] ?? '').toString(),
      endTime: (json['endTime'] ?? '').toString(),
      available: json['available'] == true,
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
  }) async {
    try {
      final doctorId = await _currentDoctorId();
      final response = await _client.get<List<dynamic>>(
        '/api/doctors/$doctorId/availability/calendar',
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
    required String startTime,
    required String endTime,
    required bool available,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
  }) async {
    final doctorId = await _currentDoctorId();
    return _write(
      '/api/doctors/$doctorId/availability',
      'POST',
      _body(
        kind,
        dayOfWeek,
        startTime,
        endTime,
        available,
        effectiveFrom,
        effectiveTo,
      ),
    );
  }

  Future<DoctorAvailability> update(
    DoctorAvailability item, {
    required AvailabilityKind kind,
    required AvailabilityDay? dayOfWeek,
    required String startTime,
    required String endTime,
    required bool available,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
  }) async {
    final doctorId = await _currentDoctorId();
    return _write(
      '/api/doctors/$doctorId/availability/${item.id}',
      'PUT',
      _body(
        kind,
        dayOfWeek,
        startTime,
        endTime,
        available,
        effectiveFrom,
        effectiveTo,
      ),
    );
  }

  Future<void> remove(DoctorAvailability item) async {
    try {
      final doctorId = await _currentDoctorId();
      await _client.delete<void>(
        '/api/doctors/$doctorId/availability/${item.id}',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Map<String, dynamic> _body(
    AvailabilityKind kind,
    AvailabilityDay? day,
    String start,
    String end,
    bool available,
    DateTime from,
    DateTime? to,
  ) => {
    'kind': kind.name.toUpperCase(),
    'dayOfWeek': day?.name.toUpperCase(),
    'startTime': start,
    'endTime': end,
    'available': available,
    'effectiveFrom': _date(from),
    'effectiveTo': to == null ? null : _date(to),
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
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail']?.toString();
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
      'Request failed${error.response?.statusCode == null ? '' : ' (${error.response!.statusCode})'}.',
    );
  }

  String _date(DateTime value) => value.toIso8601String().split('T').first;
}
