import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  // Local development keeps the existing backend default. Release builds use
  // relative URLs unless API_BASE_URL is supplied, so they target the origin
  // that served the Flutter app instead of a user's localhost.
  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    // Always use the local dev backend when running on a developer machine.
    return 'http://localhost:8081';
  }

  static Dio createDio({String? baseUrl}) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
        headers: const {Headers.acceptHeader: Headers.jsonContentType},
      ),
    );
  }
}
