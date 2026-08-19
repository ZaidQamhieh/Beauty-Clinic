import 'package:flutter/material.dart';

import '../auth/auth_session.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.authSession});

  final AuthSession authSession;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) {
      return;
    }
    setState(() => _loggingOut = true);
    try {
      await widget.authSession.logout();
    } on AuthException {
      // The session is already cleared locally, so the app returns to login.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beauty Clinic'),
        actions: [
          TextButton.icon(
            key: const Key('logoutButton'),
            onPressed: _loggingOut ? null : _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'You are signed in',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Your secure session is active.'),
            ],
          ),
        ),
      ),
    );
  }
}
