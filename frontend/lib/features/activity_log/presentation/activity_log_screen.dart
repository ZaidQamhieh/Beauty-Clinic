import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/core/theme/app_colors.dart';
import 'package:beauty_clinic_app/core/theme/app_typography.dart';
import 'package:beauty_clinic_app/core/widgets/app_dropdown.dart';
import 'package:beauty_clinic_app/core/widgets/skeleton.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key, required this.authSession});
  final AuthSession authSession;

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  late final ApiClient _api;
  final _search = TextEditingController();
  List<ActivityEntry> _entries = [];
  String? _action;
  bool _loading = true;
  String? _error;
  ActivityEntry? _selected;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(widget.authSession);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.get<dynamic>(
        '/api/activity-logs',
        queryParameters: {
          'size': 50,
          'sort': 'createdAt,desc',
          if (_action != null) 'action': _action,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        },
      );
      final payload = response.data as Map<String, dynamic>;
      final content = (payload['content'] as List<dynamic>? ?? []);
      if (!mounted) return;
      setState(
        () => _entries = content
            .map(
              (e) =>
                  ActivityEntry.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.response?.statusCode == 403
            ? 'Only administrators can view the activity log.'
            : 'Could not load activity records. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Log', style: AppTypography.displayHero()),
          const SizedBox(height: 6),
          Text(
            'A secure, read-only record of clinic account and appointment activity.',
            style: AppTypography.bodyMedium(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          _filters(),
          const SizedBox(height: 20),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filters() => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 300,
        child: TextField(
          controller: _search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search IDs, entity, or email',
            filled: true,
            fillColor: AppColors.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ),
      AppDropdown<String?>(
        value: _action,
        hint: const Text('All events'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All events'),
          ),
          ...ActivityEntry.actions.map(
            (a) => DropdownMenuItem(
              value: a,
              child: Text(ActivityEntry.labelFor(a)),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() => _action = value);
          _load();
        },
      ),
      OutlinedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    ],
  );

  Widget _body() {
    if (_loading) return const SkeletonList();
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: AppTypography.bodyLarge(color: AppColors.textMuted),
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'No activity matches these filters.',
          style: AppTypography.bodyLarge(color: AppColors.textMuted),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Card(
            color: AppColors.bgCard,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: ListView.separated(
              itemCount: _entries.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.hairline),
              itemBuilder: (_, index) => _tile(_entries[index]),
            ),
          ),
        ),
        if (_selected != null) ...[
          const SizedBox(width: 20),
          Expanded(flex: 2, child: _detail(_selected!)),
        ],
      ],
    );
  }

  Widget _tile(ActivityEntry entry) => ListTile(
    leading: CircleAvatar(
      backgroundColor: entry.color.withValues(alpha: .14),
      child: Icon(entry.icon, color: entry.color),
    ),
    title: Text(entry.label, style: AppTypography.labelLarge()),
    subtitle: Text(entry.subject, style: AppTypography.bodySmall()),
    trailing: Text(
      DateFormat('MMM d, HH:mm').format(entry.createdAt.toLocal()),
      style: AppTypography.bodySmall(),
    ),
    onTap: () => setState(() => _selected = entry),
  );

  Widget _detail(ActivityEntry entry) => Card(
    color: AppColors.bgCard,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(entry.icon, color: entry.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.label,
                  style: AppTypography.displaySubtitle(),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(height: 28),
          _detailRow(
            'When',
            DateFormat(
              'MMMM d, y • HH:mm:ss',
            ).format(entry.createdAt.toLocal()),
          ),
          _detailRow('Actor ID', entry.userId ?? 'System / unknown'),
          _detailRow('Patient ID', entry.patientUserId ?? '—'),
          _detailRow('Entity', entry.entityType ?? '—'),
          _detailRow('Entity ID', entry.entityId ?? '—'),
          if (entry.attemptedIdentifier != null)
            _detailRow('Login identifier', entry.attemptedIdentifier!),
          const SizedBox(height: 16),
          Text(
            'Records are append-only and cannot be edited from this screen.',
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.labelSmall()),
        const SizedBox(height: 3),
        SelectableText(value, style: AppTypography.bodyMedium()),
      ],
    ),
  );
}

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    this.userId,
    this.patientUserId,
    this.entityType,
    this.entityId,
    this.attemptedIdentifier,
  });
  final String id, action;
  final DateTime createdAt;
  final String? userId,
      patientUserId,
      entityType,
      entityId,
      attemptedIdentifier;
  static const actions = [
    'ACCOUNT_REGISTERED',
    'PERMISSION_DENIED',
    'APPOINTMENT_BOOKED',
    'APPOINTMENT_RESCHEDULED',
    'APPOINTMENT_CANCELLED',
    'APPOINTMENT_SESSIONS_ADDED',
    'SESSION_SCHEDULED',
    'SESSION_STATUS_CHANGED',
    'SESSION_CANCELLED',
    'SESSION_COMPLETED',
    'SESSION_NO_SHOW',
    'CLINICAL_PROFILE_VIEWED',
    'CLINICAL_HISTORY_VIEWED',
    'CLINICAL_LIST_VIEWED',
    'SESSION_RECORDS_VIEWED',
    'CLINICAL_PROFILE_UPDATED',
    'SESSION_RECORD_CREATED',
    'SESSION_RECORD_AMENDED',
    'ACCOUNT_CREATED',
    'ACCOUNT_UPDATED',
    'ACCOUNT_DELETED',
    'ACCOUNT_STATUS_CHANGED',
    'PASSWORD_CHANGED',
    'PASSWORD_RESET',
    'PROFILE_UPDATED',
    'PATIENT_REGISTERED_BY_STAFF',
    'PATIENT_DEMOGRAPHICS_UPDATED',
    'ACCOUNT_LOCKED',
    'AUTH_RATE_LIMITED',
    'STALE_SESSION_REJECTED',
    'ROLE_CHANGE_REJECTED',
    'DISABLED_ACCOUNT_REJECTED',
    'REFRESH_TOKEN_REJECTED',
    'DOCTOR_CREATED',
    'DOCTOR_UPDATED',
    'DOCTOR_DELETED',
    'AVAILABILITY_ADDED',
    'AVAILABILITY_REMOVED',
    'PRODUCT_CREATED',
    'PRODUCT_UPDATED',
    'PRODUCT_DELETED',
    'PATIENT_PRODUCT_ADDED',
    'PATIENT_PRODUCT_DISCONTINUED',
    'FORM_QUESTION_CREATED',
    'FORM_QUESTION_UPDATED',
    'FORM_QUESTION_ACTIVATED',
    'FORM_QUESTION_DEACTIVATED',
  ];
  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
    id: json['id'] as String,
    action: json['action'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    userId: json['userId'] as String?,
    patientUserId: json['patientUserId'] as String?,
    entityType: json['entityType'] as String?,
    entityId: json['entityId'] as String?,
    attemptedIdentifier: json['attemptedIdentifier'] as String?,
  );
  static String labelFor(String action) => action
      .split('_')
      .map((word) => word[0] + word.substring(1).toLowerCase())
      .join(' ');
  String get label => labelFor(action);
  String get subject =>
      attemptedIdentifier ??
      entityType ??
      (userId == null ? 'System event' : 'Account ${userId!.substring(0, 8)}');
  IconData get icon {
    if (action.contains('APPOINTMENT')) return Icons.calendar_month_outlined;
    if (action.contains('SESSION')) return Icons.spa_outlined;
    if (action == 'PERMISSION_DENIED') return Icons.lock_outline;
    if (action.contains('CLINICAL') || action.contains('RECORD')) {
      return Icons.assignment_outlined;
    }
    if (action.contains('DOCTOR')) return Icons.medical_services_outlined;
    if (action.contains('PRODUCT')) return Icons.inventory_2_outlined;
    if (action.contains('FORM_QUESTION')) return Icons.description_outlined;
    return Icons.person_outline;
  }

  Color get color =>
      action.contains('FAILED') ||
          action.contains('DENIED') ||
          action.contains('CANCELLED')
      ? AppColors.roseDark
      : action.contains('COMPLETED')
      ? AppColors.sage
      : AppColors.lav;
}
