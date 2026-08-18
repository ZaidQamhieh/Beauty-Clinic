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
      // Hugs its sessions; one treatment fills little.
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

/// Browse's shape while the first load runs.
class BookingBrowseSkeleton extends StatelessWidget {
  const BookingBrowseSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Wide fills the frame, matching browse.
          if (constraints.maxWidth >= 720) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: 340, child: _LeftSkeleton(fill: true)),
                const SizedBox(width: 24),
                const Expanded(child: _CardsSkeleton(fill: true)),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _LeftSkeleton(fill: false),
                const SizedBox(height: 20),
                const _CardsSkeleton(fill: false),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The times panel alone, mid-search.
class BookingSlotsSkeleton extends StatelessWidget {
  const BookingSlotsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Pulse(child: _CardsSkeleton(fill: false));
  }
}

/// Fades its child; marks it unreal.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: widget.child,
    );
  }
}

/// Treatment field, view toggle, then calendar.
class _LeftSkeleton extends StatelessWidget {
  const _LeftSkeleton({required this.fill});

  final bool fill;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _bar(width: 140, height: 10),
        const SizedBox(height: 10),
        _block(height: 44),
        const SizedBox(height: 18),
        _bar(width: 120, height: 10),
        const SizedBox(height: 10),
        _block(height: 38),
        const SizedBox(height: 18),
        // Calendar takes what the fields leave.
        if (fill) Expanded(child: _block()) else _block(height: 250),
      ],
    );
  }
}

/// Panel heading over stand-in slot cards.
class _CardsSkeleton extends StatelessWidget {
  const _CardsSkeleton({required this.fill});

  final bool fill;

  static const _count = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _bar(width: 180, height: 12),
        const SizedBox(height: 8),
        _bar(width: 240, height: 10),
        const SizedBox(height: 18),
        // Filling shares the height; else fixed cards.
        if (fill)
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < _count; i++) ...[
                  Expanded(child: _block()),
                  if (i < _count - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          )
        else
          for (var i = 0; i < _count; i++) ...[
            _block(height: 68),
            if (i < _count - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }
}

Widget _bar({required double width, required double height}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.hairline,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

// Null height lets Expanded size it.
Widget _block({double? height}) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.bgAlt,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
  );
}
