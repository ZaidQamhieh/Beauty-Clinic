import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../network/api_client.dart';
import '../../appointments/data/appointment.dart';
import '../../appointments/data/appointment_api.dart';
import '../../products/data/product.dart';
import '../../products/data/product_api.dart';
import '../data/session_record.dart';
import '../data/session_record_api.dart';

/// The "mark attended & record" / "add session record" / "view session
/// record" flow, shared by every screen that lets a doctor record a
/// session's clinical outcome (currently ClinicAppointmentsScreen and the
/// doctor's My Calendar).

class SessionRecordInput {
  const SessionRecordInput({
    required this.note,
    required this.skinReaction,
    required this.followUpDate,
    required this.prescribedProductIds,
  });

  final String? note;
  final String? skinReaction;
  final String? followUpDate;
  final List<String> prescribedProductIds;
}

/// Opens the record form, marks [session] attended if it was still planned,
/// then saves the record. Shows its own success/error snack bar. Returns
/// true on success, so the caller knows to refresh its session-record map.
Future<bool> completeSessionWithRecord({
  required BuildContext context,
  required ApiClient apiClient,
  required AppointmentApi appointmentApi,
  required String appointmentId,
  required String patientUserId,
  required AppointmentSession session,
}) async {
  try {
    final products = await ProductApi(apiClient).list();
    if (!context.mounted) return false;
    final input = await showDialog<SessionRecordInput>(
      context: context,
      builder: (_) => SessionRecordDialog(session: session, catalog: products),
    );
    if (input == null) return false;
    if (session.isPlanned) {
      await appointmentApi.markAttended(appointmentId, session.id);
    }
    await SessionRecordApi(apiClient).create(
      patientId: patientUserId,
      sessionId: session.id,
      note: input.note,
      skinReaction: input.skinReaction,
      followUpDate: input.followUpDate,
      prescribedProductIds: input.prescribedProductIds,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session completed and record saved.')),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not complete the session.')),
      );
    }
    return false;
  }
}

/// Opens the record form pre-filled with [record] and saves the edit.
/// Returns true on success.
Future<bool> editSessionRecord({
  required BuildContext context,
  required ApiClient apiClient,
  required SessionRecord record,
  required AppointmentSession session,
  required String patientUserId,
}) async {
  try {
    final products = await ProductApi(apiClient).list();
    if (!context.mounted) return false;
    final input = await showDialog<SessionRecordInput>(
      context: context,
      builder: (_) => SessionRecordDialog(
        session: session,
        catalog: products,
        initial: record,
      ),
    );
    if (input == null) return false;
    await SessionRecordApi(apiClient).amend(
      patientId: patientUserId,
      recordId: record.id,
      note: input.note,
      skinReaction: input.skinReaction,
      followUpDate: input.followUpDate,
      prescribedProductIds: input.prescribedProductIds,
    );
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not edit the session record.')),
      );
    }
    return false;
  }
}

