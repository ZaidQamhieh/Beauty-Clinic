import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/admin_analytics_models.dart';

class AdminDateFilterBar extends StatelessWidget {
  final AdminDateRangeType selectedRangeType;
  final DateTimeRange? customDateRange;
  final String formattedRange;
  final void Function(AdminDateRangeType rangeType, DateTimeRange? customRange)
  onRangeSelected;

  const AdminDateFilterBar({
    super.key,
    required this.selectedRangeType,
    required this.customDateRange,
    required this.formattedRange,
    required this.onRangeSelected,
  });

  Future<void> _handleCustomDatePick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialStart =
        customDateRange?.start ?? now.subtract(const Duration(days: 30));
    final DateTime initialEnd = customDateRange?.end ?? now;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      initialEntryMode: DatePickerEntryMode.input,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.rose,
              onPrimary: AppColors.white,
              surface: AppColors.bgCard,
              onSurface: AppColors.text,
              secondary: AppColors.lav,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onRangeSelected(AdminDateRangeType.custom, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 620;
        final Widget card = _buildCard(context, isNarrow: isNarrow);

        // Wide: card hugs contents, sits left.
        if (isNarrow) return card;
        return Align(alignment: Alignment.centerLeft, child: card);
      },
    );
  }

  Widget _buildCard(BuildContext context, {required bool isNarrow}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSegmentedButtons(context),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildDateBadge(),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSegmentedButtons(context),
                const SizedBox(width: 16),
                _buildDateBadge(),
              ],
            ),
    );
  }

  Widget _buildSegmentedButtons(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.bgAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: AdminDateRangeType.values.map((type) {
                final bool isSelected = selectedRangeType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: InkWell(
                    onTap: () {
                      if (type == AdminDateRangeType.custom) {
                        _handleCustomDatePick(context);
                      } else {
                        onRangeSelected(type, null);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isSelected
                            ? [
                                const BoxShadow(
                                  color: AppColors.shadow,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (type == AdminDateRangeType.custom) ...[
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 14,
                              color: isSelected
                                  ? AppColors.rose
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            type.label,
                            style:
                                AppTypography.labelSmall(
                                  color: isSelected
                                      ? AppColors.roseDark
                                      : AppColors.textSub,
                                ).copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.date_range_outlined,
            size: 16,
            color: AppColors.rose,
          ),
          const SizedBox(width: 8),
          Text(
            formattedRange,
            style: AppTypography.labelSmall(
              color: AppColors.roseDark,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
