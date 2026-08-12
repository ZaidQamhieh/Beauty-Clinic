import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/yasmine_logo.dart';

/// Top Header Navigation Bar for the signed-in account's role.
class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String activeRole;
  final VoidCallback? onBookClick;
  final VoidCallback? onNotificationClick;
  final VoidCallback? onLogout;
  final bool isMobile;

  const HeaderBar({
    super.key,
    required this.activeRole,
    this.onBookClick,
    this.onNotificationClick,
    this.onLogout,
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
          final bool showSearch = constraints.maxWidth > 840;
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

              // The role is read-only. A user must sign in to their own account
              // to reach a different portal.
              _buildRoleBadge(compact: compactText),

              const Spacer(),

              // Search Field (Desktop only on wide viewports)
              if (showSearch && !isMobile) ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.bgAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      style: AppTypography.bodySmall(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: AppTypography.bodySmall(
                          color: AppColors.textMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Notifications Button
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_outlined,
                      color: AppColors.textSub,
                      size: 20,
                    ),
                    onPressed: onNotificationClick,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.rose,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 8),

              // New Appointment Action Button
              ElevatedButton.icon(
                onPressed: onBookClick,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: compactText ? 10 : 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  compactText || isMobile ? 'Book' : 'New Appt',
                  style: AppTypography.labelSmall(color: AppColors.white),
                ),
              ),

              const SizedBox(width: 10),

              // Log out of the backend session
              if (onLogout != null)
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

              // User Profile Avatar Widget
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
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.roseLight, width: 1.2),
      ),
      child: const CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.bgLavender,
        child: Text(
          'YA',
          style: TextStyle(
            color: AppColors.lavDark,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
