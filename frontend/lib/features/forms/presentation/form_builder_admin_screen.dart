import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/dynamic_form_api.dart';

/// Form builder screen, clinic-themed.
class FormBuilderAdminScreen extends StatefulWidget {
  const FormBuilderAdminScreen({super.key, required this.api});
  final DynamicFormApi api;

  @override
  State<FormBuilderAdminScreen> createState() => _FormBuilderAdminScreenState();
}

class _FormBuilderAdminScreenState extends State<FormBuilderAdminScreen> {
  List<Map<String, dynamic>> _questions = const [];
  bool _loading = true;
  Object? _loadError;
  String _filter = 'ALL'; // ALL, ACTIVE, HIDDEN
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final questions = await widget.api.fetchAdminQuestionsRaw();
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _save([Map<String, dynamic>? q]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _QuestionDialog(question: q),
    );
    if (data == null) return;

    final previous = _questions;
    final id =
        q?['id']?.toString() ??
        'pending-${DateTime.now().microsecondsSinceEpoch}';
    // Shows now; server confirms after.
    final optimistic = {...?q, ...data, 'id': id};
    setState(() {
      _questions = q == null
          ? [..._questions, optimistic]
          : [
              for (final current in _questions)
                current['id'] == q['id'] ? optimistic : current,
            ];
    });

