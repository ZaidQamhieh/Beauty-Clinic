import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';
import 'auth/auth_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  // Show the failure, not a blank page.
  ErrorWidget.builder = (details) => _CrashReport(details: details);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('UNCAUGHT: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };
  runApp(BeautyClinicApp(authSession: AuthSession.production()));
}

class _CrashReport extends StatelessWidget {
  const _CrashReport({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFFFCFAFB),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            'Something broke on this screen.\n\n'
            '${details.exceptionAsString()}\n\n'
            '${details.stack}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF2A2030),
            ),
          ),
        ),
      ),
    );
  }
}
