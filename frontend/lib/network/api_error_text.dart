import 'package:dio/dio.dart';

import 'api_client.dart';

// Plain message for users; action reads lowercase.
String apiErrorText(Object error, {required String action}) {
  if (error is ForbiddenException) {
    return 'You do not have permission to $action. Ask an administrator if you need access.';
  }

  if (error is DioException) {
    return _dioText(error, action);
  }

  return 'Something went wrong and we could not $action. Please try again.';
}

String _dioText(DioException error, String action) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'The clinic server took too long to respond. Check your connection and try again.';
    case DioExceptionType.connectionError:
      return 'We could not reach the clinic server. Check your connection and try again.';
    case DioExceptionType.cancel:
      return 'That request was cancelled before it finished.';
    default:
      return _statusText(
        error.response?.statusCode,
        action,
        _serverMessage(error.response?.data),
      );
  }
}

// Server wording is written for users.
String _serverMessage(Object? body) {
  if (body is! Map) {
    return '';
  }

  final detail = body['message'] ?? body['detail'] ?? body['error'];
  return detail == null ? '' : detail.toString().trim();
}

String _statusText(int? statusCode, String action, String serverMessage) {
  if (statusCode == 401) {
    return 'Your session has expired. Please sign in again.';
  }

  if (statusCode == 403) {
    return 'You do not have permission to $action. Ask an administrator if you need access.';
  }

  if (statusCode == 404) {
    return 'We could not find those records. They may have been removed.';
  }

  // Server already words these for users.
  if (statusCode == 400 || statusCode == 409 || statusCode == 422) {
    return serverMessage.isEmpty
        ? 'Some details were not accepted. Please check the form and try again.'
        : serverMessage;
  }

  if (statusCode != null && statusCode >= 500) {
    return 'The clinic server ran into a problem. Please try again in a moment.';
  }

  return 'Something went wrong and we could not $action. Please try again.';
}
