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
    required this.unedited,
    required this.errorMessage,
    required this.onRemove,
    required this.onAddAnother,
    required this.onSubmit,
  });

  final List<BookingCartItem> items;
  final bool submitting;
  final bool isReschedule;

  /// Matches what's already booked; nothing to confirm.
  final bool unedited;
  final String? errorMessage;

  final ValueChanged<int> onRemove;
  final VoidCallback onAddAnother;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Hugs the ticket; scrolls if it outgrows.
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
        ] else if (unedited) ...[
          const SizedBox(height: 8),
          Text(
            'Nothing changed yet — remove, add, or move a treatment to '
            'reschedule.',
            style: AppTypography.bodySmall(),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: OutlinedButton(
                onPressed: submitting ? null : onAddAnother,
                child: const Text('Add another'),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
                onPressed: submitting || items.isEmpty || unedited
                    ? null
                    : onSubmit,
                child: submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isReschedule ? 'Confirm reschedule' : 'Confirm booking',
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Day header, then treatments on a timeline.
  Widget _ticket() {
    final ordered = [...items]
      ..sort((a, b) => a.slot.startTime.compareTo(b.slot.startTime));
    final total = items.fold(0.0, (sum, item) => sum + item.treatment.price);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BookingFormat.day(ordered.first.slot.startTime),
            style: AppTypography.labelMedium(
              color: AppColors.roseDark,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderRose),
          const SizedBox(height: 14),
          for (var i = 0; i < ordered.length; i++)
            _timelineRow(ordered[i], isLast: i == ordered.length - 1),
          const Divider(height: 20),
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
    );
  }

  Widget _timelineRow(BookingCartItem item, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: AppColors.rose,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgCard, width: 2),
                    boxShadow: const [
                      BoxShadow(color: AppColors.rose, spreadRadius: 1.5),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(top: 3),
                      color: AppColors.borderRose,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    BookingFormat.time12(item.slot.startTime),
                    style: AppTypography.labelSmall(
                      color: AppColors.roseDark,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.treatment.label,
                          style: AppTypography.labelMedium(),
                        ),
                      ),
                      Text(
                        BookingFormat.money(item.treatment.price),
                        style: AppTypography.labelMedium(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.bgAlt,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        // Keyed on caller's order, not display order.
                        onPressed: submitting
                            ? null
                            : () => onRemove(items.indexOf(item)),
                      ),
                    ],
                  ),
                  Text(
                    '${item.treatment.durationMinutes} min · '
                    '${item.slot.practitionerName}',
                    style: AppTypography.bodySmall(),
                  ),
                ],
              ),
            ),
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
