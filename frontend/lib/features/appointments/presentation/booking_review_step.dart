import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/appointment_api.dart';
import '../data/clinic_time.dart';
import '../data/free_slot.dart';
import '../data/treatment.dart';
import 'booking_format.dart';
import 'booking_result_steps.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// One chosen treatment, waiting to be booked.
class BookingCartItem {
  const BookingCartItem({required this.treatment, required this.slot});

  final Treatment treatment;
  final FreeSlot slot;

  HeldSlot get held => HeldSlot(
    practitionerUserId: slot.practitionerUserId,
    startTime: slot.startTime,
    endTime: slot.endTime,
  );

  SessionDraft get draft => SessionDraft(
    practitionerUserId: slot.practitionerUserId,
    treatmentName: treatment.name,
    startTime: slot.startTime,
  );
}

/// The chosen treatments, total, and confirm.
class BookingReviewStep extends StatelessWidget {
  const BookingReviewStep({
    super.key,
    required this.items,
    required this.submitting,
    required this.isReschedule,
    required this.errorMessage,
    required this.onRemove,
    required this.onAddAnother,
    required this.onSubmit,
  });

  final List<BookingCartItem> items;
  final bool submitting;
  final bool isReschedule;
  final String? errorMessage;

  final ValueChanged<int> onRemove;
  final VoidCallback onAddAnother;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Hugs the ticket, and only scrolls once the visit outgrows the sheet.
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Review your visit', style: AppTypography.labelLarge()),
        const SizedBox(height: 12),
        Flexible(
          child: items.isEmpty
              ? const SizedBox.shrink()
              : SingleChildScrollView(child: _ticket()),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          BookingErrorBanner(message: errorMessage!),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: submitting ? null : onAddAnother,
                child: const Text('Add another'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
                onPressed: submitting || items.isEmpty ? null : onSubmit,
                child: submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isReschedule ? 'Confirm reschedule' : 'Confirm booking',
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // A ticket: the date on its own stub, the visit itself beside it. Chronological
  // rather than in the order treatments were added, so it reads as the day runs.
  Widget _ticket() {
    final ordered = [...items]
      ..sort((a, b) => a.slot.startTime.compareTo(b.slot.startTime));
    final at = ClinicTime.at(ordered.first.slot.startTime);
    final total = items.fold(0.0, (sum, item) => sum + item.treatment.price);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 96,
              decoration: const BoxDecoration(
                color: AppColors.bgRose,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(15),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${at.day}',
                    style: AppTypography.displayTitle(
                      color: AppColors.roseDark,
                    ),
                  ),
                  Text(
                    _months[at.month - 1].toUpperCase(),
                    style: AppTypography.labelSmall(color: AppColors.roseDark),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    BookingFormat.time12(ordered.first.slot.startTime),
                    style: AppTypography.labelMedium(color: AppColors.roseDark),
                  ),
                ],
              ),
            ),
            Container(width: 1, color: AppColors.borderRose),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final item in ordered) _treatmentRow(item),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_durationLabel, style: AppTypography.bodySmall()),
                        Text(
                          BookingFormat.money(total),
                          style: AppTypography.labelLarge(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _treatmentRow(BookingCartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.treatment.label, style: AppTypography.labelMedium()),
                Text(
                  '${BookingFormat.time12(item.slot.startTime)} · '
                  '${item.treatment.durationMinutes} min · '
                  '${item.slot.practitionerName}',
                  style: AppTypography.bodySmall(),
                ),
              ],
            ),
          ),
          Text(
            BookingFormat.money(item.treatment.price),
            style: AppTypography.labelMedium(),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            // Keyed on the caller's order, which is not the display order.
            onPressed: submitting ? null : () => onRemove(items.indexOf(item)),
          ),
        ],
      ),
    );
  }

  String get _durationLabel {
    final minutes = items.fold(
      0,
      (sum, item) => sum + item.treatment.durationMinutes,
    );
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest min';
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }
}
