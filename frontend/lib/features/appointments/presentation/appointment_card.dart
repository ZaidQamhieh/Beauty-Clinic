import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/status_pill.dart';
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
    final sessions = appointment.plannedSessions.isNotEmpty
        ? appointment.plannedSessions
        : appointment.sessions;
    return _AppointmentCard(
      appointment: appointment,
      // Still to come, or all if none planned.
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
  const HistoryCard({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return _AppointmentCard(
      appointment: appointment,
      // What was delivered, not only what is planned.
      sessions: [...appointment.sessions]
        ..sort((a, b) => a.startTime.compareTo(b.startTime)),
      statusLabel: historyStatus(appointment),
    );
  }

  // What became of the visit, per its treatments.
  static String historyStatus(Appointment appointment) {
    if (!appointment.isBooked) return 'Cancelled';
    final sessions = appointment.sessions;
    if (sessions.any((s) => s.status == 'COMPLETED')) return 'Completed';
    if (sessions.isEmpty) return 'Pending';
    if (sessions.every((s) => s.status == 'CANCELLED')) return 'Cancelled';
    // Nothing delivered and nothing left planned.
    if (sessions.every((s) => !s.isPlanned)) return 'Missed';
    // Past, but no outcome was recorded.
    return 'Pending';
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

    return Opacity(
      opacity: _muted ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _muted ? AppColors.bgAlt : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${BookingFormat.day(appointment.scheduledAt)} · '
                    '${BookingFormat.time12(appointment.scheduledAt)}',
                    style: AppTypography.labelLarge(),
                  ),
                ),
                StatusPill(status: statusLabel),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            for (final session in sessions)
              _SessionRow(
                session: session,
                isNext: session.id == nextId,
                trailing: sessionTrailing?.call(session),
              ),
            if (footer != null) ...[const SizedBox(height: 4), footer!],
          ],
        ),
      ),
    );
  }
}

/// One row; soonest treatment weighted, rest recede.
class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.isNext,
    this.trailing,
  });

  final AppointmentSession session;
  final bool isNext;
  final Widget? trailing;

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
              Text(
                '${BookingFormat.time12(session.startTime)} · '
                '${session.practitionerName}',
                style: AppTypography.bodySmall(),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );

    if (isNext) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: -8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.rosePale,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(padding: const EdgeInsets.only(bottom: 2), child: row),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(opacity: 0.6, child: row),
    );
  }
}

/// Tinted glyph per category, for quick scanning.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, this.backgroundOverride});

  final String category;

  /// Swaps the tint when row has its own.
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
