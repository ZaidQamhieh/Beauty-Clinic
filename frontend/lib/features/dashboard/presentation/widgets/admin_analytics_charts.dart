import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/admin_analytics_models.dart';

/// Gridline step suited to the data.
double _axisStep(double top) {
  if (top <= 0) return 1;
  final double rough = top / 4;
  for (final double nice in [1, 2, 5, 10, 20, 25, 50, 100, 200, 500, 1000]) {
    if (rough <= nice) return nice;
  }
  return 2000;
}

// 1. SERVICE ANALYTICS WIDGETS

/// Interactive bar breakdown of bookings.
class ServiceBookingsBarChart extends StatelessWidget {
  final ServiceAnalyticsData data;
  final bool showTopService;

  const ServiceBookingsBarChart({
    super.key,
    required this.data,
    this.showTopService = true,
  });

  @override
  Widget build(BuildContext context) {
    final finishedAppointments = data.bookingsByService.fold<int>(
      0,
      (total, item) => total + item.bookingsCount,
    );
    return _AnalyticsCard(
      title: 'Bookings by Service',
      subtitle: 'Distribution of patient treatments & service popularity',
      icon: Icons.bar_chart_rounded,
      badgeText: showTopService
          ? '$finishedAppointments finished appointments'
          : null,
      badgeColor: AppColors.rose,
      child: data.bookingsByService.isEmpty
          ? Text(
              'No completed bookings in this period.',
              style: AppTypography.bodySmall(color: AppColors.textMuted),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // Two abreast when names fit.
                final int columns = constraints.maxWidth >= 440 ? 2 : 1;
                final items = data.bookingsByService;
                final List<Widget> lines = [];

                for (int start = 0; start < items.length; start += columns) {
                  final slice = items.skip(start).take(columns).toList();
                  lines.add(
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A short last row spans the width.
                        for (int i = 0; i < slice.length; i++) ...[
                          if (i > 0) const SizedBox(width: 20),
                          Expanded(child: _buildServiceRow(slice[i])),
                        ],
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lines,
                );
              },
            ),
    );
  }

