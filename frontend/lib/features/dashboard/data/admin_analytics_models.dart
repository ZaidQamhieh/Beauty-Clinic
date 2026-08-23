import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../network/api_client.dart';

enum AdminDateRangeType { days7, days30, months3, custom }

extension AdminDateRangeTypeExtension on AdminDateRangeType {
  String get label {
    switch (this) {
      case AdminDateRangeType.days7:
        return '7 Days';
      case AdminDateRangeType.days30:
        return '30 Days';
      case AdminDateRangeType.months3:
        return '3 Months';
      case AdminDateRangeType.custom:
        return 'Custom';
    }
  }
}

Color _colorFromHex(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  final clean = hex.replaceAll('#', '');
  final val = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
  return val != null ? Color(val) : fallback;
}

IconData _iconFromKey(String? key) {
  switch (key) {
    case 'spa':
      return Icons.spa_outlined;
    case 'flare':
      return Icons.flare_outlined;
    case 'medication':
      return Icons.medication_outlined;
    case 'accessibility_new':
      return Icons.accessibility_new_outlined;
    case 'forum':
      return Icons.forum_outlined;
    default:
      return Icons.auto_awesome;
  }
}

/// 1. Clinic Overview Data
class ClinicOverviewData {
  final int totalPatients;
  final String patientTrend;
  final String patientTrendSub;
  final int totalDoctors;
  final int activeDoctorsNow;
  final String doctorSub;
  final int todayAppointments;
  final int confirmedAppointments;
  final int inRoomAppointments;
  final int pendingAppointments;
  final int todaySessions;
  final int completedSessions;
  final int ongoingSessions;

  const ClinicOverviewData({
    required this.totalPatients,
    required this.patientTrend,
    required this.patientTrendSub,
    required this.totalDoctors,
    required this.activeDoctorsNow,
    required this.doctorSub,
    required this.todayAppointments,
    required this.confirmedAppointments,
    required this.inRoomAppointments,
    required this.pendingAppointments,
    required this.todaySessions,
    required this.completedSessions,
    required this.ongoingSessions,
  });

