import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/yasmine_logo.dart';
import 'widgets/header_bar.dart';
import 'widgets/sidebar_item.dart';

/// Main App Shell Component for Yasmine Beauty Clinic
/// Manages top-level layout, drawer/sidebar, and role-specific view routing.
class AppShell extends StatefulWidget {
  final Widget child;
  final String activeRole;
  final String activeView;
  final ValueChanged<String> onViewChanged;
  final VoidCallback onBookClick;
  final VoidCallback? onLogout;

  const AppShell({
    super.key,
    required this.child,
    required this.activeRole,
    required this.activeView,
    required this.onViewChanged,
    required this.onBookClick,
    this.onLogout,
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

        // Quick Role Status Card at bottom of Sidebar
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
            'id': 'dashboard',
            'label': 'Today\'s Schedule',
            'icon': Icons.calendar_today_outlined,
            'badge': '8',
          },
          {
            'id': 'patients',
            'label': 'My Patients',
            'icon': Icons.people_outline,
            'badge': '24',
          },
          {
            'id': 'doctor_profile',
            'label': 'Doctor Profile',
            'icon': Icons.badge_outlined,
          },
          {
            'id': 'consultations',
            'label': 'Consultations',
            'icon': Icons.video_call_outlined,
          },
          {
            'id': 'landing',
            'label': 'Clinic Portal',
            'icon': Icons.storefront_outlined,
          },
        ];
      case 'patient':
        return [
          {
            'id': 'patient_profile',
            'label': 'My Medical Profile',
            'icon': Icons.person_outline,
          },
          {
            'id': 'dashboard',
            'label': 'Treatments & Visits',
            'icon': Icons.spa_outlined,
          },
          {
            'id': 'book',
            'label': 'Book Appointment',
            'icon': Icons.calendar_month_outlined,
          },
          {
            'id': 'landing',
            'label': 'Clinic Homepage',
            'icon': Icons.home_outlined,
          },
        ];
      case 'receptionist':
        return [
          {
            'id': 'dashboard',
            'label': 'Front Desk Desk',
            'icon': Icons.meeting_room_outlined,
            'badge': '12',
          },
          {
            'id': 'appointments',
            'label': 'All Appointments',
            'icon': Icons.event_note_outlined,
          },
          {
            'id': 'patients',
            'label': 'Patient Directory',
            'icon': Icons.folder_shared_outlined,
          },
          {
            'id': 'doctors',
            'label': 'Doctor Rosters',
            'icon': Icons.medical_information_outlined,
          },
          {
            'id': 'landing',
            'label': 'Main Website',
            'icon': Icons.web_outlined,
          },
        ];
      case 'admin':
      default:
        return [
          {
            'id': 'dashboard',
            'label': 'Overview Dashboard',
            'icon': Icons.grid_view_rounded,
          },
          {
            'id': 'appointments',
            'label': 'Appointments',
            'icon': Icons.calendar_today_outlined,
            'badge': '14',
          },
          {
            'id': 'patients',
            'label': 'Patients Directory',
            'icon': Icons.people_alt_outlined,
          },
          {
            'id': 'doctors',
            'label': 'Doctors & Specialists',
            'icon': Icons.health_and_safety_outlined,
          },
          {
            'id': 'patient_profile',
            'label': 'Patient Details',
            'icon': Icons.assignment_ind_outlined,
          },
          {
            'id': 'doctor_profile',
            'label': 'Doctor Profile View',
            'icon': Icons.badge_outlined,
          },
          {
            'id': 'activity_log',
            'label': 'Activity Log',
            'icon': Icons.history_rounded,
          },
          {
            'id': 'landing',
            'label': 'Clinic Landing Page',
            'icon': Icons.space_dashboard_outlined,
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
