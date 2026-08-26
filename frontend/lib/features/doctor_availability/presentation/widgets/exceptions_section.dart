import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../data/doctor_availability_api.dart';

/// The date-sorted list of VACATION/MODIFIED/EXTRA_DAY exceptions.
class ExceptionsSection extends StatelessWidget {
  const ExceptionsSection({
    super.key,
    required this.exceptions,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  /// Every item here must have kind != AvailabilityKind.regular.
  final List<DoctorAvailability> exceptions;
  final VoidCallback onAdd;
  final void Function(DoctorAvailability item) onEdit;
  final void Function(DoctorAvailability item) onDelete;

  @override
  Widget build(BuildContext context) {
    final sorted = [...exceptions]
      ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 3, height: 28, color: AppColors.lav),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exceptions', style: AppTypography.labelLarge()),
                    Text(
                      'Date-specific overrides - vacations, extra days, or modified hours',
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Exception'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No exceptions scheduled.',
                  style: AppTypography.bodySmall(color: AppColors.textMuted),
                ),
              ),
            )
          else
            for (final item in sorted) _exceptionCard(item),
        ],
      ),
    );
  }

  Widget _exceptionCard(DoctorAvailability item) {
    final label = _kindLabel(item.kind);
    final color = StatusPill.accentFor(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(_kindIcon(item.kind), size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(status: label),
                      Text(_range(item), style: AppTypography.labelMedium()),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.kind == AvailabilityKind.vacation
                        ? 'No working hours'
                        : '${_short(item.startTime)} - ${_short(item.endTime)}',
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => onEdit(item),
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () => onDelete(item),
              style: TextButton.styleFrom(foregroundColor: AppColors.roseDark),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(AvailabilityKind kind) => switch (kind) {
    AvailabilityKind.vacation => 'Vacation',
    AvailabilityKind.modified => 'Modified',
    AvailabilityKind.extraDay => 'Extra Day',
    AvailabilityKind.regular => 'Regular',
  };

  IconData _kindIcon(AvailabilityKind kind) => switch (kind) {
    AvailabilityKind.vacation => Icons.beach_access_outlined,
    AvailabilityKind.modified => Icons.edit_calendar_outlined,
    AvailabilityKind.extraDay => Icons.add_circle_outline,
    AvailabilityKind.regular => Icons.event_repeat,
  };

  String _range(DoctorAvailability item) {
    final from = _date(item.effectiveFrom);
    if (item.effectiveTo == null) return from;
    final to = _date(item.effectiveTo!);
    return from == to ? from : '$from → $to';
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _short(String? value) =>
      value == null || value.length < 5 ? (value ?? '') : value.substring(0, 5);
}