  Widget _buildServiceRow(ServiceBookingItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 16, color: item.accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.serviceName,
                      style: AppTypography.labelMedium(color: AppColors.text),
                    ),
                    Text(
                      item.category,
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.bookingsCount} appts',
                    style: AppTypography.labelMedium(
                      color: AppColors.text,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${item.percentage.toStringAsFixed(1)}% · ${item.revenue}',
                    style: AppTypography.bodySmall(
                      color: item.accentColor,
                    ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (item.percentage / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.bgAlt,
              valueColor: AlwaysStoppedAnimation<Color>(item.accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Service Growth Over Time (Curved Multi-Line Chart)
class ServiceGrowthLineChart extends StatelessWidget {
  final ServiceAnalyticsData data;

  const ServiceGrowthLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final double top = data.growthOverTime.isEmpty
        ? 0
        : data.growthOverTime
              .expand(
                (point) => [
                  point.laserCount,
                  point.facialCount,
                  point.contourCount,
                  point.injectableCount,
                ],
              )
              .reduce((a, b) => a > b ? a : b);
    final double step = _axisStep(top);

    return _AnalyticsCard(
      title: 'Service Growth Over Time',
      subtitle: 'Volume trajectory across core treatment categories',
      icon: Icons.show_chart_rounded,
      badgeText: null,
      badgeColor: AppColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              _LegendItem(label: 'Laser & Energy', color: AppColors.rose),
              _LegendItem(label: 'Skin Care / Facials', color: AppColors.lav),
              _LegendItem(label: 'Body Contouring', color: AppColors.sage),
              _LegendItem(label: 'Injectables', color: AppColors.gold),
            ],
          ),
          const SizedBox(height: 14),

          // Line Chart
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: step,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: AppColors.hairline, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: step,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: AppTypography.bodySmall(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final int index = value.toInt();
                        if (index >= 0 && index < data.growthOverTime.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data.growthOverTime[index].dateLabel,
                              style: AppTypography.labelSmall(
                                color: AppColors.textMuted,
                              ).copyWith(fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _buildLineSeries(
                    spots: data.growthOverTime
                        .asMap()
                        .entries
                        .map(
                          (e) => FlSpot(e.key.toDouble(), e.value.laserCount),
                        )
                        .toList(),
                    color: AppColors.rose,
                  ),
                  _buildLineSeries(
                    spots: data.growthOverTime
                        .asMap()
                        .entries
                        .map(
                          (e) => FlSpot(e.key.toDouble(), e.value.facialCount),
                        )
                        .toList(),
                    color: AppColors.lav,
                  ),
                  _buildLineSeries(
                    spots: data.growthOverTime
                        .asMap()
                        .entries
                        .map(
                          (e) => FlSpot(e.key.toDouble(), e.value.contourCount),
                        )
                        .toList(),
                    color: AppColors.sage,
                  ),
                  _buildLineSeries(
                    spots: data.growthOverTime
                        .asMap()
                        .entries
                        .map(
                          (e) =>
                              FlSpot(e.key.toDouble(), e.value.injectableCount),
                        )
                        .toList(),
                    color: AppColors.gold,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLineSeries({
    required List<FlSpot> spots,
    required Color color,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 3.5,
          color: color,
          strokeWidth: 2,
          strokeColor: AppColors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }
}

// 2. DOCTOR ANALYTICS WIDGETS

/// Doctor Utilization Bar Chart
class DoctorUtilizationChart extends StatelessWidget {
  final DoctorAnalyticsData data;

  const DoctorUtilizationChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Doctor Utilization',
      subtitle: 'Booked hours vs total clinical capacity per practitioner',
      icon: Icons.medical_information_outlined,
      badgeText:
          '${data.averageUtilization.toStringAsFixed(1)}% Avg Utilization',
      badgeColor: AppColors.lavDark,
      child: Column(
        children: data.utilizationList.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: item.statusColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                item.doctorName
                                    .split(' ')
                                    .map((s) => s.isNotEmpty ? s[0] : '')
                                    .take(2)
                                    .join(),
                                style: AppTypography.labelSmall(
                                  color: item.statusColor,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.doctorName,
                                style: AppTypography.labelLarge(
                                  color: AppColors.text,
                                ),
                              ),
                              Text(
                                item.specialty,
                                style: AppTypography.bodySmall(
                                  color: AppColors.textMuted,
                                ).copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          item.status,
                          style: AppTypography.labelSmall(
                            color: item.statusColor,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.bookedHours}h booked / ${item.totalAvailableHours}h capacity',
                        style: AppTypography.bodySmall(
                          color: AppColors.textSub,
                        ).copyWith(fontSize: 12),
                      ),
                      Text(
                        '${item.utilizationPercentage.toStringAsFixed(1)}%',
                        style: AppTypography.labelLarge(
                          color: item.statusColor,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (item.utilizationPercentage / 100).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: AppColors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        item.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Available Slots per Doctor
class AvailableSlotsWidget extends StatelessWidget {
  final DoctorAnalyticsData data;

  const AvailableSlotsWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Available Slots per Doctor',
      subtitle: 'Real-time open appointment capacity & room assignments',
      icon: Icons.event_available_outlined,
      badgeText: '${data.totalFreeSlotsToday} Open Slots Today',
      badgeColor: AppColors.sageDark,
      child: data.availableSlotsList.isEmpty
          ? Text(
              'No open slots left today.',
              style: AppTypography.bodySmall(color: AppColors.textMuted),
            )
          : Column(
              children: data.availableSlotsList.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.bgLavender,
                                  child: Text(
                                    item.avatarInitials,
                                    style: AppTypography.labelSmall(
                                      color: AppColors.lavDark,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.doctorName,
                                      style: AppTypography.labelMedium(
                                        color: AppColors.text,
                                      ),
                                    ),
                                    Text(
                                      '${item.specialty} · ${item.room}',
                                      style: AppTypography.bodySmall(
                                        color: AppColors.textMuted,
                                      ).copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgSage,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.sage.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '${item.availableSlotsCount} free slots',
                                style: AppTypography.labelSmall(
                                  color: AppColors.sageDark,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: item.slots.map((slot) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgLavender,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.borderLav),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 12,
                                    color: AppColors.lavDark,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    slot,
                                    style: AppTypography.labelSmall(
                                      color: AppColors.lavDark,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// 3. APPOINTMENT ANALYTICS WIDGETS

/// Bookings Over Time (Area Chart)
class BookingsOverTimeChart extends StatelessWidget {
  final AppointmentAnalyticsData data;

  const BookingsOverTimeChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Bookings Over Time',
      subtitle: 'Daily & weekly appointment volumes and completion cadence',
      icon: Icons.calendar_month_outlined,
      badgeText: 'Busiest: ${data.busiestDayOfWeek}',
      badgeColor: AppColors.rose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              _LegendItem(label: 'Total Booked', color: AppColors.rose),
              _LegendItem(label: 'Completed', color: AppColors.sage),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: AppColors.hairline, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 30,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: AppTypography.bodySmall(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final int index = value.toInt();
                        if (index >= 0 &&
                            index < data.bookingsOverTime.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data.bookingsOverTime[index].dateLabel,
                              style: AppTypography.labelSmall(
                                color: AppColors.textMuted,
                              ).copyWith(fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.bookingsOverTime
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.booked))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.rose,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.rose.withValues(alpha: 0.12),
                    ),
                  ),
                  LineChartBarData(
                    spots: data.bookingsOverTime
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.completed))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.sage,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.sage.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Completed, cancelled, no-show and rescheduled.
class AppointmentOutcomesDonut extends StatelessWidget {
  final AppointmentOutcomesData data;

  const AppointmentOutcomesDonut({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final int total =
        data.completed + data.cancelled + data.noShow + data.rescheduled;

    return _AnalyticsCard(
      title: 'Appointment Outcomes',
      subtitle: 'Fulfillment vs cancellation & no-show breakdown',
      icon: Icons.pie_chart_outline_rounded,
      badgeText: '${data.completedRate.toStringAsFixed(1)}% Completed',
      badgeColor: AppColors.sage,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 44,
                    sections: [
                      PieChartSectionData(
                        value: data.completed.toDouble(),
                        color: AppColors.sage,
                        radius: 20,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: data.rescheduled.toDouble(),
                        color: AppColors.lav,
                        radius: 20,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: data.cancelled.toDouble(),
                        color: AppColors.gold,
                        radius: 20,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: data.noShow.toDouble(),
                        color: AppColors.rose,
                        radius: 20,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: AppTypography.displayTitle(
                        color: AppColors.text,
                      ).copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Total Appts',
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ).copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildOutcomePill(
            label: 'Completed Sessions',
            count: data.completed,
            rate: data.completedRate,
            color: AppColors.sage,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 6),
          _buildOutcomePill(
            label: 'Rescheduled',
            count: data.rescheduled,
            rate: data.rescheduledRate,
            color: AppColors.lav,
            icon: Icons.update,
          ),
          const SizedBox(height: 6),
          _buildOutcomePill(
            label: 'Cancelled Ahead',
            count: data.cancelled,
            rate: data.cancelledRate,
            color: AppColors.gold,
            icon: Icons.cancel_outlined,
          ),
          const SizedBox(height: 6),
          _buildOutcomePill(
            label: 'No-Show Patients',
            count: data.noShow,
            rate: data.noShowRate,
            color: AppColors.rose,
            icon: Icons.person_off_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomePill({
    required String label,
    required int count,
    required double rate,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium(color: AppColors.text),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '$count',
                style: AppTypography.labelMedium(
                  color: AppColors.text,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
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

/// Peak Booking Times & Rescheduled Appointments Card
class PeakTimesAndRescheduledWidget extends StatelessWidget {
  final AppointmentAnalyticsData data;

  const PeakTimesAndRescheduledWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final int busiest = data.peakBookingTimes.fold<int>(
      0,
      (top, slot) => slot.bookingVolume > top ? slot.bookingVolume : top,
    );

    return _AnalyticsCard(
      title: 'Peak Booking Times & Reschedules',
      subtitle: 'Hourly demand distribution and reschedule impact',
      icon: Icons.access_time_rounded,
      badgeText: 'Peak: ${data.busiestTimeWindow}',
      badgeColor: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hourly Patient Influx',
            style: AppTypography.labelMedium(color: AppColors.text),
          ),
          const SizedBox(height: 14),

          // Hourly distribution bars
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.peakBookingTimes.map((slot) {
                // Scale against the busiest slot.
                final double factor = busiest == 0
                    ? 0.15
                    : (slot.bookingVolume / busiest).clamp(0.15, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${slot.bookingVolume}',
                          style:
                              AppTypography.bodySmall(
                                color: slot.isPeak
                                    ? AppColors.rose
                                    : AppColors.textMuted,
                              ).copyWith(
                                fontSize: 10,
                                fontWeight: slot.isPeak
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Tooltip(
                          message:
                              '${slot.timeSlot}: ${slot.bookingVolume} bookings',
                          child: Container(
                            height: 176 * factor,
                            decoration: BoxDecoration(
                              color: slot.isPeak
                                  ? AppColors.rose
                                  : AppColors.lav,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          slot.timeSlot,
                          style:
                              AppTypography.labelSmall(
                                color: slot.isPeak
                                    ? AppColors.roseDark
                                    : AppColors.textMuted,
                              ).copyWith(
                                fontSize: 9,
                                fontWeight: slot.isPeak
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                        ),
                      ],
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
}

// 4. PATIENT ANALYTICS WIDGETS

/// New vs Returning Patients Ratio & Growth
class NewVsReturningDonut extends StatelessWidget {
  final PatientRatioData data;

  const NewVsReturningDonut({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final int total = data.newPatients + data.returningPatients;

    return _AnalyticsCard(
      title: 'New vs Returning Patients',
      subtitle: 'First-time consultation clients vs recurring patients',
      icon: Icons.group_outlined,
      badgeText: '${data.returningPercentage.toStringAsFixed(0)}% Returning',
      badgeColor: AppColors.rose,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        value: data.returningPatients.toDouble(),
                        color: AppColors.rose,
                        radius: 18,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: data.newPatients.toDouble(),
                        color: AppColors.lav,
                        radius: 18,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: AppTypography.displayTitle(
                        color: AppColors.text,
                      ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Total Patients',
                      style: AppTypography.bodySmall(
                        color: AppColors.textMuted,
                      ).copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgRose,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderRose),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Returning Patients',
                        style: AppTypography.bodySmall(
                          color: AppColors.roseDark,
                        ).copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data.returningPatients}',
                        style: AppTypography.displayStat(
                          color: AppColors.text,
                        ).copyWith(fontSize: 18),
                      ),
                      Text(
                        '${data.returningPercentage.toStringAsFixed(1)}% of total',
                        style: AppTypography.labelSmall(
                          color: AppColors.rose,
                        ).copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgLavender,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLav),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Patients',
                        style: AppTypography.bodySmall(
                          color: AppColors.lavDark,
                        ).copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data.newPatients}',
                        style: AppTypography.displayStat(
                          color: AppColors.text,
                        ).copyWith(fontSize: 18),
                      ),
                      Text(
                        '${data.newPercentage.toStringAsFixed(1)}% of total',
                        style: AppTypography.labelSmall(
                          color: AppColors.lavDark,
                        ).copyWith(fontSize: 10),
                      ),
                    ],
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

/// Patient Growth Over Time Line Chart
class PatientGrowthLineChart extends StatelessWidget {
  final List<PatientGrowthPoint> data;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final String valueLabel;

  /// Plot height, tuned per dashboard row.
  final double plotHeight;

  const PatientGrowthLineChart({
    super.key,
    required this.data,
    this.title = 'Patient Growth',
    this.subtitle =
        'Cumulative patient database expansion over selected window',
    this.badgeText = '+12% Database Growth',
    this.badgeColor = AppColors.sage,
    this.valueLabel = 'Patients',
    this.plotHeight = 220,
  });


  @override
  Widget build(BuildContext context) {
    final double top = data.isEmpty
        ? 0
        : data
              .map((point) => point.totalCumulative)
              .reduce((a, b) => a > b ? a : b);
    final double step = _axisStep(top);

    return _AnalyticsCard(
      title: title,
      subtitle: subtitle,
      icon: Icons.trending_up_rounded,
      badgeText: badgeText,
      badgeColor: badgeColor,
      child: Column(
        children: [
          SizedBox(
            height: plotHeight,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: step,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: AppColors.hairline, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: step,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: AppTypography.bodySmall(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: data.length > 8
                          ? (data.length / 6).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        final int index = value.toInt();
                        final int labelInterval = data.length > 8
                            ? (data.length / 6).ceil()
                            : 1;
                        if (index >= 0 &&
                            index < data.length &&
                            (index % labelInterval == 0 ||
                                index == data.length - 1)) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[index].dateLabel,
                              style: AppTypography.labelSmall(
                                color: AppColors.textMuted,
                              ).copyWith(fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.text,
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    tooltipMargin: 12,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map(
                          (spot) => LineTooltipItem(
                            '${spot.y.toInt()} $valueLabel',
                            AppTypography.labelLarge(
                              color: AppColors.bgCard,
                            ).copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
                      .map(
                        (_) => TouchedSpotIndicatorData(
                          FlLine(color: AppColors.roseDark, strokeWidth: 3),
                          FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                                  radius: 7,
                                  color: AppColors.roseDark,
                                  strokeWidth: 3,
                                  strokeColor: AppColors.bgCard,
                                ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: data
                        .asMap()
                        .entries
                        .map(
                          (e) =>
                              FlSpot(e.key.toDouble(), e.value.totalCumulative),
                        )
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.roseDark,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.rose.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Patient Retention Rate & Loyalty Insights
class PatientRetentionCard extends StatelessWidget {
  final PatientRetentionData data;

  const PatientRetentionCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Patient Retention Rate',
      subtitle: 'Loyalty cohort return intervals and repeat booking rates',
      icon: Icons.workspace_premium_outlined,
      badgeText: data.retentionTrend,
      badgeColor: AppColors.sage,
      child: Column(
        children: [
          Row(
            children: [
              // Circular progress gauge
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgRose,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderRose, width: 2),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${data.retentionRate}%',
                        style: AppTypography.displayTitle(
                          color: AppColors.roseDark,
                        ).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Retention',
                        style: AppTypography.bodySmall(
                          color: AppColors.textSub,
                        ).copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRetentionMetric(
                      label: 'Avg Return Interval',
                      value: '${data.averageReturnDays} days',
                      icon: Icons.repeat_rounded,
                      color: AppColors.rose,
                    ),
                    const SizedBox(height: 10),
                    _buildRetentionMetric(
                      label: 'Repeat Treatment Rate',
                      value: '${data.repeatBookingRate}%',
                      icon: Icons.auto_awesome_rounded,
                      color: AppColors.sage,
                    ),
                    const SizedBox(height: 10),
                    _buildRetentionMetric(
                      label: 'Active Loyalty Members',
                      value: '${data.activeLoyaltyMembers} clients',
                      icon: Icons.star_border_rounded,
                      color: AppColors.gold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall(
              color: AppColors.textSub,
            ).copyWith(fontSize: 12),
          ),
        ),
        Text(
          value,
          style: AppTypography.labelMedium(
            color: AppColors.text,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// BASE ANALYTICS CONTAINER CARD & HELPERS

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badgeText;
  final Color? badgeColor;
  final Widget child;

  const _AnalyticsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badgeText,
    this.badgeColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveBadgeColor = badgeColor ?? AppColors.rose;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bgRose,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: AppColors.rose),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.labelLarge(
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: AppTypography.bodySmall(
                              color: AppColors.textMuted,
                            ).copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: effectiveBadgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: effectiveBadgeColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: AppTypography.labelSmall(
                      color: effectiveBadgeColor,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.bodySmall(
            color: AppColors.textSub,
          ).copyWith(fontSize: 11),
        ),
      ],
    );
  }
}
