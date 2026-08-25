import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/yasmine_logo.dart';
import 'widgets/header_bar.dart';
import 'widgets/sidebar_item.dart';

/// Top-level layout: sidebar, drawer, header, content.
class AppShell extends StatefulWidget {
  final Widget child;
  final String activeRole;
  final String activeView;
  final ValueChanged<String> onViewChanged;

  /// Null where the page owns booking itself.
  final VoidCallback? onBookClick;
  final VoidCallback? onLogout;
  final VoidCallback? onProfileTap;
  final String? userName;
  final String? userImageUrl;

  const AppShell({
    super.key,
    required this.child,
    required this.activeRole,
    required this.activeView,
    required this.onViewChanged,
    this.onBookClick,
    this.onLogout,
    this.onProfileTap,
    this.userName,
    this.userImageUrl,
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
        userName: widget.userName,
        userImageUrl: widget.userImageUrl,
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
    final List<Map<String, dynamic>> menuItems = _getMenuItemsForRole(
      widget.activeRole,
    );

    return Column(
      children: [
        // Sidebar Top Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              // Tapping the logo expands the rail.
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
              final item = menuItems[index];
              final bool isActive = widget.activeView == item['id'];

              if (isCollapsed) {
                return Tooltip(
                  message: item['label'] as String,
                  child: IconButton(
                    icon: Icon(
                      item['icon'] as IconData,
                      color: isActive
                          ? AppColors.roseLight
                          : AppColors.textSideMuted,
                    ),
                    onPressed: () => widget.onViewChanged(item['id'] as String),
                  ),
                );
              }

              return SidebarItem(
                icon: item['icon'] as IconData,
                label: item['label'] as String,
                badge: item['badge'] as String?,
                isActive: isActive,
                onTap: () {
                  if (isDrawer) Navigator.of(context).pop();
                  widget.onViewChanged(item['id'] as String);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    final List<Map<String, dynamic>> menuItems = _getMenuItemsForRole(
      widget.activeRole,
    );
    final int selectedIndex = menuItems
        .indexWhere((item) => item['id'] == widget.activeView)
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
        widget.onViewChanged(menuItems[index]['id'] as String);
      },
      items: menuItems.take(4).map((item) {
        return BottomNavigationBarItem(
          icon: Icon(item['icon'] as IconData),
          label: item['label'] as String,
        );
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _getMenuItemsForRole(String role) {
    switch (role) {
      case 'doctor':
        return [
          {
            'id': 'my_profile',
            'label': 'My Profile',
            'icon': Icons.person_outline,
          },
          {
            'id': 'dashboard',
            'label': 'Dashboard',
            'icon': Icons.calendar_today_outlined,
          },
          {
            'id': 'patients',
            'label': 'My Patients',
            'icon': Icons.people_outline,
          },
          {
            'id': 'appointments',
            'label': 'Appointments',
            'icon': Icons.calendar_today_outlined,
          },
          {
            'id': 'clinical_forms',
            'label': 'Patient Forms History',
            'icon': Icons.assignment_outlined,
          },
          {
            'id': 'products',
            'label': 'Products',
            'icon': Icons.inventory_2_outlined,
          },
          {
            'id': 'my_calendar',
            'label': 'My Calendar',
            'icon': Icons.calendar_view_day_outlined,
          },
          {
            'id': 'doctor_availability',
            'label': 'Availability',
            'icon': Icons.event_available_outlined,
          },
        ];
      case 'patient':
        return [
          {'id': 'dashboard', 'label': 'Dashboard', 'icon': Icons.spa_outlined},
          {
            'id': 'my_profile',
            'label': 'My Profile',
            'icon': Icons.person_outline,
          },
          {
            'id': 'patient_profile',
            'label': 'My Medical Profile',
            'icon': Icons.health_and_safety_outlined,
          },
          {
            'id': 'appointments',
            'label': 'Treatments & Visits',
            'icon': Icons.calendar_today_outlined,
          },
        ];
      case 'receptionist':
        return [
          {
            'id': 'my_profile',
            'label': 'My Profile',
            'icon': Icons.person_outline,
          },
          {
            'id': 'dashboard',
            'label': 'Dashboard',
            'icon': Icons.meeting_room_outlined,
          },
          {
            'id': 'appointments',
            'label': 'Appointments',
            'icon': Icons.event_note_outlined,
          },
          {
            'id': 'patients',
            'label': 'Patients',
            'icon': Icons.folder_shared_outlined,
          },
          {
            'id': 'doctors',
            'label': 'Doctors',
            'icon': Icons.medical_information_outlined,
          },
          {
            'id': 'products',
            'label': 'Products',
            'icon': Icons.inventory_2_outlined,
          },
        ];
      case 'admin':
      default:
        return [
          {
            'id': 'my_profile',
            'label': 'My Profile',
            'icon': Icons.person_outline,
          },
          {
            'id': 'dashboard',
            'label': 'Overview Dashboard',
            'icon': Icons.grid_view_rounded,
          },
          {
            'id': 'staff_management',
            'label': 'Staff Management',
            'icon': Icons.groups_rounded,
          },
          {
            'id': 'patients',
            'label': 'Patients Directory',
            'icon': Icons.people_alt_outlined,
          },
          {
            'id': 'appointments',
            'label': 'Appointments',
            'icon': Icons.calendar_today_outlined,
          },
          {
            'id': 'activity_log',
            'label': 'Activity Log',
            'icon': Icons.history_rounded,
          },
          {
            'id': 'clinical_forms',
            'label': 'Patient Forms History',
            'icon': Icons.assignment_outlined,
          },
          {
            'id': 'products',
            'label': 'Products',
            'icon': Icons.inventory_2_outlined,
          },
          {
            'id': 'form_builder',
            'label': 'Form Builder',
            'icon': Icons.dynamic_form_outlined,
          },
        ];
    }
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
