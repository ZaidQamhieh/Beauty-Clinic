import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/doctor_availability_api.dart';

/// The doctor's recurring weekly pattern: one row per weekday, each holding
/// zero or more REGULAR slots. A gap within a day (e.g. a lunch break) is
/// just two slots rather than one slot with a break carved out of it.
class WeeklyScheduleSection extends StatelessWidget {
  const WeeklyScheduleSection({
    super.key,
    required this.regular,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<DoctorAvailability> regular;
  final void Function(AvailabilityDay day) onAdd;
  final void Function(DoctorAvailability item) onEdit;
  final void Function(DoctorAvailability item) onDelete;

  @override
  Widget build(BuildContext context) {
    final days = AvailabilityDay.values;
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
            children: [
              Container(width: 3, height: 28, color: AppColors.sage),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Schedule', style: AppTypography.labelLarge()),
                    Text(
                      'Recurring availability - applies every week unless overridden',
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (var i = 0; i < days.length; i++) ...[
            _dayRow(days[i]),
            if (i != days.length - 1)
              const Divider(height: 1, color: AppColors.hairline),
          ],
        ],
      ),
    );
  }

  Widget _dayRow(AvailabilityDay day) {
    final slots = regular.where((item) => item.dayOfWeek == day).toList()
      ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(day),
                  style: AppTypography.labelMedium(
                    color: slots.isEmpty ? AppColors.textMuted : AppColors.text,
                  ),
                ),
                if (slots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Not available',
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final slot in slots) _slotChip(slot),
                OutlinedButton.icon(
                  onPressed: () => onAdd(day),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 30),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add slot'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotChip(DoctorAvailability slot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_short(slot.startTime)} - ${_short(slot.endTime)}',
            style: AppTypography.labelSmall(color: AppColors.sageDark),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => onEdit(slot),
            child: const Icon(
              Icons.edit_outlined,
              size: 14,
              color: AppColors.sageDark,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => onDelete(slot),
            child: const Icon(Icons.close, size: 14, color: AppColors.roseDark),
          ),
        ],
      ),
    );
  }

  String _short(String? value) =>
      value == null || value.length < 5 ? (value ?? '') : value.substring(0, 5);

  String _label(AvailabilityDay day) =>
      day.name[0].toUpperCase() + day.name.substring(1);
}
