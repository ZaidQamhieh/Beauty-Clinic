import 'package:dio/dio.dart';

abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

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
