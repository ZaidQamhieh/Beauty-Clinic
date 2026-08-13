import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/appointment.dart';
import 'booking_format.dart';

/// The booked visit, once confirmed.
class BookingSuccessStep extends StatelessWidget {
  const BookingSuccessStep({
    super.key,
    required this.appointment,
    required this.isReschedule,
    required this.onDone,
  });

  final Appointment appointment;
  final bool isReschedule;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Hugs its sessions, so a one-treatment visit is not a screen of nothing.
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, color: AppColors.sage, size: 44),
        const SizedBox(height: 12),
        Text(
          isReschedule ? 'Appointment rescheduled' : 'Appointment booked',
          style: AppTypography.displaySubtitle(),
        ),
        const SizedBox(height: 4),
        Text(
          BookingFormat.dayWithYear(appointment.scheduledAt),
          style: AppTypography.bodyMedium(),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final session in appointment.plannedSessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.spa_outlined,
                        size: 18,
                        color: AppColors.rose,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${session.treatmentLabel} · ${BookingFormat.time12(session.startTime)} · '
                          '${session.practitionerName}',
                          style: AppTypography.bodyMedium(),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: onDone,
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

/// Shown until the health form is filled.
class BookingGateStep extends StatelessWidget {
  const BookingGateStep({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.assignment_late_outlined,
            size: 44,
            color: AppColors.gold,
          ),
          const SizedBox(height: 12),
          Text(
            'Complete your health form first',
            style: AppTypography.displaySubtitle(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'The clinic needs your health form before your first treatment. '
            'Fill it in from your medical profile, then come back to book.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: onClose,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// A centred message, with optional retry.
class BookingMessage extends StatelessWidget {
  const BookingMessage({
    super.key,
    required this.icon,
    required this.text,
    this.onRetry,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

/// The red strip carrying a refusal reason.
class BookingErrorBanner extends StatelessWidget {
  const BookingErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: AppTypography.bodySmall(color: const Color(0xFFDC2626)),
      ),
    );
  }
}