    try {
      if (q == null) {
        await widget.api.createQuestion(data);
      } else {
        await widget.api.updateQuestion(q['id'] as String, data);
      }
      if (!mounted) return;
      // Server owns ids and ordering.
      await _refreshQuietly();
    } catch (_) {
      if (!mounted) return;
      setState(() => _questions = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the question.')),
      );
    }
  }

  Future<void> _setActive(Map<String, dynamic> q, bool active) async {
    final previous = _questions;
    setState(() {
      _questions = [
        for (final current in _questions)
          current['id'] == q['id'] ? {...current, 'active': active} : current,
      ];
    });

    try {
      active
          ? await widget.api.activateQuestion(q['id'] as String)
          : await widget.api.deactivateQuestion(q['id'] as String);
    } catch (_) {
      if (!mounted) return;
      setState(() => _questions = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active ? 'Could not show the question.' : 'Could not hide it.',
          ),
        ),
      );
    }
  }

  Future<void> _refreshQuietly() async {
    try {
      final questions = await widget.api.fetchAdminQuestionsRaw();
      if (!mounted) return;
      setState(() => _questions = questions);
    } catch (_) {
      // What is on screen already stands.
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
          _buildHeaderBanner(),

          const SizedBox(height: 20),

          // Search & Filter Toolbar
          _buildToolbar(),

          const SizedBox(height: 16),

          // Main Questions List
          Expanded(
            child: Builder(
              builder: (context) {
                if (_loading) {
                  return const SkeletonList();
                }
                if (_loadError != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.rose,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load the form: $_loadError',
                          style: AppTypography.bodyMedium(
                            color: AppColors.textSub,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.rose,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final rawQuestions = _questions;
                final filtered = rawQuestions.where((q) {
                  final matchesFilter = switch (_filter) {
                    'ACTIVE' => q['active'] == true,
                    'HIDDEN' => q['active'] != true,
                    _ => true,
                  };
                  if (!matchesFilter) return false;

                  if (_searchQuery.isEmpty) return true;
                  final label = (q['label']?.toString() ?? '').toLowerCase();
                  final key = (q['fieldKey']?.toString() ?? '').toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return label.contains(query) || key.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(rawQuestions.isEmpty);
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final q = filtered[index];
                    return _QuestionCard(
                      question: q,
                      onEdit: () => _save(q),
                      onHide: q['active'] == true
                          ? () => _setActive(q, false)
                          : null,
                      onShow: q['active'] != true
                          ? () => _setActive(q, true)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
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
              Icons.dynamic_form_rounded,
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
                  'Clinic forms builder',
                  style: AppTypography.displaySubtitle(
                    color: AppColors.text,
                  ).copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Changes are saved to the database. Hide removes a question from the patient UI while retaining its schema and all answers.',
                  style: AppTypography.bodySmall(color: AppColors.textSub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => _save(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add question'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        // Search Input
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search by question title or field key...',
                      // Prevents the theme's fill from doubling up.
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                    style: AppTypography.bodyMedium(),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.clear,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Filter Segment Tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.bgAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterChip('ALL', 'All'),
              _buildFilterChip('ACTIVE', 'Active'),
              _buildFilterChip('HIDDEN', 'Hidden'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgCard : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style:
              AppTypography.labelSmall(
                color: isSelected ? AppColors.rose : AppColors.textSub,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isAbsoluteEmpty) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.bgLavender,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.quiz_outlined,
                size: 40,
                color: AppColors.lav,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isAbsoluteEmpty
                  ? 'No form questions configured'
                  : 'No questions match your filter',
              style: AppTypography.displaySubtitle(),
            ),
            const SizedBox(height: 6),
            Text(
              isAbsoluteEmpty
                  ? 'Create questions to be displayed on the clinical health form.'
                  : 'Try clearing your search or switching filters.',
              style: AppTypography.bodySmall(color: AppColors.textSub),
            ),
            if (isAbsoluteEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _save(),
                icon: const Icon(Icons.add),
                label: const Text('Add question'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.onEdit,
    this.onHide,
    this.onShow,
  });

  final Map<String, dynamic> question;
  final VoidCallback onEdit;
  final VoidCallback? onHide;
  final VoidCallback? onShow;

  @override
  Widget build(BuildContext context) {
    final fieldType = question['fieldType']?.toString() ?? 'SINGLE_SELECT';
    final isRequired = question['required'] == true;
    final isActive = question['active'] == true;
    final fieldKey = question['fieldKey']?.toString() ?? '';
    final label = question['label']?.toString() ?? '';
    final helpText = question['helpText']?.toString();
    final options = (question['options'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    final (
      IconData typeIcon,
      Color typeColor,
      Color typeBg,
      String typeName,
    ) = switch (fieldType) {
      'BOOLEAN' => (
        Icons.toggle_on_outlined,
        AppColors.lavDark,
        AppColors.bgLavender,
        'Yes / No',
      ),
      'MULTI_SELECT' => (
        Icons.checklist_rounded,
        AppColors.sageDark,
        AppColors.bgSage,
        'Multiple Choice',
      ),
      _ => (
        Icons.radio_button_checked_rounded,
        AppColors.roseDark,
        AppColors.bgRose,
        'Single Choice',
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: isActive ? AppColors.bgCard : AppColors.bgAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AppColors.border
              : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: isActive
            ? const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Field Type Icon Badge
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 14),
              // Question Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges row + Field key
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Field key capsule
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            fieldKey,
                            style: AppTypography.labelSmall(
                              color: AppColors.textSub,
                            ).copyWith(fontFamily: 'monospace', fontSize: 11),
                          ),
                        ),
                        // Type pill
                        _buildStatusPill(
                          label: typeName,
                          color: typeColor,
                          bg: typeBg,
                        ),
                        // Required pill
                        _buildStatusPill(
                          label: isRequired ? 'Required' : 'Optional',
                          color: isRequired ? AppColors.rose : AppColors.sage,
                          bg: isRequired ? AppColors.bgRose : AppColors.bgSage,
                        ),
                        // Hidden status pill
                        if (!isActive)
                          _buildStatusPill(
                            label: 'Hidden',
                            color: AppColors.textMuted,
                            bg: AppColors.bgAlt,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: AppTypography.labelLarge(
                        color: isActive ? AppColors.text : AppColors.textMuted,
                      ).copyWith(fontSize: 15),
                    ),
                    if (helpText != null && helpText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        helpText,
                        style: AppTypography.bodySmall(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit question',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.textSub,
                      backgroundColor: AppColors.bgAlt,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (onHide != null)
                    IconButton(
                      onPressed: onHide,
                      tooltip: 'Hide from patient form',
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        backgroundColor: AppColors.bgAlt,
                      ),
                    ),
                  if (onShow != null)
                    IconButton(
                      onPressed: onShow,
                      tooltip: 'Show on patient form again',
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.rose,
                        backgroundColor: AppColors.bgRose,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Options Chips Preview
          if (options.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final opt in options)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${opt['label']} (${opt['value']})',
                      style: AppTypography.labelSmall(color: AppColors.textSub),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(
          color: color,
        ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog({this.question});
  final Map<String, dynamic>? question;

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late final TextEditingController fieldKey, label, help, options;
  late String type;
  bool required = false;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    fieldKey = TextEditingController(
      text: q == null ? '' : q['fieldKey'] as String,
    );
    label = TextEditingController(text: q == null ? '' : q['label'] as String);
    help = TextEditingController(
      text: q == null ? '' : (q['helpText'] as String? ?? ''),
    );
    type = q == null ? 'SINGLE_SELECT' : q['fieldType'] as String;
    required = q != null && q['required'] == true;
    final list = q == null ? const [] : q['options'] as List;
    options = TextEditingController(
      text: list.map((x) => '${x['value']}:${x['label']}').join('\n'),
    );
    _initialSnapshot = _snapshot();
  }

  late List<Object?> _initialSnapshot;

  List<Object?> _snapshot() => [
    fieldKey.text,
    label.text,
    help.text,
    options.text,
    type,
    required,
  ];

  bool get _isDirty => !listEquals(_snapshot(), _initialSnapshot);

  Listenable get _textFields =>
      Listenable.merge([fieldKey, label, help, options]);

  @override
  void dispose() {
    fieldKey.dispose();
    label.dispose();
    help.dispose();
    options.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.question != null;

    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.bgRose,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEditing
                          ? Icons.edit_note_rounded
                          : Icons.add_circle_outline_rounded,
                      color: AppColors.rose,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit question' : 'Add question',
                    style: AppTypography.displaySubtitle(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scrollable Form Fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field Key
                      Text('Field key', style: AppTypography.labelMedium()),
                      const SizedBox(height: 6),
                      TextField(
                        controller: fieldKey,
                        decoration: _inputDecoration(
                          hint: 'e.g. skinType, sunExposure',
                        ),
                        style: AppTypography.bodyMedium(),
                      ),
                      const SizedBox(height: 14),

                      // Question Label
                      Text('Question', style: AppTypography.labelMedium()),
                      const SizedBox(height: 6),
                      TextField(
                        controller: label,
                        decoration: _inputDecoration(
                          hint: 'e.g. What is your current skin type?',
                        ),
                        style: AppTypography.bodyMedium(),
                      ),
                      const SizedBox(height: 14),

                      // Help Text
                      Text(
                        'Help text (optional)',
                        style: AppTypography.labelMedium(),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: help,
                        decoration: _inputDecoration(
                          hint: 'Guidance shown below the question',
                        ),
                        style: AppTypography.bodyMedium(),
                      ),
                      const SizedBox(height: 14),

                      // Field Type Dropdown
                      Text('Answer type', style: AppTypography.labelMedium()),
                      const SizedBox(height: 6),
                      AppDropdownField<String>(
                        initialValue: type,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(
                            value: 'SINGLE_SELECT',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.radio_button_checked,
                                  size: 18,
                                  color: AppColors.rose,
                                ),
                                SizedBox(width: 8),
                                Text('Single choice'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'MULTI_SELECT',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.checklist,
                                  size: 18,
                                  color: AppColors.sage,
                                ),
                                SizedBox(width: 8),
                                Text('Multiple choice'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'BOOLEAN',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.toggle_on,
                                  size: 18,
                                  color: AppColors.lav,
                                ),
                                SizedBox(width: 8),
                                Text('Yes / No'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => type = v!),
                      ),
                      const SizedBox(height: 14),

                      // Required Switch Tile
                      Material(
                        color: AppColors.bgAlt,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: SwitchListTile(
                          value: required,
                          activeThumbColor: AppColors.rose,
                          onChanged: (v) => setState(() => required = v),
                          title: Text(
                            'Required',
                            style: AppTypography.labelMedium(),
                          ),
                          subtitle: Text(
                            'Must be answered before form can be submitted',
                            style: AppTypography.bodySmall(),
                          ),
                        ),
                      ),

                      // Options input
                      if (type != 'BOOLEAN') ...[
                        const SizedBox(height: 14),
                        Text('Options', style: AppTypography.labelMedium()),
                        const SizedBox(height: 4),
                        Text(
                          'Format: VALUE:Label (one per line, e.g. OILY:Oily Skin)',
                          style: AppTypography.bodySmall(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: options,
                          maxLines: 4,
                          decoration: _inputDecoration(
                            hint:
                                'DRY:Dry Skin\nOILY:Oily Skin\nCOMBINATION:Combination',
                          ),
                          style: AppTypography.bodyMedium().copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppTypography.labelLarge(color: AppColors.textSub),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ListenableBuilder(
                    listenable: _textFields,
                    builder: (context, _) => ElevatedButton(
                      onPressed: !_isDirty
                          ? null
                          : () {
                              final lines = options.text
                                  .split('\n')
                                  .where((v) => v.trim().isNotEmpty)
                                  .toList();
                              Navigator.pop(context, {
                                'fieldKey': fieldKey.text.trim(),
                                'label': label.text.trim(),
                                'helpText': help.text.trim().isEmpty
                                    ? null
                                    : help.text.trim(),
                                'fieldType': type,
                                'required': required,
                                'displayOrder': widget.question == null
                                    ? 999
                                    : widget.question!['displayOrder'],
                                'options': [
                                  for (var i = 0; i < lines.length; i++)
                                    {
                                      'value': lines[i].split(':').first.trim(),
                                      'label': lines[i].contains(':')
                                          ? lines[i]
                                                .substring(
                                                  lines[i].indexOf(':') + 1,
                                                )
                                                .trim()
                                          : lines[i].trim(),
                                      'displayOrder': i,
                                    },
                                ],
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, String? helper}) {
    return InputDecoration(
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      filled: true,
      fillColor: AppColors.bgAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
