import 'dart:async';
import 'dart:convert';

import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/core/theme/app_colors.dart';
import 'package:beauty_clinic_app/core/theme/app_typography.dart';
import 'package:beauty_clinic_app/core/widgets/app_dropdown.dart';
import 'package:beauty_clinic_app/core/widgets/app_search_field.dart';
import 'package:beauty_clinic_app/core/widgets/skeleton.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const int _pageSize = 50;

// Every filter control shares this height.
const double _controlHeight = 40;

// Column widths shared by header and rows.
const List<double> _columns = [138, 104, 176, 196, 104];

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key, required this.authSession});
  final AuthSession authSession;

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  late final ApiClient _api;
  final _search = TextEditingController();
  Timer? _searchDebounce;

  // Bumps on a filter change, voiding cache.
  int _filterVersion = 0;

  // Guards which in-flight fetch may paint.
  int _viewRequest = 0;

  final Map<int, List<ActivityEntry>> _pageCache = {};

  List<ActivityEntry> _entries = [];
  String? _action;
  String? _category;
  DateTimeRange? _range;
  bool _newestFirst = true;
  int _page = 0;
  int _totalPages = 1;
  int _totalElements = 0;

  bool _loading = true;
  bool _forbidden = false;
  String? _error;
  ActivityEntry? _expanded;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(widget.authSession);
    unawaited(_showPage(0));
  }

  @override
  void dispose() {
    _search.dispose();
    _searchDebounce?.cancel();
    _api.close();
    super.dispose();
  }

  Future<_ActivityPage?> _fetch(int page, int version) async {
    final response = await _api.get<dynamic>(
      '/api/activity-logs',
      queryParameters: {
        'page': page,
        'size': _pageSize,
        'sort': 'createdAt,${_newestFirst ? 'desc' : 'asc'}',
        if (_action != null) 'action': _action,
        if (_category != null) 'category': _category,
        if (_range != null) 'from': _range!.start.toUtc().toIso8601String(),
        if (_range != null) 'to': _rangeEnd(_range!),
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
      },
    );
    if (version != _filterVersion) return null;
    final payload = response.data as Map<String, dynamic>;
    final content = (payload['content'] as List<dynamic>? ?? []);
    final entries = content
        .map((e) => ActivityEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return _ActivityPage(
      entries: entries,
      totalPages: (payload['totalPages'] as int?) ?? 1,
      totalElements: (payload['totalElements'] as int?) ?? entries.length,
    );
  }

  Future<void> _showPage(int page) async {
    final version = _filterVersion;
    final request = ++_viewRequest;
    _page = page;
    _trimCache(page);

    final cached = _pageCache[page];
    if (cached != null) {
      setState(() {
        _entries = cached;
        _loading = false;
        _error = null;
        _forbidden = false;
        _expanded = null;
      });
      unawaited(_prefetch(page + 1, version));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _forbidden = false;
      _expanded = null;
    });

    try {
      final result = await _fetch(page, version);
      if (!mounted || result == null || request != _viewRequest) return;
      setState(() {
        _pageCache[page] = result.entries;
        _entries = result.entries;
        _totalPages = result.totalPages;
        _totalElements = result.totalElements;
        _loading = false;
      });
      unawaited(_prefetch(page + 1, version));
    } on DioException catch (error) {
      if (!mounted || request != _viewRequest) return;
      setState(() {
        _loading = false;
        _forbidden = error.response?.statusCode == 403;
        _error = _forbidden
            ? 'Only administrators can view the activity log.'
            : 'Could not reach the server.';
      });
    }
  }

  /// Warms the next page in advance.
  Future<void> _prefetch(int page, int version) async {
    if (page >= _totalPages || _pageCache.containsKey(page)) return;
    try {
      final result = await _fetch(page, version);
      if (!mounted || result == null || version != _filterVersion) return;
      _pageCache[page] = result.entries;
    } on DioException catch (_) {
      // A missed warm-up just loads on arrival.
    }
  }

  /// Holds the current page and its neighbours.
  void _trimCache(int page) {
    _pageCache.removeWhere((cached, _) => (cached - page).abs() > 1);
  }

  /// Inclusive of the whole closing day.
  String _rangeEnd(DateTimeRange range) {
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );
    return end.toUtc().toIso8601String();
  }

  void _reload({bool resetPage = true}) {
    _filterVersion++;
    _pageCache.clear();
    unawaited(_showPage(resetPage ? 0 : _page));
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _reload());
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _reload();
  }

  bool get _hasFilters =>
      _action != null ||
      _category != null ||
      _range != null ||
      _search.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 22),
          _filters(),
          const SizedBox(height: 18),
          Expanded(child: _ledger()),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Activity Log', style: AppTypography.displayHero()),
              const SizedBox(height: 6),
              Text(
                'Every write in the clinic, newest first · kept 24 months',
                style: AppTypography.bodyMedium(color: AppColors.textSub),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : () => _reload(resetPage: false),
          icon: const Icon(Icons.refresh, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _categoryTabs(),
        SizedBox(
          width: 300,
          height: _controlHeight,
          child: AppSearchField(
            controller: _search,
            hintText: 'Search actor, patient, or login identifier',
            contentPadding: EdgeInsets.zero,
            onChanged: (_) => _scheduleSearch(),
            onSubmitted: (_) => _reload(),
            onClear: () {
              _search.clear();
              _scheduleSearch();
            },
          ),
        ),
        AppDropdown<String?>(
          value: _action,
          hint: const Text('All events'),
          labelOf: (value) =>
              value == null ? 'All events' : ActivityEntry.labelFor(value),
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
            _reload();
          },
        ),
        _rangeChip(),
      ],
    );
  }

  Widget _categoryTabs() {
    return Container(
      height: _controlHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _categoryTab('All', null),
          _categoryTab('Clinical', 'CLINICAL'),
          _categoryTab('Admin', 'ADMIN'),
          _categoryTab('Security', 'SECURITY'),
        ],
      ),
    );
  }

  Widget _categoryTab(String label, String? value) {
    final isSelected = _category == value;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () {
        setState(() => _category = value);
        _reload();
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgCard : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: isSelected
              ? AppTypography.labelLarge()
              : AppTypography.bodyMedium(color: AppColors.textSub),
        ),
      ),
    );
  }

  Widget _rangeChip() {
    final range = _range;
    final format = DateFormat('MMM d');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickRange,
      child: Container(
        height: _controlHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: range == null ? AppColors.border : AppColors.borderRose,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: range == null ? AppColors.textMuted : AppColors.rose,
            ),
            const SizedBox(width: 8),
            Text(
              range == null
                  ? 'Any date'
                  : '${format.format(range.start)} – ${format.format(range.end)}',
              style: AppTypography.bodyMedium(
                color: range == null ? AppColors.textSub : AppColors.roseDark,
              ),
            ),
            if (range != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  setState(() => _range = null);
                  _reload();
                },
                child: const Icon(
                  Icons.close,
                  size: 15,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ledger() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (!_forbidden) _tableHeader(),
          Expanded(child: _body()),
          if (!_forbidden && !_loading && _entries.isNotEmpty) _pager(),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.bgAlt,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _columns[0],
            child: InkWell(
              onTap: () {
                setState(() => _newestFirst = !_newestFirst);
                _reload();
              },
              child: Row(
                children: [
                  Text(
                    'WHEN',
                    style: AppTypography.labelSmall(color: AppColors.textSub),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 11,
                    color: AppColors.roseDark,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: _columns[1], child: _headerLabel('CATEGORY')),
          Expanded(child: _headerLabel('EVENT')),
          SizedBox(width: _columns[2], child: _headerLabel('ACTOR')),
          SizedBox(width: _columns[3], child: _headerLabel('SUBJECT')),
          SizedBox(width: _columns[4], child: _headerLabel('CHANGES')),
          const SizedBox(width: 30),
        ],
      ),
    );
  }

  Widget _headerLabel(String text) =>
      Text(text, style: AppTypography.labelSmall());

  Widget _body() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(16), child: SkeletonList());
    }
    if (_forbidden) return _forbiddenState();
    if (_error != null) return _errorState();
    if (_entries.isEmpty) return _emptyState();

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final isExpanded = identical(entry, _expanded);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_row(entry, isExpanded), if (isExpanded) _detail(entry)],
        );
      },
    );
  }

  Widget _row(ActivityEntry entry, bool isExpanded) {
    return InkWell(
      onTap: () => setState(() => _expanded = isExpanded ? null : entry),
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isExpanded
              ? AppColors.bgLavender
              : entry.isRefusal
              ? AppColors.rosePale
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isExpanded ? Colors.transparent : AppColors.hairline,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: _columns[0],
              child: Text(
                DateFormat('HH:mm:ss').format(entry.createdAt.toLocal()),
                style: AppTypography.numeric(fontSize: 13),
              ),
            ),
            SizedBox(width: _columns[1], child: _categoryPill(entry)),
            Expanded(
              child: Text(
                entry.label,
                overflow: TextOverflow.ellipsis,
                style: entry.isRefusal
                    ? AppTypography.labelLarge(color: AppColors.roseDark)
                    : AppTypography.bodyMedium(),
              ),
            ),
            SizedBox(width: _columns[2], child: _cell(entry.actorName)),
            SizedBox(width: _columns[3], child: _cell(entry.subject)),
            SizedBox(
              width: _columns[4],
              child: Text(
                entry.changes.isEmpty
                    ? '—'
                    : '${entry.changes.length} '
                          '${entry.changes.length == 1 ? 'field' : 'fields'}',
                style: AppTypography.bodySmall(
                  color: entry.changes.isEmpty
                      ? AppColors.textMuted
                      : AppColors.lavDark,
                ),
              ),
            ),
            SizedBox(
              width: 30,
              child: Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 16,
                color: isExpanded ? AppColors.lavDark : AppColors.textSide,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String? value) => Text(
    value == null || value.isEmpty ? '—' : value,
    overflow: TextOverflow.ellipsis,
    style: AppTypography.bodySmall(color: AppColors.textSub),
  );

  Widget _categoryPill(ActivityEntry entry) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: entry.categoryTint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          entry.categoryLabel,
          style: AppTypography.labelSmall(
            color: entry.categoryAccent,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _detail(ActivityEntry entry) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      color: AppColors.bgLavender,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLav),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WHAT CHANGED', style: AppTypography.labelSmall()),
                  const SizedBox(height: 12),
                  if (entry.changes.isEmpty)
                    Text(
                      'This event recorded no field changes.',
                      style: AppTypography.bodyMedium(
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    for (final change in entry.changes) _changeRow(change),
                ],
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(width: 260, child: _context(entry)),
          ],
        ),
      ),
    );
  }

  Widget _context(ActivityEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONTEXT', style: AppTypography.labelSmall()),
        const SizedBox(height: 12),
        _contextRow(
          'When',
          DateFormat('MMMM d, y · HH:mm:ss').format(entry.createdAt.toLocal()),
        ),
        _contextRow('Actor', entry.actorName ?? 'System / unknown'),
        if (entry.patientName != null)
          _contextRow('Patient', entry.patientName!),
        _contextRow('Entity', entry.entityType ?? '—'),
        if (entry.attemptedIdentifier != null)
          _contextRow('Login identifier', entry.attemptedIdentifier!),
        if (entry.correlationId != null)
          _contextRow('Request', entry.correlationId!),
      ],
    );
  }

  Widget _contextRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.labelSmall()),
        const SizedBox(height: 3),
        SelectableText(value, style: AppTypography.bodyMedium()),
      ],
    ),
  );

  Widget _changeRow(ActivityChange change) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          change.label,
          style: AppTypography.bodySmall(color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _value(change.before, isBefore: true)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward,
                size: 14,
                color: AppColors.textMuted,
              ),
            ),
            Expanded(child: _value(change.after, isBefore: false)),
          ],
        ),
      ],
    ),
  );

  Widget _value(String text, {required bool isBefore}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: isBefore ? AppColors.bgRose : AppColors.bgSage,
      borderRadius: BorderRadius.circular(9),
    ),
    child: SelectableText(
      text,
      style: AppTypography.bodyMedium(
        color: isBefore ? AppColors.textSub : AppColors.text,
      ),
    ),
  );

  Widget _pager() {
    final first = _page * _pageSize + 1;
    final last = _page * _pageSize + _entries.length;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.bgAlt,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            'Showing $first–$last of $_totalElements',
            style: AppTypography.numeric(
              fontSize: 13,
              color: AppColors.textSub,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Previous page',
            onPressed: _page == 0 ? null : () => _showPage(_page - 1),
            icon: const Icon(Icons.chevron_left, size: 18),
          ),
          Text(
            'Page ${_page + 1} of $_totalPages',
            style: AppTypography.numeric(
              fontSize: 13,
              color: AppColors.textSub,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: _page + 1 >= _totalPages
                ? null
                : () => _showPage(_page + 1),
            icon: const Icon(Icons.chevron_right, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return _centeredState(
      icon: Icons.search_off_outlined,
      tint: AppColors.bgLavender,
      accent: AppColors.lavDark,
      title: 'No events match these filters',
      body: _filterSummary(),
      action: _hasFilters ? 'Clear the filters' : null,
      onAction: _hasFilters
          ? () {
              setState(() {
                _action = null;
                _category = null;
                _range = null;
                _search.clear();
              });
              _reload();
            }
          : null,
    );
  }

  /// Names the filters that emptied the list.
  String _filterSummary() {
    final parts = <String>[];
    if (_category != null) parts.add(ActivityEntry.labelFor(_category!));
    if (_action != null) parts.add(ActivityEntry.labelFor(_action!));
    if (_range != null) {
      final format = DateFormat('MMM d');
      parts.add(
        '${format.format(_range!.start)} to ${format.format(_range!.end)}',
      );
    }
    if (_search.text.trim().isNotEmpty) parts.add('“${_search.text.trim()}”');
    if (parts.isEmpty) return 'Nothing has been recorded yet.';
    return 'Nothing recorded for ${parts.join(' · ')}.';
  }

  Widget _forbiddenState() {
    return _centeredState(
      icon: Icons.lock_outline,
      tint: AppColors.bgRose,
      accent: AppColors.roseDark,
      title: 'The activity log is admin only',
      body:
          'Ask an administrator if you need a record pulled. '
          'This refusal was itself recorded.',
    );
  }

  Widget _errorState() {
    return _centeredState(
      icon: Icons.error_outline,
      tint: AppColors.goldPale,
      accent: AppColors.gold,
      title: 'Could not reach the server',
      body:
          'Your filters are still set. Try again, or narrow the range '
          'if this keeps happening.',
      action: 'Try again',
      onAction: () => _reload(resetPage: false),
    );
  }

  Widget _centeredState({
    required IconData icon,
    required Color tint,
    required Color accent,
    required String title,
    required String body,
    String? action,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, size: 24, color: accent),
            ),
            const SizedBox(height: 14),
            Text(title, style: AppTypography.displaySubtitle()),
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(color: AppColors.textSub),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onAction, child: Text(action)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityPage {
  const _ActivityPage({
    required this.entries,
    required this.totalPages,
    required this.totalElements,
  });

  final List<ActivityEntry> entries;
  final int totalPages;
  final int totalElements;
}

class ActivityEntry {
  const ActivityEntry({
    required this.action,
    required this.createdAt,
    this.category,
    this.actorName,
    this.patientName,
    this.entityType,
    this.attemptedIdentifier,
    this.correlationId,
    this.oldValues,
    this.newValues,
  });
  final String action;
  final DateTime createdAt;
  final String? category;
  final String? actorName, patientName, entityType, attemptedIdentifier;
  final String? correlationId;
  final Object? oldValues;
  final Object? newValues;
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
    action: json['action'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    category: json['category'] as String?,
    actorName: json['actorName'] as String?,
    patientName: json['patientName'] as String?,
    entityType: json['entityType'] as String?,
    attemptedIdentifier: json['attemptedIdentifier'] as String?,
    correlationId: json['correlationId'] as String?,
    oldValues: json['oldValues'],
    newValues: json['newValues'],
  );

  /// Fields the action touched, before beside after.
  List<ActivityChange> get changes {
    if (oldValues == null && newValues == null) return const [];
    if (oldValues is! Map && newValues is! Map) {
      final before = _render(oldValues);
      final after = _render(newValues);
      if (before == after) return const [];
      return [ActivityChange(entityType ?? 'value', before, after)];
    }

    final before = _asMap(oldValues);
    final after = _asMap(newValues);
    final keys = <String>{...before.keys, ...after.keys}.toList()..sort();
    return [
      for (final key in keys)
        if (_render(before[key]) != _render(after[key]))
          ActivityChange(key, _render(before[key]), _render(after[key])),
    ];
  }

  static Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static String _render(Object? value) {
    if (value == null) return '—';
    if (value is String) return value.isEmpty ? '—' : value;
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  static String labelFor(String action) => action
      .split('_')
      .map((word) => word[0] + word.substring(1).toLowerCase())
      .join(' ');
  String get label => labelFor(action);
  String get subject =>
      patientName ?? attemptedIdentifier ?? entityType ?? 'System event';

  /// Refusals earn a tinted row.
  bool get isRefusal =>
      action.contains('DENIED') ||
      action.contains('REJECTED') ||
      action.contains('RATE_LIMITED') ||
      action.contains('LOCKED');

  String get categoryLabel => category ?? 'OTHER';

  Color get categoryAccent => switch (category) {
    'CLINICAL' => AppColors.sageDark,
    'ADMIN' => AppColors.lavDark,
    'SECURITY' => AppColors.roseDark,
    _ => AppColors.textSub,
  };

  Color get categoryTint => switch (category) {
    'CLINICAL' => AppColors.bgSage,
    'ADMIN' => AppColors.lavPale,
    'SECURITY' => AppColors.rosePale,
    _ => AppColors.bgAlt,
  };
}

class ActivityChange {
  const ActivityChange(this.field, this.before, this.after);
  final String field;
  final String before;
  final String after;

  String get label => field
      .replaceAllMapped(RegExp(r'(?<=[a-z])[A-Z]'), (m) => ' ${m[0]}')
      .replaceAll('_', ' ')
      .toLowerCase();
}
