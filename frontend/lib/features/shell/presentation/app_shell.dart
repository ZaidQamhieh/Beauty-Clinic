import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/yasmine_logo.dart';
import '../../../../routing/app_routes.dart';
import 'widgets/header_bar.dart';
import 'widgets/sidebar_item.dart';

// Shell layout: header, sidebar, active view.
class AppShell extends StatefulWidget {
  final Widget child;
  final String activeRole;
  final String activeView;
  final ValueChanged<String> onViewChanged;

  // Null when the page owns booking.
  final VoidCallback? onBookClick;
  final VoidCallback? onLogout;
  final VoidCallback? onProfileTap;

  const AppShell({
    super.key,
    required this.child,
    required this.activeRole,
    required this.activeView,
    required this.onViewChanged,
    this.onBookClick,
    this.onLogout,
    this.onProfileTap,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: HeaderBar(
        activeRole: widget.activeRole,
        onBookClick: widget.onBookClick,
        onLogout: widget.onLogout,
        onProfileTap: widget.onProfileTap,
        isMobile: isMobile,
      ),
      drawer: isMobile ? _buildDrawer(context) : null,
      body: Row(
        children: [
          // Sidebar for Desktop & Tablet
          if (!isMobile)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: _isSidebarCollapsed ? 80 : 250,
              color: AppColors.bgSidebar,
              child: _buildSidebarContent(isCollapsed: _isSidebarCollapsed),
            ),

          // Main View Body
          Expanded(
            child: Container(color: AppColors.bg, child: widget.child),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomNav() : null,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bgSidebar,
      child: SafeArea(
        child: _buildSidebarContent(isCollapsed: false, isDrawer: true),
      ),
    );
  }

  Widget _buildSidebarContent({
    required bool isCollapsed,
    bool isDrawer = false,
  }) {
    final List<AppRoute> menuItems = AppRoutes.menuFor(widget.activeRole);

    return Column(
      children: [
        // Sidebar Top Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              // Collapsed rail expands via the logo.
              if (!isDrawer && isCollapsed)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _isSidebarCollapsed = false),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: YasmineLogo(size: 28, isDarkBackground: true),
                  ),
                )
              else
                const YasmineLogo(size: 34, isDarkBackground: true),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YASMINE',
                        style: AppTypography.displayTitle(
                          color: AppColors.white,
                        ).copyWith(fontSize: 16, letterSpacing: 1.1),
                      ),
                      Text(
                        _getRoleTitle(widget.activeRole),
                        style: AppTypography.labelSmall(
                          color: AppColors.roseLight,
                        ).copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
              if (!isDrawer && !isCollapsed)
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.textSideMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSidebarCollapsed = !_isSidebarCollapsed;
                    });
                  },
                ),
            ],
          ),
        ),

        const Divider(color: Color(0x1AFCFAFB), height: 1),

        const SizedBox(height: 12),

        // Navigation Menu List
        Expanded(
          child: ListView.builder(
            itemCount: menuItems.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final route = menuItems[index];
              final entry = route.menu[widget.activeRole]!;
              final bool isActive = widget.activeView == route.id;

              if (isCollapsed) {
                return Tooltip(
                  message: entry.label,
                  child: IconButton(
                    icon: Icon(
                      entry.icon,
                      color: isActive
                          ? AppColors.roseLight
                          : AppColors.textSideMuted,
                    ),
                    onPressed: () => widget.onViewChanged(route.id),
                  ),
                );
              }

              return SidebarItem(
                icon: entry.icon,
                label: entry.label,
                badge: entry.badge,
                isActive: isActive,
                onTap: () {
                  if (isDrawer) Navigator.of(context).pop();
                  widget.onViewChanged(route.id);
                },
              );
            },
          ),
        ),

        // Role status card, sidebar bottom.
        if (!isCollapsed) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x15FFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x20FFFFFF)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yasmine Derma',
                          style: AppTypography.labelMedium(
                            color: AppColors.white,
                          ),
                        ),
                        Text(
                          'System v2.4 Active',
                          style: AppTypography.labelSmall(
                            color: AppColors.textSide,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    final List<AppRoute> menuItems = AppRoutes.menuFor(widget.activeRole);
    final int selectedIndex = menuItems
        .indexWhere((route) => route.id == widget.activeView)
        .clamp(0, menuItems.length - 1);

    return BottomNavigationBar(
      currentIndex: selectedIndex,
      backgroundColor: AppColors.bgCard,
      selectedItemColor: AppColors.rose,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: AppTypography.labelSmall(color: AppColors.rose),
      unselectedLabelStyle: AppTypography.labelSmall(
        color: AppColors.textMuted,
      ),
      onTap: (index) {
        widget.onViewChanged(menuItems[index].id);
      },
      items: menuItems.take(4).map((route) {
        final entry = route.menu[widget.activeRole]!;
        return BottomNavigationBarItem(
          icon: Icon(entry.icon),
          label: entry.label,
        );
      }).toList(),
    );
  }


  String _getRoleTitle(String role) {
    switch (role) {
      case 'doctor':
        return 'Specialist Portal';
      case 'patient':
        return 'Patient Account';
      case 'receptionist':
        return 'Reception Desk';
      case 'admin':
      default:
        return 'Admin Management';
    }
  }
}
