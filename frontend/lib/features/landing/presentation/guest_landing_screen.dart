import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/floating_petals.dart';
import '../../../core/widgets/yasmine_logo.dart';
import 'landing_screen.dart';

// Public landing page shown before sign-in.
class GuestLandingScreen extends StatelessWidget {
  const GuestLandingScreen({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _GuestHeaderBar(onLogin: onLogin),
      body: Stack(
        children: [
          const FloatingPetals(),
          LandingScreen(onBookClick: onLogin, onViewDoctor: (_) => onLogin()),
        ],
      ),
    );
  }
}

class _GuestHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const _GuestHeaderBar({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const YasmineLogo(size: 32),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YASMINE',
                style: AppTypography.displayTitle(
                  color: AppColors.text,
                ).copyWith(fontSize: 17, letterSpacing: 1.1),
              ),
              Text(
                'BEAUTY & DERMA',
                style: AppTypography.labelSmall(
                  color: AppColors.rose,
                ).copyWith(fontSize: 8.5, letterSpacing: 0.6),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            key: const Key('guestLoginButton'),
            onPressed: onLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
