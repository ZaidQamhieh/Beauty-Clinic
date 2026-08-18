import '../../../../network/api_client.dart';
import 'admin_analytics_models.dart';

class DoctorDashboardData {
  final int activePatientsCount;
  final int todayPatientsCount;
  final List<PatientGrowthPoint> appointmentsOverTime;
  final AppointmentOutcomesData appointmentOutcomes;
  final ServiceAnalyticsData treatmentsPerformed;
  final List<DoctorAppointmentItem> todayAppointments;
  final List<DoctorAppointmentItem> upcomingAppointments;

  const DoctorDashboardData({
    required this.activePatientsCount,
    required this.todayPatientsCount,
    required this.appointmentsOverTime,
    required this.appointmentOutcomes,
    required this.treatmentsPerformed,
    required this.todayAppointments,
    required this.upcomingAppointments,
  });

  factory DoctorDashboardData.fromJson(Map<String, dynamic> json) {
    final appointmentsOverTimeList = (json['appointmentsOverTime'] as List<dynamic>?)
            ?.map((e) => PatientGrowthPoint(
                  dateLabel: e['dateLabel']?.toString() ?? '',
                  totalCumulative: (e['count'] as num?)?.toDouble() ?? 0.0,
                  monthlyNew: (e['count'] as num?)?.toDouble() ?? 0.0,
                ))
            .toList() ??
        [];

    final treatmentsList = (json['treatmentsPerformed'] as List<dynamic>?)
            ?.map((e) => ServiceBookingItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final ServiceAnalyticsData serviceAnalytics = ServiceAnalyticsData(
      bookingsByService: treatmentsList,
      growthOverTime: const [],
      topService: treatmentsList.isNotEmpty ? treatmentsList.first.serviceName : 'Consultation',
      growthPercentage: '+0.0%',
    );

    final todayAppts = (json['todayAppointments'] as List<dynamic>?)
            ?.map((e) => DoctorAppointmentItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final upcomingAppts = (json['upcomingAppointments'] as List<dynamic>?)
            ?.map((e) => DoctorAppointmentItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return DoctorDashboardData(
      activePatientsCount: (json['activePatientsCount'] as num?)?.toInt() ?? 0,
      todayPatientsCount: (json['todayPatientsCount'] as num?)?.toInt() ?? 0,
      appointmentsOverTime: appointmentsOverTimeList,
      appointmentOutcomes: json['appointmentOutcomes'] != null
          ? AppointmentOutcomesData.fromJson(json['appointmentOutcomes'] as Map<String, dynamic>)
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
      treatmentsPerformed: serviceAnalytics,
      todayAppointments: todayAppts,
      upcomingAppointments: upcomingAppts,
    );
  }
}

class DoctorAppointmentItem {
  final String appointmentId;
  final String time;
  final String patientName;
  final String treatmentName;
  final String doctorName;
  final String status;
  final String date;

  const DoctorAppointmentItem({
    required this.appointmentId,
    required this.time,
    required this.patientName,
    required this.treatmentName,
    required this.doctorName,
    required this.status,
    required this.date,
  });

  factory DoctorAppointmentItem.fromJson(Map<String, dynamic> json) {
    return DoctorAppointmentItem(
      appointmentId: json['appointmentId']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      treatmentName: json['treatmentName']?.toString() ?? '',
      doctorName: json['doctorName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }
}

class DoctorDashboardRepository {
  static Future<DoctorDashboardData> fetchDashboardData(ApiClient? apiClient) async {
    if (apiClient != null) {
      try {
        final response = await apiClient.get('/api/doctor/analytics');
        if (response.data is Map<String, dynamic>) {
          return DoctorDashboardData.fromJson(response.data as Map<String, dynamic>);
        }
      } catch (_) {
        // Fallback to offline mock on failure
      }
    }
    return _offlineMock();
  }

  static DoctorDashboardData _offlineMock() {
    return DoctorDashboardData(
      activePatientsCount: 142,
      todayPatientsCount: 8,
      appointmentsOverTime: const [
        PatientGrowthPoint(dateLabel: 'Week 1', totalCumulative: 12.0, monthlyNew: 12.0),
        PatientGrowthPoint(dateLabel: 'Week 2', totalCumulative: 15.0, monthlyNew: 15.0),
        PatientGrowthPoint(dateLabel: 'Week 3', totalCumulative: 15.0, monthlyNew: 15.0),
        PatientGrowthPoint(dateLabel: 'Week 4', totalCumulative: 16.0, monthlyNew: 16.0),
      ],
      appointmentOutcomes: const AppointmentOutcomesData(
        completed: 18,
        cancelled: 2,
        noShow: 1,
        rescheduled: 1,
        completedRate: 81.8,
        cancelledRate: 9.1,
        noShowRate: 4.5,
        rescheduledRate: 4.5,
      ),
      treatmentsPerformed: const ServiceAnalyticsData(
        bookingsByService: [],
        growthOverTime: [],
        topService: 'Consultation',
        growthPercentage: '+0.0%',
      ),
      todayAppointments: const [],
      upcomingAppointments: const [],
    );
  }
}
