import 'package:beauty_clinic_app/core/widgets/error_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showErrorDialog displays error message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDialog(
                context,
                'Test error message',
                title: 'Error',
              ),
              child: const Text('Show Error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Error'));
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Test error message'), findsOneWidget);
  });

  testWidgets('showErrorDialog closes on OK button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showErrorDialog(context, 'Test error', title: 'Error'),
              child: const Text('Show Error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Error'));
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsNothing);
  });

  testWidgets('showApiErrorDialog extracts server detail', (tester) async {
    final error = DioException(
      requestOptions: RequestOptions(path: '/test'),
      response: Response(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: 400,
        data: {'detail': 'Validation failed on server'},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showApiErrorDialog(context, error, 'Default error'),
              child: const Text('Show Error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Error'));
    await tester.pumpAndSettle();

    expect(find.text('Validation failed on server'), findsOneWidget);
  });

  testWidgets('showApiErrorDialog uses fallback message', (tester) async {
    final error = DioException(
      requestOptions: RequestOptions(path: '/test'),
      response: Response(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: 500,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showApiErrorDialog(context, error, 'Fallback error message'),
              child: const Text('Show Error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Error'));
    await tester.pumpAndSettle();

    expect(find.text('Fallback error message'), findsOneWidget);
  });

  testWidgets('error dialog uses custom title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showErrorDialog(
                context,
                'Authentication failed',
                title: 'Login Error',
              ),
              child: const Text('Show Error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Error'));
    await tester.pumpAndSettle();

    expect(find.text('Login Error'), findsOneWidget);
    expect(find.text('Authentication failed'), findsOneWidget);
  });
}
