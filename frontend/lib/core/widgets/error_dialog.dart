import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// Every failure interrupts; successes stay toasts.
Future<void> showErrorDialog(
  BuildContext context,
  String message, {
  String title = 'Something went wrong',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.error_outline_rounded, color: AppColors.rose),
      iconColor: AppColors.rose,
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// Prefers the server's reason over ours.
Future<void> showApiErrorDialog(
  BuildContext context,
  Object? error,
  String fallback, {
  String title = 'Something went wrong',
}) {
  return showErrorDialog(
    context,
    _serverDetail(error) ?? fallback,
    title: title,
  );
}

// Reads "detail" off a problem+json body.
String? _serverDetail(Object? error) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  if (data is! Map) return null;
  final detail = data['detail'] ?? data['message'] ?? data['error'];
  if (detail is! String || detail.trim().isEmpty) return null;
  return detail;
}