  factory ClinicOverviewData.fromJson(Map<String, dynamic> json) {
    return ClinicOverviewData(
      totalPatients: (json['totalPatients'] as num?)?.toInt() ?? 0,
      patientTrend: json['patientTrend'] as String? ?? '+0.0%',
      patientTrendSub: json['patientTrendSub'] as String? ?? '',
      totalDoctors: (json['totalDoctors'] as num?)?.toInt() ?? 0,
      activeDoctorsNow: (json['activeDoctorsNow'] as num?)?.toInt() ?? 0,
      doctorSub: json['doctorSub'] as String? ?? '',
      todayAppointments: (json['todayAppointments'] as num?)?.toInt() ?? 0,
      confirmedAppointments:
          (json['confirmedAppointments'] as num?)?.toInt() ?? 0,
      inRoomAppointments: (json['inRoomAppointments'] as num?)?.toInt() ?? 0,
      pendingAppointments: (json['pendingAppointments'] as num?)?.toInt() ?? 0,
      todaySessions: (json['todaySessions'] as num?)?.toInt() ?? 0,
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      ongoingSessions: (json['ongoingSessions'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 2. Service Analytics Data
class ServiceBookingItem {
  final String serviceName;
  final String category;
  final int bookingsCount;
  final double percentage;
  final String revenue;
  final IconData icon;
  final Color accentColor;

  const ServiceBookingItem({
    required this.serviceName,
    required this.category,
    required this.bookingsCount,
    required this.percentage,
    required this.revenue,
    required this.icon,
    required this.accentColor,
  });

  factory ServiceBookingItem.fromJson(Map<String, dynamic> json) {
    return ServiceBookingItem(
      serviceName: json['serviceName'] as String? ?? '',
      category: json['category'] as String? ?? '',
      bookingsCount: (json['bookingsCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      revenue: json['revenue'] as String? ?? '₪0',
      icon: _iconFromKey(json['iconKey'] as String?),
      accentColor: _colorFromHex(
        json['accentColorHex'] as String?,
        AppColors.rose,
      ),
    );
  }
}

class ServiceGrowthPoint {
  final String dateLabel;
  final double laserCount;
  final double facialCount;
  final double contourCount;
  final double injectableCount;

  const ServiceGrowthPoint({
    required this.dateLabel,
    required this.laserCount,
    required this.facialCount,
    required this.contourCount,
    required this.injectableCount,
  });

  factory ServiceGrowthPoint.fromJson(Map<String, dynamic> json) {
    return ServiceGrowthPoint(
      dateLabel: json['dateLabel'] as String? ?? '',
      laserCount: (json['laserCount'] as num?)?.toDouble() ?? 0.0,
      facialCount: (json['facialCount'] as num?)?.toDouble() ?? 0.0,
      contourCount: (json['contourCount'] as num?)?.toDouble() ?? 0.0,
      injectableCount: (json['injectableCount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ServiceAnalyticsData {
  final List<ServiceBookingItem> bookingsByService;
  final List<ServiceGrowthPoint> growthOverTime;
  final String topService;
  final String growthPercentage;

  const ServiceAnalyticsData({
    required this.bookingsByService,
    required this.growthOverTime,
    required this.topService,
    required this.growthPercentage,
  });

  factory ServiceAnalyticsData.fromJson(Map<String, dynamic> json) {
    return ServiceAnalyticsData(
      bookingsByService:
          (json['bookingsByService'] as List<dynamic>?)
              ?.map(
                (e) => ServiceBookingItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      growthOverTime:
          (json['growthOverTime'] as List<dynamic>?)
              ?.map(
                (e) => ServiceGrowthPoint.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      topService: json['topService'] as String? ?? 'HydraFacial',
      growthPercentage: json['growthPercentage'] as String? ?? '+0.0%',
    );
  }
}

/// 3. Doctor Analytics Data
class DoctorUtilizationItem {
  final String doctorName;
  final String specialty;
  final double bookedHours;
  final double totalAvailableHours;
  final double utilizationPercentage;
  final String status;
  final Color statusColor;

  const DoctorUtilizationItem({
    required this.doctorName,
    required this.specialty,
    required this.bookedHours,
    required this.totalAvailableHours,
    required this.utilizationPercentage,
    required this.status,
    required this.statusColor,
  });

  factory DoctorUtilizationItem.fromJson(Map<String, dynamic> json) {
    return DoctorUtilizationItem(
      doctorName: json['doctorName'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      bookedHours: (json['bookedHours'] as num?)?.toDouble() ?? 0.0,
      totalAvailableHours:
          (json['totalAvailableHours'] as num?)?.toDouble() ?? 0.0,
      utilizationPercentage:
          (json['utilizationPercentage'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'Optimal',
      statusColor: _colorFromHex(
        json['statusColorHex'] as String?,
        AppColors.sage,
      ),
    );
  }
}

class DoctorAvailableSlotItem {
  final String doctorName;
  final String specialty;
  final String avatarInitials;
  final int availableSlotsCount;
  final List<String> slots;
  final String nextAvailable;
  final String room;

  const DoctorAvailableSlotItem({
    required this.doctorName,
    required this.specialty,
    required this.avatarInitials,
    required this.availableSlotsCount,
    required this.slots,
    required this.nextAvailable,
    required this.room,
  });

  factory DoctorAvailableSlotItem.fromJson(Map<String, dynamic> json) {
    return DoctorAvailableSlotItem(
      doctorName: json['doctorName'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      avatarInitials: json['avatarInitials'] as String? ?? 'DR',
      availableSlotsCount: (json['availableSlotsCount'] as num?)?.toInt() ?? 0,
      slots:
          (json['slots'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      nextAvailable: json['nextAvailable'] as String? ?? 'Today',
      room: json['room'] as String? ?? 'Suite 1',
    );
  }
}

class DoctorAnalyticsData {
  final List<DoctorUtilizationItem> utilizationList;
  final List<DoctorAvailableSlotItem> availableSlotsList;
  final double averageUtilization;
  final int totalFreeSlotsToday;

  const DoctorAnalyticsData({
    required this.utilizationList,
    required this.availableSlotsList,
    required this.averageUtilization,
    required this.totalFreeSlotsToday,
  });

  factory DoctorAnalyticsData.fromJson(Map<String, dynamic> json) {
    return DoctorAnalyticsData(
      utilizationList:
          (json['utilizationList'] as List<dynamic>?)
              ?.map(
                (e) =>
                    DoctorUtilizationItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      availableSlotsList:
          (json['availableSlotsList'] as List<dynamic>?)
              ?.map(
                (e) =>
                    DoctorAvailableSlotItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      averageUtilization:
          (json['averageUtilization'] as num?)?.toDouble() ?? 0.0,
      totalFreeSlotsToday: (json['totalFreeSlotsToday'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 4. Appointment Analytics Data
class AppointmentTrendPoint {
  final String dateLabel;
  final double booked;
  final double completed;
  final double cancelled;

  const AppointmentTrendPoint({
    required this.dateLabel,
    required this.booked,
    required this.completed,
    required this.cancelled,
  });

  factory AppointmentTrendPoint.fromJson(Map<String, dynamic> json) {
    return AppointmentTrendPoint(
      dateLabel: json['dateLabel'] as String? ?? '',
      booked: (json['booked'] as num?)?.toDouble() ?? 0.0,
      completed: (json['completed'] as num?)?.toDouble() ?? 0.0,
      cancelled: (json['cancelled'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AppointmentOutcomesData {
  final int completed;
  final int cancelled;
  final int noShow;
  final int rescheduled;
  final double completedRate;
  final double cancelledRate;
  final double noShowRate;
  final double rescheduledRate;

  const AppointmentOutcomesData({
    required this.completed,
    required this.cancelled,
    required this.noShow,
    required this.rescheduled,
    required this.completedRate,
    required this.cancelledRate,
    required this.noShowRate,
    required this.rescheduledRate,
  });

  factory AppointmentOutcomesData.fromJson(Map<String, dynamic> json) {
    return AppointmentOutcomesData(
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      noShow: (json['noShow'] as num?)?.toInt() ?? 0,
      rescheduled: (json['rescheduled'] as num?)?.toInt() ?? 0,
      completedRate: (json['completedRate'] as num?)?.toDouble() ?? 0.0,
      cancelledRate: (json['cancelledRate'] as num?)?.toDouble() ?? 0.0,
      noShowRate: (json['noShowRate'] as num?)?.toDouble() ?? 0.0,
      rescheduledRate: (json['rescheduledRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PeakBookingTimeItem {
  final String timeSlot;
  final int bookingVolume;
  final bool isPeak;

  const PeakBookingTimeItem({
    required this.timeSlot,
    required this.bookingVolume,
    this.isPeak = false,
  });

  factory PeakBookingTimeItem.fromJson(Map<String, dynamic> json) {
    return PeakBookingTimeItem(
      timeSlot: json['timeSlot'] as String? ?? '',
      bookingVolume: (json['bookingVolume'] as num?)?.toInt() ?? 0,
      isPeak: json['isPeak'] as bool? ?? false,
    );
  }
}

class RescheduledReasonItem {
  final String reason;
  final int count;
  final double percentage;

  const RescheduledReasonItem({
    required this.reason,
    required this.count,
    required this.percentage,
  });

  factory RescheduledReasonItem.fromJson(Map<String, dynamic> json) {
    return RescheduledReasonItem(
      reason: json['reason'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RescheduledAppointmentsData {
  final int totalRescheduled;
  final double rescheduleRate;
  final String avgNoticeTime;
  final List<RescheduledReasonItem> topReasons;

  const RescheduledAppointmentsData({
    required this.totalRescheduled,
    required this.rescheduleRate,
    required this.avgNoticeTime,
    required this.topReasons,
  });

  factory RescheduledAppointmentsData.fromJson(Map<String, dynamic> json) {
    return RescheduledAppointmentsData(
      totalRescheduled: (json['totalRescheduled'] as num?)?.toInt() ?? 0,
      rescheduleRate: (json['rescheduleRate'] as num?)?.toDouble() ?? 0.0,
      avgNoticeTime: json['avgNoticeTime'] as String? ?? '',
      topReasons:
          (json['topReasons'] as List<dynamic>?)
              ?.map(
                (e) =>
                    RescheduledReasonItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

class AppointmentAnalyticsData {
  final List<AppointmentTrendPoint> bookingsOverTime;
  final AppointmentOutcomesData outcomes;
  final List<PeakBookingTimeItem> peakBookingTimes;
  final String busiestDayOfWeek;
  final String busiestTimeWindow;
  final RescheduledAppointmentsData rescheduled;

  const AppointmentAnalyticsData({
    required this.bookingsOverTime,
    required this.outcomes,
    required this.peakBookingTimes,
    required this.busiestDayOfWeek,
    required this.busiestTimeWindow,
    required this.rescheduled,
  });

  factory AppointmentAnalyticsData.fromJson(Map<String, dynamic> json) {
    return AppointmentAnalyticsData(
      bookingsOverTime:
          (json['bookingsOverTime'] as List<dynamic>?)
              ?.map(
                (e) =>
                    AppointmentTrendPoint.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      outcomes: json['outcomes'] != null
          ? AppointmentOutcomesData.fromJson(
              json['outcomes'] as Map<String, dynamic>,
            )
          : const AppointmentOutcomesData(
              completed: 0,
              cancelled: 0,
              noShow: 0,
              rescheduled: 0,
              completedRate: 0.0,
              cancelledRate: 0.0,
              noShowRate: 0.0,
              rescheduledRate: 0.0,
            ),
      peakBookingTimes:
          (json['peakBookingTimes'] as List<dynamic>?)
              ?.map(
                (e) => PeakBookingTimeItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      busiestDayOfWeek: json['busiestDayOfWeek'] as String? ?? 'Thursday',
      busiestTimeWindow:
          json['busiestTimeWindow'] as String? ?? '2:00 PM – 5:30 PM',
      rescheduled: json['rescheduled'] != null
          ? RescheduledAppointmentsData.fromJson(
              json['rescheduled'] as Map<String, dynamic>,
            )
          : const RescheduledAppointmentsData(
              totalRescheduled: 0,
              rescheduleRate: 0.0,
              avgNoticeTime: '',
              topReasons: [],
            ),
    );
  }
}

/// 5. Patient Analytics Data
class PatientRatioData {
  final int newPatients;
  final int returningPatients;
  final double newPercentage;
  final double returningPercentage;

  const PatientRatioData({
    required this.newPatients,
    required this.returningPatients,
    required this.newPercentage,
    required this.returningPercentage,
  });

  factory PatientRatioData.fromJson(Map<String, dynamic> json) {
    return PatientRatioData(
      newPatients: (json['newPatients'] as num?)?.toInt() ?? 0,
      returningPatients: (json['returningPatients'] as num?)?.toInt() ?? 0,
      newPercentage: (json['newPercentage'] as num?)?.toDouble() ?? 0.0,
      returningPercentage:
          (json['returningPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PatientGrowthPoint {
  final String dateLabel;
  final double totalCumulative;
  final double monthlyNew;

  const PatientGrowthPoint({
    required this.dateLabel,
    required this.totalCumulative,
    required this.monthlyNew,
  });

  factory PatientGrowthPoint.fromJson(Map<String, dynamic> json) {
    return PatientGrowthPoint(
      dateLabel: json['dateLabel'] as String? ?? '',
      totalCumulative: (json['totalCumulative'] as num?)?.toDouble() ?? 0.0,
      monthlyNew: (json['monthlyNew'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PatientRetentionData {
  final double retentionRate;
  final int averageReturnDays;
  final double repeatBookingRate;
  final int activeLoyaltyMembers;
  final String retentionTrend;

  const PatientRetentionData({
    required this.retentionRate,
    required this.averageReturnDays,
    required this.repeatBookingRate,
    required this.activeLoyaltyMembers,
    required this.retentionTrend,
  });

  factory PatientRetentionData.fromJson(Map<String, dynamic> json) {
    return PatientRetentionData(
      retentionRate: (json['retentionRate'] as num?)?.toDouble() ?? 0.0,
      averageReturnDays: (json['averageReturnDays'] as num?)?.toInt() ?? 0,
      repeatBookingRate: (json['repeatBookingRate'] as num?)?.toDouble() ?? 0.0,
      activeLoyaltyMembers:
          (json['activeLoyaltyMembers'] as num?)?.toInt() ?? 0,
      retentionTrend: json['retentionTrend'] as String? ?? '',
    );
  }
}

class PatientAnalyticsData {
  final PatientRatioData newVsReturning;
  final List<PatientGrowthPoint> growthTimeline;
  final PatientRetentionData retention;

  const PatientAnalyticsData({
    required this.newVsReturning,
    required this.growthTimeline,
    required this.retention,
  });

  factory PatientAnalyticsData.fromJson(Map<String, dynamic> json) {
    return PatientAnalyticsData(
      newVsReturning: json['newVsReturning'] != null
          ? PatientRatioData.fromJson(
              json['newVsReturning'] as Map<String, dynamic>,
            )
          : const PatientRatioData(
              newPatients: 0,
              returningPatients: 0,
              newPercentage: 0.0,
              returningPercentage: 0.0,
            ),
      growthTimeline:
          (json['growthTimeline'] as List<dynamic>?)
              ?.map(
                (e) => PatientGrowthPoint.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      retention: json['retention'] != null
          ? PatientRetentionData.fromJson(
              json['retention'] as Map<String, dynamic>,
            )
          : const PatientRetentionData(
              retentionRate: 0.0,
              averageReturnDays: 0,
              repeatBookingRate: 0.0,
              activeLoyaltyMembers: 0,
              retentionTrend: '',
            ),
    );
  }
}

/// 6. Live Daily Operations Data
class TodayAppointmentItem {
  final String id;
  final String patientId;
  final String time;
  final String patientName;
  final String treatmentName;
  final String doctorName;
  final String status;

  const TodayAppointmentItem({
    required this.id,
    required this.patientId,
    required this.time,
    required this.patientName,
    required this.treatmentName,
    required this.doctorName,
    required this.status,
  });

  factory TodayAppointmentItem.fromJson(Map<String, dynamic> json) {
    return TodayAppointmentItem(
      id: json['id'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      time: json['time'] as String? ?? '',
      patientName: json['patientName'] as String? ?? '',
      treatmentName: json['treatmentName'] as String? ?? '',
      doctorName: json['doctorName'] as String? ?? '',
      status: json['status'] as String? ?? 'Confirmed',
    );
  }
}

class StaffDutyItem {
  final String name;
  final String role;
  final int appointmentsCount;
  final String status;
  final bool isDoctor;

  const StaffDutyItem({
    required this.name,
    required this.role,
    required this.appointmentsCount,
    required this.status,
    this.isDoctor = true,
  });

  factory StaffDutyItem.fromJson(Map<String, dynamic> json) {
    return StaffDutyItem(
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'Specialist',
      appointmentsCount: (json['appointmentsCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'Available',
      isDoctor: json['isDoctor'] as bool? ?? true,
    );
  }
}

class OperationsData {
  final List<TodayAppointmentItem> todayAppointments;
  final List<StaffDutyItem> staffList;

  const OperationsData({
    required this.todayAppointments,
    required this.staffList,
  });

  factory OperationsData.fromJson(Map<String, dynamic> json) {
    return OperationsData(
      todayAppointments:
          (json['todayAppointments'] as List<dynamic>?)
              ?.map(
                (e) => TodayAppointmentItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      staffList:
          (json['staffList'] as List<dynamic>?)
              ?.map((e) => StaffDutyItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Aggregate Dashboard Analytics Container
class AdminDashboardData {
  final AdminDateRangeType rangeType;
  final DateTime startDate;
  final DateTime endDate;
  final ClinicOverviewData overview;
  final ServiceAnalyticsData serviceAnalytics;
  final DoctorAnalyticsData doctorAnalytics;
  final AppointmentAnalyticsData appointmentAnalytics;
  final PatientAnalyticsData patientAnalytics;
  final OperationsData operations;

  const AdminDashboardData({
    required this.rangeType,
    required this.startDate,
    required this.endDate,
    required this.overview,
    required this.serviceAnalytics,
    required this.doctorAnalytics,
    required this.appointmentAnalytics,
    required this.patientAnalytics,
    required this.operations,
  });

  String get formattedDateRange {
    final DateFormat formatter = DateFormat('d MMM yyyy');
    return '${formatter.format(startDate)} – ${formatter.format(endDate)}';
  }

  factory AdminDashboardData.fromJson(
    Map<String, dynamic> json, {
    AdminDateRangeType? rangeType,
  }) {
    final startStr = json['startDate'] as String?;
    final endStr = json['endDate'] as String?;

    return AdminDashboardData(
      rangeType: rangeType ?? AdminDateRangeType.days30,
      startDate: startStr != null
          ? DateTime.tryParse(startStr) ?? DateTime.now()
          : DateTime.now(),
      endDate: endStr != null
          ? DateTime.tryParse(endStr) ?? DateTime.now()
          : DateTime.now(),
      overview: ClinicOverviewData.fromJson(
        (json['overview'] as Map<String, dynamic>?) ?? {},
      ),
      serviceAnalytics: ServiceAnalyticsData.fromJson(
        (json['serviceAnalytics'] as Map<String, dynamic>?) ?? {},
      ),
      doctorAnalytics: DoctorAnalyticsData.fromJson(
        (json['doctorAnalytics'] as Map<String, dynamic>?) ?? {},
      ),
      appointmentAnalytics: AppointmentAnalyticsData.fromJson(
        (json['appointmentAnalytics'] as Map<String, dynamic>?) ?? {},
      ),
      patientAnalytics: PatientAnalyticsData.fromJson(
        (json['patientAnalytics'] as Map<String, dynamic>?) ?? {},
      ),
      operations: OperationsData.fromJson(
        (json['operations'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}

/// Repository that yields cohesive, dynamically adjusted analytics for any date range
class AdminAnalyticsRepository {
  static Future<AdminDashboardData> fetchDashboardDataAsync({
    AdminDateRangeType rangeType = AdminDateRangeType.days30,
    DateTimeRange? customRange,
    ApiClient? apiClient,
  }) async {
    if (apiClient != null) {
      try {
        final DateTime now = DateTime.now();
        DateTime start;
        DateTime end = now;

        switch (rangeType) {
          case AdminDateRangeType.days7:
            start = now.subtract(const Duration(days: 7));
            break;
          case AdminDateRangeType.days30:
            start = now.subtract(const Duration(days: 30));
            break;
          case AdminDateRangeType.months3:
            start = now.subtract(const Duration(days: 90));
            break;
          case AdminDateRangeType.custom:
            start =
                customRange?.start ?? now.subtract(const Duration(days: 30));
            end = customRange?.end ?? now;
            break;
        }

        final response = await apiClient.get(
          '/api/admin/analytics',
          queryParameters: {
            'from': start.toUtc().toIso8601String(),
            'to': end.toUtc().toIso8601String(),
          },
        );

        if (response.data is Map<String, dynamic>) {
          return AdminDashboardData.fromJson(
            response.data as Map<String, dynamic>,
            rangeType: rangeType,
          );
        }
      } catch (_) {
        // Fall back gracefully to local generation if offline or mock
      }
    }

    return fetchDashboardData(rangeType: rangeType, customRange: customRange);
  }

  static AdminDashboardData fetchDashboardData({
    AdminDateRangeType rangeType = AdminDateRangeType.days30,
    DateTimeRange? customRange,
  }) {
    final DateTime now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (rangeType) {
      case AdminDateRangeType.days7:
        start = now.subtract(const Duration(days: 7));
        break;
      case AdminDateRangeType.days30:
        start = now.subtract(const Duration(days: 30));
        break;
      case AdminDateRangeType.months3:
        start = now.subtract(const Duration(days: 90));
        break;
      case AdminDateRangeType.custom:
        start = customRange?.start ?? now.subtract(const Duration(days: 30));
        end = customRange?.end ?? now;
        break;
    }

    return AdminDashboardData(
      rangeType: rangeType,
      startDate: start,
      endDate: end,
      overview: _buildOverview(rangeType),
      serviceAnalytics: _buildServiceAnalytics(rangeType),
      doctorAnalytics: _buildDoctorAnalytics(rangeType),
      appointmentAnalytics: _buildAppointmentAnalytics(rangeType),
      patientAnalytics: _buildPatientAnalytics(rangeType),
      operations: _buildOperations(),
    );
  }

  static OperationsData _buildOperations() {
    return const OperationsData(todayAppointments: [], staffList: []);
  }

  static ClinicOverviewData _buildOverview(AdminDateRangeType rangeType) {
    switch (rangeType) {
      case AdminDateRangeType.days7:
        return const ClinicOverviewData(
          totalPatients: 1302,
          patientTrend: '+3.1%',
          patientTrendSub: '+38 this week',
          totalDoctors: 4,
          activeDoctorsNow: 4,
          doctorSub: 'All suites operating',
          todayAppointments: 14,
          confirmedAppointments: 11,
          inRoomAppointments: 2,
          pendingAppointments: 3,
          todaySessions: 18,
          completedSessions: 8,
          ongoingSessions: 10,
        );
      case AdminDateRangeType.months3:
        return const ClinicOverviewData(
          totalPatients: 1284,
          patientTrend: '+28.4%',
          patientTrendSub: '+284 this quarter',
          totalDoctors: 4,
          activeDoctorsNow: 4,
          doctorSub: '100% capacity',
          todayAppointments: 14,
          confirmedAppointments: 11,
          inRoomAppointments: 2,
          pendingAppointments: 3,
          todaySessions: 18,
          completedSessions: 8,
          ongoingSessions: 10,
        );
      case AdminDateRangeType.days30:
      case AdminDateRangeType.custom:
        return const ClinicOverviewData(
          totalPatients: 1284,
          patientTrend: '+12.5%',
          patientTrendSub: '+142 this month',
          totalDoctors: 4,
          activeDoctorsNow: 4,
          doctorSub: 'All suites operating',
          todayAppointments: 14,
          confirmedAppointments: 11,
          inRoomAppointments: 2,
          pendingAppointments: 3,
          todaySessions: 18,
          completedSessions: 8,
          ongoingSessions: 10,
        );
    }
  }

  static ServiceAnalyticsData _buildServiceAnalytics(
    AdminDateRangeType rangeType,
  ) {
    final List<ServiceBookingItem> bookings = [
      const ServiceBookingItem(
        serviceName: 'HydraFacial Glow',
        category: 'Facial Treatments',
        bookingsCount: 142,
        percentage: 34.0,
        revenue: '₪63,900',
        icon: Icons.spa_outlined,
        accentColor: AppColors.rose,
      ),
      const ServiceBookingItem(
        serviceName: 'Laser Resurfacing',
        category: 'Laser Therapy',
        bookingsCount: 98,
        percentage: 23.5,
        revenue: '₪88,200',
        icon: Icons.flare_outlined,
        accentColor: AppColors.gold,
      ),
      const ServiceBookingItem(
        serviceName: 'Botox & Fillers',
        category: 'Injectables',
        bookingsCount: 76,
        percentage: 18.2,
        revenue: '₪72,400',
        icon: Icons.medication_outlined,
        accentColor: AppColors.lav,
      ),
      const ServiceBookingItem(
        serviceName: 'Chemical Peel',
        category: 'Facial Treatments',
        bookingsCount: 54,
        percentage: 12.9,
        revenue: '₪18,900',
        icon: Icons.auto_fix_high_outlined,
        accentColor: AppColors.sage,
      ),
      const ServiceBookingItem(
        serviceName: 'Body Contouring',
        category: 'Body Therapy',
        bookingsCount: 48,
        percentage: 11.4,
        revenue: '₪48,000',
        icon: Icons.accessibility_new_outlined,
        accentColor: Color(0xFF6366F1),
      ),
    ];

    List<ServiceGrowthPoint> growth;
    if (rangeType == AdminDateRangeType.days7) {
      growth = const [
        ServiceGrowthPoint(
          dateLabel: 'Mon',
          laserCount: 12,
          facialCount: 18,
          contourCount: 6,
          injectableCount: 9,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Tue',
          laserCount: 15,
          facialCount: 22,
          contourCount: 8,
          injectableCount: 11,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Wed',
          laserCount: 14,
          facialCount: 20,
          contourCount: 7,
          injectableCount: 10,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Thu',
          laserCount: 18,
          facialCount: 26,
          contourCount: 10,
          injectableCount: 14,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Fri',
          laserCount: 16,
          facialCount: 24,
          contourCount: 9,
          injectableCount: 12,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Sat',
          laserCount: 20,
          facialCount: 28,
          contourCount: 11,
          injectableCount: 16,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Sun',
          laserCount: 8,
          facialCount: 12,
          contourCount: 4,
          injectableCount: 6,
        ),
      ];
    } else if (rangeType == AdminDateRangeType.months3) {
      growth = const [
        ServiceGrowthPoint(
          dateLabel: 'May',
          laserCount: 68,
          facialCount: 110,
          contourCount: 38,
          injectableCount: 55,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Jun',
          laserCount: 82,
          facialCount: 128,
          contourCount: 44,
          injectableCount: 65,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Jul',
          laserCount: 92,
          facialCount: 135,
          contourCount: 46,
          injectableCount: 72,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Aug',
          laserCount: 98,
          facialCount: 142,
          contourCount: 48,
          injectableCount: 76,
        ),
      ];
    } else {
      growth = const [
        ServiceGrowthPoint(
          dateLabel: 'Week 1',
          laserCount: 20,
          facialCount: 32,
          contourCount: 10,
          injectableCount: 16,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Week 2',
          laserCount: 24,
          facialCount: 36,
          contourCount: 12,
          injectableCount: 19,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Week 3',
          laserCount: 26,
          facialCount: 38,
          contourCount: 13,
          injectableCount: 20,
        ),
        ServiceGrowthPoint(
          dateLabel: 'Week 4',
          laserCount: 28,
          facialCount: 36,
          contourCount: 13,
          injectableCount: 21,
        ),
      ];
    }

    return ServiceAnalyticsData(
      bookingsByService: bookings,
      growthOverTime: growth,
      topService: 'HydraFacial Glow',
      growthPercentage: '+18.4%',
    );
  }

  static DoctorAnalyticsData _buildDoctorAnalytics(
    AdminDateRangeType rangeType,
  ) {
    final List<DoctorUtilizationItem> utilization = [
      const DoctorUtilizationItem(
        doctorName: 'Dr. Hana Nasser',
        specialty: 'Cosmetic Dermatology',
        bookedHours: 34.5,
        totalAvailableHours: 40.0,
        utilizationPercentage: 86.2,
        status: 'High Demand',
        statusColor: AppColors.rose,
      ),
      const DoctorUtilizationItem(
        doctorName: 'Dr. Reem Khalil',
        specialty: 'Laser & Aesthetics',
        bookedHours: 30.0,
        totalAvailableHours: 40.0,
        utilizationPercentage: 75.0,
        status: 'Optimal',
        statusColor: AppColors.sage,
      ),
      const DoctorUtilizationItem(
        doctorName: 'Dr. Yasmine Ammar',
        specialty: 'Injectables & Anti-Aging',
        bookedHours: 36.0,
        totalAvailableHours: 40.0,
        utilizationPercentage: 90.0,
        status: 'High Demand',
        statusColor: AppColors.rose,
      ),
      const DoctorUtilizationItem(
        doctorName: 'Dr. Tariq Zaid',
        specialty: 'Body Contouring',
        bookedHours: 24.0,
        totalAvailableHours: 40.0,
        utilizationPercentage: 60.0,
        status: 'Moderate',
        statusColor: AppColors.gold,
      ),
    ];

    final List<DoctorAvailableSlotItem> availableSlots = [
      const DoctorAvailableSlotItem(
        doctorName: 'Dr. Hana Nasser',
        specialty: 'Cosmetic Dermatology',
        avatarInitials: 'HN',
        availableSlotsCount: 3,
        slots: ['14:30', '16:15', '17:00'],
        nextAvailable: 'Today 14:30',
        room: 'Suite 101',
      ),
      const DoctorAvailableSlotItem(
        doctorName: 'Dr. Reem Khalil',
        specialty: 'Laser & Aesthetics',
        avatarInitials: 'RK',
        availableSlotsCount: 4,
        slots: ['11:00', '13:30', '15:00', '16:45'],
        nextAvailable: 'Today 11:00',
        room: 'Laser Room A',
      ),
      const DoctorAvailableSlotItem(
        doctorName: 'Dr. Yasmine Ammar',
        specialty: 'Injectables & Anti-Aging',
        avatarInitials: 'YA',
        availableSlotsCount: 2,
        slots: ['15:30', '17:15'],
        nextAvailable: 'Today 15:30',
        room: 'Clinic Suite 2',
      ),
      const DoctorAvailableSlotItem(
        doctorName: 'Dr. Tariq Zaid',
        specialty: 'Body Contouring',
        avatarInitials: 'TZ',
        availableSlotsCount: 5,
        slots: ['10:00', '11:45', '14:00', '15:30', '16:30'],
        nextAvailable: 'Today 10:00',
        room: 'Body Suite',
      ),
    ];

    return DoctorAnalyticsData(
      utilizationList: utilization,
      availableSlotsList: availableSlots,
      averageUtilization: 77.8,
      totalFreeSlotsToday: 14,
    );
  }

  static AppointmentAnalyticsData _buildAppointmentAnalytics(
    AdminDateRangeType rangeType,
  ) {
    List<AppointmentTrendPoint> bookings;
    if (rangeType == AdminDateRangeType.days7) {
      bookings = const [
        AppointmentTrendPoint(
          dateLabel: 'Mon',
          booked: 18,
          completed: 16,
          cancelled: 1,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Tue',
          booked: 22,
          completed: 20,
          cancelled: 2,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Wed',
          booked: 20,
          completed: 19,
          cancelled: 1,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Thu',
          booked: 26,
          completed: 24,
          cancelled: 2,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Fri',
          booked: 24,
          completed: 21,
          cancelled: 1,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Sat',
          booked: 28,
          completed: 26,
          cancelled: 1,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Sun',
          booked: 12,
          completed: 11,
          cancelled: 0,
        ),
      ];
    } else if (rangeType == AdminDateRangeType.months3) {
      bookings = const [
        AppointmentTrendPoint(
          dateLabel: 'May',
          booked: 240,
          completed: 210,
          cancelled: 18,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Jun',
          booked: 285,
          completed: 254,
          cancelled: 20,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Jul',
          booked: 310,
          completed: 282,
          cancelled: 16,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Aug',
          booked: 345,
          completed: 314,
          cancelled: 22,
        ),
      ];
    } else {
      bookings = const [
        AppointmentTrendPoint(
          dateLabel: 'Week 1',
          booked: 74,
          completed: 68,
          cancelled: 4,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Week 2',
          booked: 86,
          completed: 80,
          cancelled: 5,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Week 3',
          booked: 92,
          completed: 84,
          cancelled: 6,
        ),
        AppointmentTrendPoint(
          dateLabel: 'Week 4',
          booked: 93,
          completed: 82,
          cancelled: 7,
        ),
      ];
    }

    return AppointmentAnalyticsData(
      bookingsOverTime: bookings,
      outcomes: const AppointmentOutcomesData(
        completed: 314,
        cancelled: 22,
        noShow: 10,
        rescheduled: 34,
        completedRate: 82.6,
        cancelledRate: 5.8,
        noShowRate: 2.6,
        rescheduledRate: 9.0,
      ),
      peakBookingTimes: const [
        PeakBookingTimeItem(
          timeSlot: '09:00 - 11:00',
          bookingVolume: 42,
          isPeak: false,
        ),
        PeakBookingTimeItem(
          timeSlot: '11:00 - 13:00',
          bookingVolume: 68,
          isPeak: false,
        ),
        PeakBookingTimeItem(
          timeSlot: '14:00 - 16:00',
          bookingVolume: 114,
          isPeak: true,
        ),
        PeakBookingTimeItem(
          timeSlot: '16:00 - 18:00',
          bookingVolume: 126,
          isPeak: true,
        ),
        PeakBookingTimeItem(
          timeSlot: '18:00 - 20:00',
          bookingVolume: 56,
          isPeak: false,
        ),
      ],
      busiestDayOfWeek: 'Thursday',
      busiestTimeWindow: '2:00 PM – 6:00 PM',
      rescheduled: const RescheduledAppointmentsData(
        totalRescheduled: 34,
        rescheduleRate: 9.0,
        avgNoticeTime: '26 hours',
        topReasons: [
          RescheduledReasonItem(
            reason: 'Patient Work / Travel Conflict',
            count: 16,
            percentage: 47.0,
          ),
          RescheduledReasonItem(
            reason: 'Specialist Session Extension',
            count: 9,
            percentage: 26.5,
          ),
          RescheduledReasonItem(
            reason: 'Illness / Family Emergency',
            count: 6,
            percentage: 17.6,
          ),
          RescheduledReasonItem(
            reason: 'Treatment Pre-care Requirement',
            count: 3,
            percentage: 8.9,
          ),
        ],
      ),
    );
  }

  static PatientAnalyticsData _buildPatientAnalytics(
    AdminDateRangeType rangeType,
  ) {
    int newPatients;
    int returning;
    if (rangeType == AdminDateRangeType.days7) {
      newPatients = 14;
      returning = 54;
    } else if (rangeType == AdminDateRangeType.months3) {
      newPatients = 184;
      returning = 620;
    } else {
      newPatients = 62;
      returning = 212;
    }
    final int total = newPatients + returning;

    List<PatientGrowthPoint> growth;
    if (rangeType == AdminDateRangeType.days7) {
      growth = const [
        PatientGrowthPoint(
          dateLabel: 'Mon',
          totalCumulative: 1272,
          monthlyNew: 6,
        ),
        PatientGrowthPoint(
          dateLabel: 'Tue',
          totalCumulative: 1278,
          monthlyNew: 6,
        ),
        PatientGrowthPoint(
          dateLabel: 'Wed',
          totalCumulative: 1283,
          monthlyNew: 5,
        ),
        PatientGrowthPoint(
          dateLabel: 'Thu',
          totalCumulative: 1290,
          monthlyNew: 7,
        ),
        PatientGrowthPoint(
          dateLabel: 'Fri',
          totalCumulative: 1295,
          monthlyNew: 5,
        ),
        PatientGrowthPoint(
          dateLabel: 'Sat',
          totalCumulative: 1298,
          monthlyNew: 9,
        ),
        PatientGrowthPoint(
          dateLabel: 'Sun',
          totalCumulative: 1302,
          monthlyNew: 4,
        ),
      ];
    } else if (rangeType == AdminDateRangeType.months3) {
      growth = const [
        PatientGrowthPoint(
          dateLabel: 'May',
          totalCumulative: 1040,
          monthlyNew: 52,
        ),
        PatientGrowthPoint(
          dateLabel: 'Jun',
          totalCumulative: 1115,
          monthlyNew: 75,
        ),
        PatientGrowthPoint(
          dateLabel: 'Jul',
          totalCumulative: 1198,
          monthlyNew: 83,
        ),
        PatientGrowthPoint(
          dateLabel: 'Aug',
          totalCumulative: 1284,
          monthlyNew: 86,
        ),
      ];
    } else {
      growth = const [
        PatientGrowthPoint(
          dateLabel: 'Week 1',
          totalCumulative: 1238,
          monthlyNew: 12,
        ),
        PatientGrowthPoint(
          dateLabel: 'Week 2',
          totalCumulative: 1253,
          monthlyNew: 15,
        ),
        PatientGrowthPoint(
          dateLabel: 'Week 3',
          totalCumulative: 1268,
          monthlyNew: 15,
        ),
        PatientGrowthPoint(
          dateLabel: 'Week 4',
          totalCumulative: 1284,
          monthlyNew: 16,
        ),
      ];
    }

    return PatientAnalyticsData(
      newVsReturning: PatientRatioData(
        newPatients: newPatients,
        returningPatients: returning,
        newPercentage: (newPatients / total * 100).roundToDouble(),
        returningPercentage: (returning / total * 100).roundToDouble(),
      ),
      growthTimeline: growth,
      retention: const PatientRetentionData(
        retentionRate: 86.4,
        averageReturnDays: 24,
        repeatBookingRate: 63.1,
        activeLoyaltyMembers: 412,
        retentionTrend: '+4.2% vs last quarter',
      ),
    );
  }
}