/// Shows the read-only record, with an Edit action when [canEdit].
void showSessionRecordViewDialog({
  required BuildContext context,
  required SessionRecord record,
  bool canEdit = false,
  VoidCallback? onEdit,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        'Session record · ${record.createdAt.toLocal().toIso8601String().split('T').first}',
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (record.note == null || record.note!.trim().isEmpty)
                  ? 'No clinical note added.'
                  : record.note!,
            ),
            const SizedBox(height: 12),
            Text('Skin reaction: ${record.skinReaction ?? 'Not recorded'}'),
            if (record.followUpDate != null)
              Text('Follow-up: ${record.followUpDate}'),
            Text('Prescribed products: ${record.prescribedProductIds.length}'),
          ],
        ),
      ),
      actions: [
        if (canEdit)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onEdit?.call();
            },
            child: const Text('Edit'),
          ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Shown in place of the record when a read-only viewer (the admin
/// doctor-detail view) taps a session that has none yet - there is nothing
/// to view, and no capability here to create one.
void showNoSessionRecordDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('No session record yet'),
      content: const Text(
        'The practitioner has not added a clinical note for this session yet.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// The tri-state button: "Mark attended & record" (no record, still
/// planned) -> "Add session record" (completed, no record yet) -> "View
/// session record" (record already exists). [readOnly] (the admin
/// doctor-detail view, which can look but not record) collapses the first
/// two states into a plain "No record yet" - there is nothing it can do
/// about a missing record, so it should not read as an action to take.
class SessionRecordActionButton extends StatelessWidget {
  const SessionRecordActionButton({
    super.key,
    required this.session,
    required this.hasRecord,
    required this.onTap,
    this.readOnly = false,
  });

  final AppointmentSession session;
  final bool hasRecord;
  final VoidCallback onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(
        hasRecord
            ? Icons.visibility_outlined
            : readOnly
            ? Icons.info_outline
            : session.status == 'COMPLETED'
            ? Icons.note_add_outlined
            : Icons.check_circle_outline,
        size: 16,
      ),
      label: Text(
        hasRecord
            ? 'View session record'
            : readOnly
            ? 'No record yet'
            : session.status == 'COMPLETED'
            ? 'Add session record'
            : 'Mark attended & record',
      ),
    );
  }
}

class SessionRecordDialog extends StatefulWidget {
  const SessionRecordDialog({
    super.key,
    required this.session,
    required this.catalog,
    this.initial,
  });

  final AppointmentSession session;
  final List<Product> catalog;
  final SessionRecord? initial;

  @override
  State<SessionRecordDialog> createState() => _SessionRecordDialogState();
}

class _SessionRecordDialogState extends State<SessionRecordDialog> {
  late final TextEditingController _note;
  late final Set<String> _products;
  late String _reaction;
  DateTime? _followUp;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _note = TextEditingController(text: initial?.note ?? '');
    _products = {...?initial?.prescribedProductIds};
    _reaction = initial?.skinReaction ?? 'NONE';
    _followUp = initial?.followUpDate == null
        ? null
        : DateTime.tryParse(initial!.followUpDate!);
    _initialSnapshot = _snapshot();
  }

  late List<Object?> _initialSnapshot;

  List<Object?> _snapshot() => [
    _note.text,
    _reaction,
    _followUp,
    ..._products.toList()..sort(),
  ];

  bool get _isDirty => !listEquals(_snapshot(), _initialSnapshot);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    // A past follow-up would break the picker: initialDate can't precede firstDate.
    final start = _followUp == null || _followUp!.isBefore(now) ? now : _followUp!;
    final date = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date != null) setState(() => _followUp = date);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Session record · ${widget.session.treatmentLabel}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _note,
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Clinical note',
                  alignLabelWithHint: true,
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _reaction,
                decoration: const InputDecoration(labelText: 'Skin reaction'),
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text('None')),
                  DropdownMenuItem(value: 'MILD', child: Text('Mild')),
                  DropdownMenuItem(value: 'MODERATE', child: Text('Moderate')),
                  DropdownMenuItem(value: 'SEVERE', child: Text('Severe')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _reaction = value);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  _followUp == null
                      ? 'Add follow-up date'
                      : 'Follow-up: ${_followUp!.toIso8601String().split('T').first}',
                ),
              ),
              const SizedBox(height: 12),
              Text('Prescribe products', style: AppTypography.labelLarge()),
              ...widget.catalog.map(
                (product) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _products.contains(product.id),
                  title: Text('${product.brandLabel} ${product.typeLabel}'),
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      _products.add(product.id);
                    } else {
                      _products.remove(product.id);
                    }
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _note,
          builder: (context, _) => FilledButton(
            onPressed: !_isDirty
                ? null
                : () => Navigator.of(context).pop(
                    SessionRecordInput(
                      note: _note.text.trim().isEmpty
                          ? null
                          : _note.text.trim(),
                      skinReaction: _reaction,
                      followUpDate: _followUp
                          ?.toIso8601String()
                          .split('T')
                          .first,
                      prescribedProductIds: _products.toList(),
                    ),
                  ),
            child: const Text('Save session record'),
          ),
        ),
      ],
    );
  }
}
