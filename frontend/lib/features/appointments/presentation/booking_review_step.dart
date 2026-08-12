import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/appointment_api.dart';
import '../data/free_slot.dart';
import '../data/treatment.dart';
import 'booking_format.dart';
import 'booking_result_steps.dart';

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
      children: [
        Text('Review your visit', style: AppTypography.labelLarge()),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.treatment.label, style: AppTypography.labelLarge()),
                subtitle: Text(
                  '${BookingFormat.day(item.slot.startTime)} · '
                  '${BookingFormat.time12(item.slot.startTime)} · ${item.slot.practitionerName}',
                  style: AppTypography.bodySmall(),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.textMuted),
                  onPressed: submitting ? null : () => onRemove(index),
                ),
              );
            },
          ),
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: AppTypography.labelLarge()),
            Text(
              '£${BookingFormat.money(items.fold(0.0, (sum, item) => sum + item.treatment.price))}',
              style: AppTypography.displaySubtitle(),
            ),
          ],
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
                    : Text(isReschedule ? 'Confirm reschedule' : 'Confirm booking'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
