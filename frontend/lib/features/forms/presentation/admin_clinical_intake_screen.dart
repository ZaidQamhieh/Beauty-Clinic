import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../network/api_error_text.dart';
import '../data/clinical_intake_api.dart';

// Clinic form directory and activity log.
class AdminClinicalIntakeScreen extends StatefulWidget {
  const AdminClinicalIntakeScreen({super.key, required this.api});

  final ClinicalIntakeApi api;

  @override
  State<AdminClinicalIntakeScreen> createState() =>
      _AdminClinicalIntakeScreenState();
}

class _AdminClinicalIntakeScreenState extends State<AdminClinicalIntakeScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _patients = const [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final patients = await widget.api.searchClinical(
        _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _patients = patients;
        if (_selected != null) {
          _selected = patients.firstWhere(
            (p) => p['id'] == _selected!['id'],
            orElse: () => patients.isNotEmpty ? patients.first : _selected!,
          );
        } else if (patients.isNotEmpty) {
          _selected = patients.first;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorText(e, action: 'load these clinical records');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          _buildHeader(),

          const SizedBox(height: 20),

          // Search & Filter Row
          _buildSearchBar(),

          const SizedBox(height: 20),

          // Main Master-Detail Layout
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_edu_rounded,
              color: AppColors.rose,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Forms History & Activity Log',
                  style: AppTypography.displaySubtitle(
                    color: AppColors.text,
                  ).copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track every clinic health form modification — who changed it, when, and exact field values.',
                  style: AppTypography.bodySmall(color: AppColors.textSub),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 16,
                  color: AppColors.rose,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_patients.length} Patients',
                  style: AppTypography.labelSmall(color: AppColors.rose),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(
                hintText: 'Search patients by name, email, or skin type...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.clear,
                size: 18,
                color: AppColors.textMuted,
              ),
              onPressed: () {
                _searchController.clear();
                _load();
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.rose, size: 20),
            tooltip: 'Refresh list',
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.rose),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.rose),
            const SizedBox(height: 16),
            Text(_error!, style: AppTypography.bodyMedium()),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Try Again')),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final directory = _buildDirectory();
        final detail = _selected == null
            ? _buildNoSelectionPlaceholder()
            : _buildDetailPane(_selected!);

        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              Expanded(flex: 2, child: directory),
              const SizedBox(height: 16),
              Expanded(flex: 3, child: detail),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 360, child: directory),
            const SizedBox(width: 20),
            Expanded(child: detail),
          ],
        );
      },
    );
  }

  Widget _buildDirectory() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Patient Directory',
                    style: AppTypography.labelLarge(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_patients.length} found',
                  style: AppTypography.bodySmall(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _patients.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_search_outlined,
                            size: 40,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No matching patients found.',
                            style: AppTypography.bodySmall(),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _patients.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final patient = _patients[index];
                      final id = patient['id'] as String;
                      final isSelected = _selected?['id'] == id;

                      return InkWell(
                        onTap: () => setState(() => _selected = patient),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          color: isSelected
                              ? AppColors.bgRose.withValues(alpha: 0.6)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isSelected
                                    ? AppColors.rose
                                    : AppColors.bgRose,
                                child: Text(
                                  _initials(patient),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.rose,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${patient['firstName']} ${patient['lastName']}',
                                      style: AppTypography.labelMedium()
                                          .copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      patient['email']?.toString() ??
                                          patient['phone']?.toString() ??
                                          'No contact',
                                      style: AppTypography.bodySmall(
                                        color: AppColors.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSelectionPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_ind_outlined,
                size: 54,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text('Select a Patient', style: AppTypography.displaySubtitle()),
              const SizedBox(height: 8),
              Text(
                'Choose a patient from the directory on the left to inspect their current Clinic Form and revision audit log.',
                style: AppTypography.bodySmall(color: AppColors.textSub),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPane(Map<String, dynamic> patient) {
    final name = '${patient['firstName']} ${patient['lastName']}';
    final email = patient['email']?.toString() ?? 'No email';
    final phone = patient['phone']?.toString() ?? 'No phone';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Patient Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.bgRose,
                child: Text(
                  _initials(patient),
                  style: const TextStyle(
                    color: AppColors.rose,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.displaySubtitle()),
                    const SizedBox(height: 2),
                    Text(
                      '$email · $phone',
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Activity Log Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Revision History & Audit Trail',
                  style: AppTypography.labelLarge(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Immutable Audit Log',
                  style: AppTypography.labelSmall(color: AppColors.textMuted),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Timeline List
          Expanded(
            child: _ClinicalHistory(
              key: ValueKey(patient['id']),
              api: widget.api,
              patientId: patient['id'] as String,
              patientName: name,
            ),
          ),
        ],
      ),
    );
  }

  String _initials(Map<String, dynamic> p) =>
      '${p['firstName'] ?? ''}${p['lastName'] ?? ''}'.characters
          .take(2)
          .toString()
          .toUpperCase();
}

class _ClinicalHistory extends StatefulWidget {
  const _ClinicalHistory({
    super.key,
    required this.api,
    required this.patientId,
    required this.patientName,
  });

  final ClinicalIntakeApi api;
  final String patientId;
  final String patientName;

  @override
  State<_ClinicalHistory> createState() => _ClinicalHistoryState();
}

class _ClinicalHistoryState extends State<_ClinicalHistory> {
  late Future<List<Map<String, dynamic>>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.api.fetchHistory(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.rose),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load change history: ${snapshot.error}'),
          );
        }
        final records = snapshot.data ?? const [];
        if (records.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'No saved clinic-form revisions yet.',
                  style: AppTypography.bodySmall(color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revisions will appear here automatically when the patient or clinician saves changes.',
                  style: AppTypography.labelSmall(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final record = records[index];
            final changedAt = DateTime.tryParse(
              record['changedAt']?.toString() ?? '',
            );
            final actorName = record['actorName']?.toString() ?? 'System';

            return Material(
              color: AppColors.bgAlt,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.bgRose,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_document,
                    color: AppColors.rose,
                    size: 18,
                  ),
                ),
                title: Text(
                  'Clinic Form Updated',
                  style: AppTypography.labelLarge(),
                ),
                subtitle: Text(
                  'by $actorName • ${changedAt == null ? 'Unknown date' : DateFormat.yMMMd().add_jm().format(changedAt.toLocal())}',
                  style: AppTypography.bodySmall(color: AppColors.textMuted),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () => _showValues(context, record),
                  icon: const Icon(Icons.compare_arrows, size: 14),
                  label: const Text('Inspect Diff'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgRose,
                    foregroundColor: AppColors.rose,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: AppTypography.labelSmall(),
                  ),
                ),
                onTap: () => _showValues(context, record),
              ),
            );
          },
        );
      },
    );
  }

  void _showValues(BuildContext context, Map<String, dynamic> record) {
    final changedAt = DateTime.tryParse(record['changedAt']?.toString() ?? '');
    final actorName = record['actorName']?.toString() ?? 'Unknown';
    final prevRaw = record['previousValues'];
    final newRaw = record['newValues'];

    final prevMap = _extractFormValues(prevRaw);
    final newMap = _extractFormValues(newRaw);

    final allKeys = <String>{...prevMap.keys, ...newMap.keys}.toList();
    const priorityKeys = [
      'pregnantBreastfeeding',
      'skinType',
      'smokingStatus',
      'allergies',
      'medications',
      'chronicConditions',
    ];
    allKeys.sort((a, b) {
      final indexA = priorityKeys.indexOf(a);
      final indexB = priorityKeys.indexOf(b);
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      return a.compareTo(b);
    });

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clinic Form Revision Diff',
                          style: AppTypography.displaySubtitle(),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.patientName,
                          style: AppTypography.labelLarge(
                            color: AppColors.rose,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Changed by: $actorName',
                      style: AppTypography.bodySmall().copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      changedAt == null
                          ? 'Unknown date'
                          : DateFormat.yMMMd().add_jm().format(
                              changedAt.toLocal(),
                            ),
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: allKeys.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No recorded form changes in this revision.',
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: allKeys.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final key = allKeys[i];
                          final prevVal = prevMap[key];
                          final newVal = newMap[key];
                          final isChanged = !_areValuesEqual(prevVal, newVal);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isChanged
                                  ? AppColors.bgRose.withValues(alpha: 0.4)
                                  : AppColors.bgCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isChanged
                                    ? AppColors.borderRose
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatFieldLabel(key),
                                      style: AppTypography.labelMedium(
                                        color: isChanged
                                            ? AppColors.roseDark
                                            : AppColors.text,
                                      ),
                                    ),
                                    if (isChanged)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.rose,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'MODIFIED',
                                          style: AppTypography.labelSmall(
                                            color: Colors.white,
                                          ).copyWith(fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (isChanged) ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Previous: ',
                                        style: AppTypography.bodySmall(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _formatValue(prevVal),
                                          style:
                                              AppTypography.bodySmall(
                                                color: AppColors.textMuted,
                                              ).copyWith(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'New: ',
                                        style: AppTypography.bodySmall(
                                          color: AppColors.text,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _formatValue(newVal),
                                          style:
                                              AppTypography.bodySmall(
                                                color: AppColors.roseDark,
                                              ).copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Text(
                                    _formatValue(newVal ?? prevVal),
                                    style: AppTypography.bodySmall(),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rose,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Map<String, dynamic> _extractFormValues(dynamic raw) {
    if (raw == null) return {};
    Map<String, dynamic> map = {};
    if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.startsWith('{')) {
      try {
        map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        return {};
      }
    } else {
      return {};
    }

    const ignoredKeys = {
      'array',
      'bigDecimal',
      'bigInteger',
      'binary',
      'boolean',
      'containerNode',
      'double',
      'empty',
      'float',
      'floatingPointNumber',
      'int',
      'integralNumber',
      'long',
      'missingNode',
      'nodeType',
      'null',
      'number',
      'object',
      'pojo',
      'short',
      'textual',
      'valueNode',
      'id',
      'firstName',
      'lastName',
      'email',
      'phone',
      'dateOfBirth',
      'gender',
    };

    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      if (!ignoredKeys.contains(entry.key)) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  static String _formatFieldLabel(String key) {
    switch (key) {
      case 'pregnantBreastfeeding':
        return 'Pregnant or Breastfeeding';
      case 'skinType':
        return 'Skin Type';
      case 'smokingStatus':
        return 'Smoking Status';
      case 'allergies':
        return 'Allergies';
      case 'medications':
        return 'Current Medications';
      case 'chronicConditions':
        return 'Chronic Conditions';
      default:
        final formatted = key.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        );
        return formatted.isEmpty
            ? key
            : '${formatted[0].toUpperCase()}${formatted.substring(1)}'.trim();
    }
  }

  static String _formatValue(dynamic val) {
    if (val == null) return 'None / Not specified';
    if (val is bool) return val ? 'Yes' : 'No';
    if (val is List) {
      if (val.isEmpty) return 'None';
      return val.map((e) => _humanizeEnum(e.toString())).join(', ');
    }
    return _humanizeEnum(val.toString());
  }

  static String _humanizeEnum(String text) {
    if (text.isEmpty) return text;
    final words = text.replaceAll('_', ' ').split(' ');
    return words
        .map((w) {
          if (w.isEmpty) return w;
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  static bool _areValuesEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return a == b;
  }
}
