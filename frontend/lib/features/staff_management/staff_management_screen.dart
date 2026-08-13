import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_session.dart';
import '../../core/constants/country_dial_codes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/yasmine_logo.dart';
import '../../network/api_client.dart';

part 'staff_form_dialog.dart';
part 'staff_management_types.dart';
part 'staff_management_widgets.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({
    super.key,
    required this.apiClient,
    required this.authSession,
  });

  final ApiClient apiClient;
  final AuthSession authSession;

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  late Future<List<StaffMember>> _staffFuture;
  _StaffFilter _selectedFilter = _StaffFilter.all;

  @override
  void initState() {
    super.initState();
    _staffFuture = _loadStaff();
  }

  Future<List<StaffMember>> _loadStaff() async {
    if (!widget.authSession.isAuthenticated) {
      throw const AuthException();
    }

    final accessToken = await widget.authSession.validAccessToken();
    if (accessToken == null) {
      throw const AuthException();
    }

    final response = await widget.apiClient.get<dynamic>('/api/admin/accounts');
    final raw = response.data;

    if (raw is! List) {
      throw const FormatException('Invalid staff list payload.');
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map(StaffMember.fromJson)
        .where((member) => member.fullName.isNotEmpty)
        .toList();
  }

  void _refreshStaff() {
    setState(() {
      _staffFuture = _loadStaff();
    });
  }

  void _setFilter(_StaffFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  List<StaffMember> _applyFilter(List<StaffMember> staff) {
    return switch (_selectedFilter) {
      _StaffFilter.all => staff,
      _StaffFilter.doctor =>
        staff.where((member) => member.role == 'DOCTOR').toList(),
      _StaffFilter.receptionist =>
        staff.where((member) => member.role == 'RECEPTIONIST').toList(),
    };
  }

  String _roleLabel(String role) {
    return role == 'RECEPTIONIST' ? 'Receptionist' : 'Doctor';
  }

  String _friendlyDioError(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final details = switch (body) {
      Map<String, dynamic>() =>
        (body['message'] ?? body['detail'] ?? body['error'] ?? '').toString(),
      _ => '',
    };

    if (status == 404) {
      return details.isEmpty
          ? 'Request failed with 404. Please check backend route mapping.'
          : 'Request failed with 404: $details';
    }

    if (status == 403) {
      return details.isEmpty
          ? 'Access denied (403). This endpoint requires ADMIN privileges.'
          : 'Access denied (403): $details';
    }

    if (status == 400 || status == 422) {
      return details.isEmpty
          ? 'Validation failed. Please check required fields and enum values.'
          : 'Validation failed: $details';
    }

    if (status != null) {
      return details.isEmpty
          ? 'Request failed with status $status.'
          : 'Request failed with status $status: $details';
    }

    return 'Request failed: ${error.message ?? error.toString()}';
  }

  Future<void> _openFormDialog({
    required _StaffRole role,
    StaffMember? initialStaff,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StaffFormDialog(
        role: role,
        apiClient: widget.apiClient,
        initialStaff: initialStaff,
      ),
    );

    if (saved == true) {
      _refreshStaff();
    }
  }

  Future<void> _deleteStaff(StaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${member.fullName}?'),
        content: Text(
          'This will permanently remove the ${_roleLabel(member.role).toLowerCase()} account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.apiClient.delete<dynamic>(
        '/api/admin/accounts/${member.userId}',
      );
      _refreshStaff();
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyDioError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const YasmineLogo(size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'YASMINE',
                  style: AppTypography.labelSmall(
                    color: AppColors.rose,
                  ).copyWith(letterSpacing: 2, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Staff Management',
                  style: AppTypography.displaySubtitle(),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => _openFormDialog(role: _StaffRole.receptionist),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Register Receptionist'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.bgRose,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _openFormDialog(role: _StaffRole.doctor),
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text('Register Doctor'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.lavDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<StaffMember>>(
          future: _staffFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load staff.',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', style: theme.textTheme.bodySmall),
                  ],
                ),
              );
            }

            final staff = snapshot.data ?? const <StaffMember>[];
            final visibleStaff = _applyFilter(staff);
            final doctors = staff
                .where((entry) => entry.role == 'DOCTOR')
                .length;
            final receptionists = staff
                .where((entry) => entry.role == 'RECEPTIONIST')
                .length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.bgRose,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderRose),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clinic team overview',
                          style: AppTypography.displayTitle(),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Manage doctors and receptionists with the same Yasmine visual language used across the dashboard and landing experience.',
                          style: AppTypography.bodyLarge(
                            color: AppColors.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Manage clinic staff - doctors and receptionists',
                    style: AppTypography.bodyMedium(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _StatTile(
                        title: 'All',
                        value: '${staff.length}',
                        subtitle: 'Show all staff',
                        icon: Icons.people_alt_rounded,
                        color: AppColors.rose,
                        selected: _selectedFilter == _StaffFilter.all,
                        onTap: () => _setFilter(_StaffFilter.all),
                      ),
                      _StatTile(
                        title: 'Doctors',
                        value: '$doctors',
                        subtitle: 'Filter doctors',
                        icon: Icons.medical_services_rounded,
                        color: AppColors.lavDark,
                        selected: _selectedFilter == _StaffFilter.doctor,
                        onTap: () => _setFilter(_StaffFilter.doctor),
                      ),
                      _StatTile(
                        title: 'Receptionists',
                        value: '$receptionists',
                        subtitle: 'Filter receptionists',
                        icon: Icons.event_available_rounded,
                        color: AppColors.gold,
                        selected: _selectedFilter == _StaffFilter.receptionist,
                        onTap: () => _setFilter(_StaffFilter.receptionist),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: const BoxDecoration(
                            color: AppColors.bgAlt,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'All Staff',
                                style: AppTypography.labelLarge(),
                              ),
                            ],
                          ),
                        ),
                        if (visibleStaff.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No staff found for the selected filter.',
                              style: AppTypography.bodyMedium(
                                color: AppColors.textSub,
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: visibleStaff.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = visibleStaff[index];
                              return _StaffRow(
                                item: item,
                                onEdit: () => _openFormDialog(
                                  role: item.role == 'RECEPTIONIST'
                                      ? _StaffRole.receptionist
                                      : _StaffRole.doctor,
                                  initialStaff: item,
                                ),
                                onDelete: () => _deleteStaff(item),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
