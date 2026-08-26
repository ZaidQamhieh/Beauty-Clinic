import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/yasmine_logo.dart';

/// Top header bar for the signed-in role.
class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String activeRole;
  final VoidCallback? onBookClick;
  final VoidCallback? onLogout;
  final VoidCallback? onProfileTap;
  final String? userName;
  final String? userImageUrl;
  final bool isMobile;

  const HeaderBar({
    super.key,
    required this.activeRole,
    this.onBookClick,
    this.onLogout,
    this.onProfileTap,
    this.userName,
    this.userImageUrl,
    this.isMobile = false,
  });

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compactText = constraints.maxWidth < 650;

          return Row(
            children: [
              if (isMobile) ...[
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: AppColors.text),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Clinic Brand Logo & Title
              Row(
                children: [
                  const YasmineLogo(size: 32),
                  const SizedBox(width: 8),
                  if (!compactText)
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
                ],
              ),

              const SizedBox(width: 12),

              // Read-only; sign in to switch role.
              _buildRoleBadge(compact: compactText),

              const Spacer(),

              // Booking is per-page, shown only when passed.
              if (onBookClick != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onBookClick,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: compactText ? 10 : 14,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    compactText || isMobile ? 'Book' : 'New Appt',
                    style: AppTypography.labelSmall(color: AppColors.white),
                  ),
                ),
              ],

              const SizedBox(width: 12),
              Container(height: 24, width: 1, color: AppColors.border),
              const SizedBox(width: 12),
              if (onLogout != null) ...[
                IconButton(
                  tooltip: 'Log out',
                  onPressed: onLogout,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.logout_outlined,
                    color: AppColors.textSub,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              _buildUserAvatar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleBadge({bool compact = false}) {
    final (String label, IconData icon) = switch (activeRole) {
      'admin' => ('Admin', Icons.admin_panel_settings_outlined),
      'doctor' => ('Doctor portal', Icons.medical_services_outlined),
      'receptionist' => ('Staff portal', Icons.support_agent_outlined),
      _ => ('Patient portal', Icons.person_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.rose),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall(
                color: AppColors.roseDark,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Semantics(
      button: true,
      label: 'Open my profile',
      child: InkWell(
        onTap: onProfileTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.roseLight, width: 1.2),
              ),
              child: ProfileAvatar(
                radius: 14,
                color: AppColors.lavDark,
                imageUrl: userImageUrl,
              ),
            ),
            if (userName != null && userName!.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  userName!,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall(color: AppColors.textSub),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
