import 'package:flutter/material.dart';

import 'auth/auth_session.dart';
import 'network/api_client.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.authSession});

  final AuthSession? authSession;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthSession _authSession;
  late final ApiClient _apiClient;
  late final bool _ownsServices;

  @override
  void initState() {
    super.initState();
    _ownsServices = widget.authSession == null;
    _authSession = widget.authSession ?? AuthSession.production();
    _apiClient = ApiClient(authSession: _authSession);
    _authSession.initialize();
  }

  @override
  void dispose() {
    _apiClient.close();
    if (_ownsServices) {
      _authSession.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beauty Clinic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7D5260),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8FA),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ),
      home: ListenableBuilder(
        listenable: _authSession,
        builder: (context, _) {
          return switch (_authSession.status) {
            AuthStatus.initializing => const _SessionLoadingScreen(),
            AuthStatus.authenticated => HomeScreen(authSession: _authSession),
            AuthStatus.unauthenticated => LoginScreen(
              authSession: _authSession,
            ),
          };
        },
      ),
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
