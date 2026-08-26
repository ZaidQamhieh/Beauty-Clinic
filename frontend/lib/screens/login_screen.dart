import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/floating_petals.dart';
import '../core/widgets/yasmine_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authSession,
    required this.onRegister,
    this.onBack,
  });

  final AuthSession authSession;
  final VoidCallback onRegister;

  // Shown as "Back to home" when set.
  final VoidCallback? onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  OverlayEntry? _alertEntry;

  @override
  void dispose() {
    _alertEntry?.remove();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) {
      return;
    }

    _dismissAlert();
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authSession.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on InvalidCredentialsException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } on AccountLockedException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
        _showLockedBanner(error.message);
      }
    } on RateLimitedException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } on AuthException {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to sign in. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _dismissAlert() {
    _alertEntry?.remove();
    _alertEntry = null;
  }

  void _showLockedBanner(String message) {
    _dismissAlert();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopAlert(
        message: message,
        onDismissed: () {
          entry.remove();
          if (identical(_alertEntry, entry)) {
            _alertEntry = null;
          }
        },
      ),
    );
    _alertEntry = entry;
    Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.bgRose, AppColors.bg],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: FloatingPetals()),
          if (widget.onBack != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to home'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.text),
                ),
              ),
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: const BorderSide(color: AppColors.borderRose),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: YasmineLogo(size: 64)),
                              const SizedBox(height: 18),
                              Text(
                                'YASMINE DERMA CLINIC',
                                textAlign: TextAlign.center,
                                style:
                                    AppTypography.labelSmall(
                                      color: AppColors.rose,
                                    ).copyWith(
                                      letterSpacing: 2.4,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Welcome back',
                                textAlign: TextAlign.center,
                                style: AppTypography.displayTitle(),
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                key: const Key('emailField'),
                                controller: _emailController,
                                enabled: !_submitting,
                                autofillHints: const [AutofillHints.email],
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return 'Enter your email.';
                                  }
                                  if (!email.contains('@')) {
                                    return 'Enter a valid email.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                key: const Key('passwordField'),
                                controller: _passwordController,
                                enabled: !_submitting,
                                autofillHints: const [AutofillHints.password],
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter your password.'
                                    : null,
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _errorMessage!,
                                    key: const Key('loginError'),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              FilledButton(
                                key: const Key('loginButton'),
                                onPressed: _submitting ? null : _submit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: _submitting
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Sign in'),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'New patient?',
                                    style: AppTypography.bodyMedium(
                                      color: AppColors.textSub,
                                    ),
                                  ),
                                  TextButton(
                                    key: const Key('registerLink'),
                                    onPressed: _submitting
                                        ? null
                                        : widget.onRegister,
                                    style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Create account',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Floating top toast, self-dismisses after 5s.
class _TopAlert extends StatefulWidget {
  const _TopAlert({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_TopAlert> createState() => _TopAlertState();
}

class _TopAlertState extends State<_TopAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _timer = Timer(const Duration(seconds: 5), _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Material(
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                color: AppColors.rose,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_clock_outlined,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _dismiss,
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
