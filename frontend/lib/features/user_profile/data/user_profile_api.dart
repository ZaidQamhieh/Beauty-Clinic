import 'package:dio/dio.dart';

import '../../../network/api_client.dart';

class UserProfileException implements Exception {
  const UserProfileException(this.message);

  final String message;
}

class IncorrectCurrentPasswordException extends UserProfileException {
  const IncorrectCurrentPasswordException()
    : super('The current password is incorrect.');
}

class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.status,
    this.dateOfBirth,
    this.gender,
    this.specializations = const [],
    this.yearsOfExperience,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String status;
  final DateTime? dateOfBirth;
  final String? gender;
  final List<String> specializations;
  final int? yearsOfExperience;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final doctorProfile = json['doctorProfile'];
    final doctor = doctorProfile is Map
        ? Map<String, dynamic>.from(doctorProfile)
        : json;
    final rawSpecializations = doctor['specializations'];

    return UserProfile(
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      status: (json['status'] ?? 'ACTIVE').toString(),
      dateOfBirth: DateTime.tryParse((json['dateOfBirth'] ?? '').toString()),
      gender: json['gender']?.toString(),
      specializations: rawSpecializations is List
          ? rawSpecializations.map((value) => value.toString()).toList()
          : const [],
      yearsOfExperience: _asInt(doctor['yearsOfExperience']),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}

class UserProfileApi {
  const UserProfileApi(this._client);

  final ApiClient _client;

  Future<UserProfile> me() async {
    try {
      final response = await _client.get<dynamic>('/api/users/me');
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Invalid user profile payload.');
      }
      return UserProfile.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<UserProfile> update({
    required String firstName,
    required String lastName,
    required String phone,
    required DateTime dateOfBirth,
    required String gender,
    List<String>? specializations,
    int? yearsOfExperience,
  }) async {
    try {
      final data = <String, dynamic>{
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
        'dateOfBirth': dateOfBirth.toIso8601String().split('T').first,
        'gender': gender,
      };
      if (specializations != null) {
        data['specializations'] = specializations;
        data['yearsOfExperience'] = yearsOfExperience;
      }
      final response = await _client.put<dynamic>('/api/users/me', data: data);
      final payload = response.data;
      if (payload is! Map) {
        throw const FormatException('Invalid updated profile payload.');
      }
      return UserProfile.fromJson(Map<String, dynamic>.from(payload));
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.put<dynamic>(
        '/api/users/me/password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Object _mapError(DioException error) {
    final status = error.response?.statusCode;
    final responseMessage = _responseMessage(error.response?.data);
    if ((status == 400 || status == 422) &&
        _isIncorrectPasswordMessage(responseMessage)) {
      return const IncorrectCurrentPasswordException();
    }
    if (status == 401) {
      return const FormatException('Session expired.');
    }
    if (status == 403) {
      return const FormatException('You cannot edit this profile.');
    }
    if (status == 400 || status == 422) {
      return const FormatException('The submitted profile data is invalid.');
    }
    return error;
  }

  String _responseMessage(Object? data) {
    if (data is! Map) {
      return '';
    }
    return (data['message'] ?? data['detail'] ?? data['error'] ?? '')
        .toString()
        .toLowerCase();
  }

  bool _isIncorrectPasswordMessage(String message) {
    return message.contains('current password') &&
        (message.contains('incorrect') ||
            message.contains('invalid') ||
            message.contains('wrong'));
  }
}
