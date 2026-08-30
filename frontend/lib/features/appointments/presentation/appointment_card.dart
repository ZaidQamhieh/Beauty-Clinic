import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/status_pill.dart';
import '../../patient_profile/data/session_record.dart';
import '../data/appointment.dart';
import 'booking_format.dart';

class UpcomingCard extends StatelessWidget {
  const UpcomingCard({
    super.key,
    required this.appointment,
    required this.cancellable,
    required this.onCancel,
    required this.onReschedule,
    required this.onCancelSession,
  });

  final Appointment appointment;

  /// False once the cancellation cutoff has passed.
  final bool cancellable;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;

  /// Drops one treatment; the rest stays.
  final ValueChanged<AppointmentSession> onCancelSession;

  @override
  Widget build(BuildContext context) {
    final sessions = [...appointment.sessions]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return _AppointmentCard(
      appointment: appointment,
      // Still to come, else all of them.
      sessions: sessions,
      statusLabel: 'Confirmed',
      // Soonest treatment stands out; rest recedes.
      highlightNext: true,
      // Only useful with more than one treatment.
      sessionTrailing: cancellable && sessions.length > 1
          ? (session) => session.isPlanned
                ? IconButton(
                    tooltip: 'Cancel this treatment',
                    onPressed: () => onCancelSession(session),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.bgAlt,
                      shape: const CircleBorder(),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.close,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  )
                : null
          : null,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!cancellable) ...[
            Text(
              'Too close to the appointment to change it. Call the clinic.',
              style: AppTypography.bodySmall(),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: OutlinedButton(
                  onPressed: cancellable ? onCancel : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FilledButton(
                  onPressed: cancellable ? onReschedule : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rose,
                  ),
                  child: const Text(
                    'Reschedule',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.appointment,
    this.recordsBySession = const {},
    this.recordHistoryBySession = const {},
    this.productNamesById = const {},
  });

  final Appointment appointment;

  /// The doctor's current record per treatment.
  final Map<String, SessionRecord> recordsBySession;

  /// Older, superseded versions per treatment, newest first - lets a
  /// patient see a note was corrected and what it said before.
  final Map<String, List<SessionRecord>> recordHistoryBySession;

  /// Names for products the record prescribes.
  final Map<String, String> productNamesById;

  @override
  Widget build(BuildContext context) {
    return _AppointmentCard(
      appointment: appointment,
      // What was delivered, not just planned.
      sessions: [...appointment.sessions]
        ..sort((a, b) => a.startTime.compareTo(b.startTime)),
      statusLabel: historyStatus(appointment),
      footer: Align(
        alignment: Alignment.centerRight,
        child: Tooltip(
          message: _hasAnyRecord
              ? 'Read what the doctor wrote'
              : 'The doctor wrote no notes for this visit',
          child: OutlinedButton.icon(
            onPressed: _hasAnyRecord ? () => _openNotes(context) : null,
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Text('Doctor\'s notes'),
          ),
        ),
      ),
    );
  }

  bool get _hasAnyRecord => appointment.sessions.any(
    (session) => recordsBySession[session.id] != null,
  );

  void _openNotes(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => TreatmentNotesDialog(
        appointment: appointment,
        recordsBySession: recordsBySession,
        recordHistoryBySession: recordHistoryBySession,
        productNamesById: productNamesById,
      ),
    );
  }

  // Visit outcome, read from its treatments.
  static String historyStatus(Appointment appointment) {
    if (!appointment.isBooked) return 'Cancelled';

    final sessions = appointment.sessions;
    if (sessions.isEmpty) return 'Planned';
    if (sessions.every((s) => s.status == 'COMPLETED')) return 'Completed';
    if (sessions.every((s) => s.status == 'CANCELLED')) return 'Cancelled';
    if (sessions.every((s) => s.status == 'NO_SHOW')) return 'Missed';

    // Any planned treatment keeps the visit planned, not yet completed.
    final hasPlanned = sessions.any((s) => s.isPlanned);
    if (sessions.any((s) => s.status == 'COMPLETED') && !hasPlanned) {
      return 'Completed';
    }
    return 'Planned';
  }
}

/// Side inset every row but next.
const EdgeInsets _inset = EdgeInsets.symmetric(horizontal: 8);

/// What the doctor wrote after a treatment.
class TreatmentRecordPanel extends StatelessWidget {
  const TreatmentRecordPanel({
    super.key,
    required this.record,
    this.productNamesById = const {},
    this.previousVersions = const [],
  });

  final SessionRecord record;
  final Map<String, String> productNamesById;

  /// Older, superseded versions of this same record, newest first - a note
  /// the doctor corrected still leaves what it said before visible, not
  /// just what it says now.
  final List<SessionRecord> previousVersions;

  @override
  Widget build(BuildContext context) {
    final note = record.note?.trim();
    final reaction = record.skinReaction;
    final products = record.prescribedProductIds
        .map((id) => productNamesById[id])
        .whereType<String>()
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Treatment record · ${BookingFormat.dayWithYear(record.createdAt)}',
                  style: AppTypography.labelSmall(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note == null || note.isEmpty
                ? 'The doctor left no written note.'
                : note,
            style: AppTypography.bodySmall(),
          ),
          if (record.authorName != null && record.authorName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              record.authorName!,
              style: AppTypography.bodySmall(color: AppColors.textMuted),
            ),
          ],
          if (reaction != null && reaction != 'NONE')
            _line('Skin reaction: ${_humanize(reaction)}'),
          if (record.followUpDate != null)
            _line('Follow-up: ${record.followUpDate}'),
          if (products.isNotEmpty) _line('Prescribed: ${products.join(', ')}'),
          if (previousVersions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Previously:',
              style: AppTypography.labelSmall(color: AppColors.textMuted),
            ),
            for (final version in previousVersions)
              GestureDetector(
                onTap: () => _showPreviousVersion(context, version),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    BookingFormat.dayWithYear(version.createdAt),
                    style: AppTypography.bodySmall(
                      color: AppColors.textMuted,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showPreviousVersion(BuildContext context, SessionRecord version) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Earlier note · ${BookingFormat.dayWithYear(version.createdAt)}',
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: TreatmentRecordPanel(
              record: version,
              productNamesById: productNamesById,
            ),
          ),
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

  Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: AppTypography.bodySmall(color: AppColors.textMuted),
    ),
  );

  static String _humanize(String value) => value
      .toLowerCase()
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

/// One visit's treatments and records.
class TreatmentNotesDialog extends StatelessWidget {
  const TreatmentNotesDialog({
    super.key,
    required this.appointment,
    required this.recordsBySession,
    this.recordHistoryBySession = const {},
    this.productNamesById = const {},
  });

  final Appointment appointment;
  final Map<String, SessionRecord> recordsBySession;
  final Map<String, List<SessionRecord>> recordHistoryBySession;
  final Map<String, String> productNamesById;

  @override
  Widget build(BuildContext context) {
    final sessions = [...appointment.sessions]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text('Doctor\'s notes', style: AppTypography.displaySubtitle()),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${BookingFormat.dayWithYear(appointment.scheduledAt)} · '
                '${sessions.length} treatment(s)',
                style: AppTypography.bodySmall(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              if (sessions.isEmpty)
                Text(
                  'This visit has no treatments on it.',
                  style: AppTypography.bodySmall(color: AppColors.textMuted),
                ),
              for (final session in sessions) ...[
                Text(
                  session.treatmentLabel,
                  style: AppTypography.labelMedium(),
                ),
                const SizedBox(height: 2),
                Text(
                  '${BookingFormat.time12(session.startTime)} · '
                  '${session.practitionerName}',
                  style: AppTypography.bodySmall(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                if (recordsBySession[session.id] case final record?)
                  TreatmentRecordPanel(
                    record: record,
                    productNamesById: productNamesById,
                    previousVersions:
                        recordHistoryBySession[session.id] ?? const [],
                  )
                else
                  Text(
                    'No record for this treatment.',
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.sessions,
    required this.statusLabel,
    this.footer,
    this.sessionTrailing,
    this.highlightNext = false,
  });

  final Appointment appointment;

  /// Which treatments to list; the caller decides.
  final List<AppointmentSession> sessions;
  final String statusLabel;
  final Widget? footer;

  /// Per-session action; null hides it.
  final Widget? Function(AppointmentSession session)? sessionTrailing;

  /// Weights next session; only for upcoming visits.
  final bool highlightNext;

  // Cancelled visits recede; others read first.
  bool get _muted => statusLabel == 'Cancelled';

  // A cancelled visit cancels every session alike, so one label up top says
  // it all. Anything else can have sessions in genuinely different states
  // (one done, one still booked, one missed) that a single visit-level word
  // would flatten - so each session carries its own status instead.
  bool get _showTopStatus => _muted;

  @override
  Widget build(BuildContext context) {
    String? nextId;
    if (highlightNext) {
      for (final session in sessions) {
        if (session.isPlanned) {
          nextId = session.id;
          break;
        }
      }
    }
    final headerTime = highlightNext && sessions.isNotEmpty
        ? sessions
              .firstWhere(
                (session) => session.isPlanned,
                orElse: () => sessions.first,
              )
              .startTime
        : appointment.scheduledAt;

    return Opacity(
      opacity: _muted ? 0.6 : 1,
      child: Container(
        // Sides sit on children; next row bleeds.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: _muted ? AppColors.bgAlt : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: _inset,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${BookingFormat.day(headerTime)} · '
                      '${BookingFormat.time12(headerTime)}',
                      style: AppTypography.labelLarge(),
                    ),
                  ),
                  if (_showTopStatus) StatusPill(status: statusLabel),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: _inset,
              child: Divider(height: 1, color: AppColors.border),
            ),
            const SizedBox(height: 10),
            for (final session in sessions)
              _SessionRow(
                session: session,
                isNext: session.id == nextId,
                trailing: sessionTrailing?.call(session),
                showStatus: !_showTopStatus,
              ),
            if (footer != null) ...[
              const SizedBox(height: 4),
              Padding(padding: _inset, child: footer!),
            ],
          ],
        ),
      ),
    );
  }
}

// A session's own status, one at a time - now the same four words
// HistoryCard.historyStatus uses for the whole visit (Planned/Completed/
// Cancelled/Missed), just per session instead of summarized across all of
// them.
String _sessionStatusLabel(AppointmentSession session) {
  return switch (session.status) {
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    'NO_SHOW' => 'Missed',
    _ => 'Planned',
  };
}

/// One row; soonest treatment weighted, rest recede.
class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.isNext,
    this.trailing,
    this.showStatus = false,
  });

  final AppointmentSession session;
  final bool isNext;
  final Widget? trailing;

  /// Shows this session's own status pill - used once the card no longer
  /// shows a single status for the whole visit (see
  /// _AppointmentCard._showTopStatus).
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CategoryBadge(
          category: session.category,
          backgroundOverride: isNext ? AppColors.bgCard : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    session.treatmentLabel,
                    style: AppTypography.labelMedium(),
                  ),
                  if (isNext) ...[
                    const SizedBox(width: 6),
                    Text(
                      'NEXT',
                      style: AppTypography.labelSmall(
                        color: AppColors.roseDark,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${BookingFormat.time12(session.startTime)} · '
                      '${session.practitionerName}',
                      style: AppTypography.bodySmall(),
                    ),
                  ),
                  if (showStatus) ...[
                    const SizedBox(width: 6),
                    StatusPill(status: _sessionStatusLabel(session)),
                  ],
                ],
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );

    if (isNext) {
      // Text stays aligned; tint runs wider.
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.rosePale,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(padding: const EdgeInsets.only(bottom: 2), child: row),
      );
    }
    return Padding(
      padding: _inset.copyWith(bottom: 8),
      child: Opacity(opacity: 0.6, child: row),
    );
  }
}

/// Tinted glyph per category, for quick scanning.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, this.backgroundOverride});

  final String category;

  /// Swaps tint when row has one.
  final Color? backgroundOverride;

  static const _byCategory = {
    'FACIAL': (Icons.spa_outlined, AppColors.sage, AppColors.bgSage),
    'LASER': (Icons.bolt_outlined, AppColors.gold, AppColors.goldPale),
    'INJECTABLE': (Icons.vaccines_outlined, AppColors.rose, AppColors.bgRose),
    'BODY': (
      Icons.self_improvement_outlined,
      AppColors.lav,
      AppColors.bgLavender,
    ),
    'CONSULTATION': (
      Icons.chat_bubble_outline,
      AppColors.textSub,
      AppColors.bgAlt,
    ),
  };
  static const _fallback = (
    Icons.medical_services_outlined,
    AppColors.textSub,
    AppColors.bgAlt,
  );

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg) = _byCategory[category] ?? _fallback;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: backgroundOverride ?? bg,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 15, color: fg),
    );
  }
}
