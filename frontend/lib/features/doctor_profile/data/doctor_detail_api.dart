import 'package:dio/dio.dart';

import '../../../network/api_client.dart';
import '../../dashboard/data/doctor_dashboard_models.dart';

class DoctorDetailException implements Exception {
  const DoctorDetailException(this.message);

  final String message;
}

/// A doctor's account + doctor-profile fields, as seen by an admin.
class DoctorAccountDetail {
  const DoctorAccountDetail({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    this.imageUrl,
    required this.gender,
    required this.status,
    required this.specializations,
    required this.yearsOfExperience,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime? dateOfBirth;
  final String? imageUrl;
  final String gender;
  final String status;
  final List<String> specializations;
  final int? yearsOfExperience;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory DoctorAccountDetail.fromJson(Map<String, dynamic> json) {
    final doctorProfile = json['doctorProfile'];
    final profileMap = doctorProfile is Map<String, dynamic>
        ? doctorProfile
        : <String, dynamic>{};
    final rawSpecializations = profileMap['specializations'];

    return DoctorAccountDetail(
      userId: (json['id'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      dateOfBirth: json['dateOfBirth'] == null
          ? null
          : DateTime.tryParse(json['dateOfBirth'].toString()),
      imageUrl: json['imageUrl']?.toString(),
      gender: (json['gender'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      specializations: rawSpecializations is List
          ? rawSpecializations.map((entry) => entry.toString()).toList()
          : <String>[],
      yearsOfExperience: profileMap['yearsOfExperience'] as int?,
    );
  }
}

/// A doctor's live duty status, as shown on the admin dashboard's "Staff
/// Today" list: 'In Session' | 'Available' | 'Off Duty'.
class DoctorLiveStatus {
  const DoctorLiveStatus({
    required this.status,
    required this.appointmentsToday,
  });

  final String status;
  final int appointmentsToday;

  factory DoctorLiveStatus.fromJson(Map<String, dynamic> json) {
    return DoctorLiveStatus(
      status: (json['status'] ?? 'Off Duty').toString(),
      appointmentsToday: (json['appointmentsToday'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Fetches a single doctor's account info and statistics for the admin-facing
/// doctor detail view.
class DoctorDetailApi {
  DoctorDetailApi(this._client);

  final ApiClient _client;

  Future<DoctorAccountDetail> fetchAccount(String doctorId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/admin/accounts/$doctorId',
      );
      return DoctorAccountDetail.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<DoctorLiveStatus> fetchLiveStatus(String doctorId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/admin/doctors/$doctorId/status',
      );
      return DoctorLiveStatus.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<DoctorDashboardData> fetchStatistics(
    String doctorId, {
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/admin/doctors/$doctorId/analytics',
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      );
      return DoctorDashboardData.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Exception _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail']?.toString() ?? data['message']?.toString();
      if (detail != null && detail.isNotEmpty) {
        return DoctorDetailException(detail);
      }
    }
    return DoctorDetailException(
      'Request failed'
      '${error.response?.statusCode == null ? '' : ' (${error.response!.statusCode})'}.',
    );
  }
}
