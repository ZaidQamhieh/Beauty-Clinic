import 'package:beauty_clinic_app/features/dashboard/data/admin_analytics_models.dart';
import 'package:beauty_clinic_app/features/dashboard/presentation/widgets/admin_analytics_charts.dart';
import 'package:beauty_clinic_app/features/dashboard/presentation/widgets/admin_date_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Analytics Repository & Models', () {
    test(
      'fetchDashboardData returns valid structure for 7 Days, 30 Days, 3 Months',
      () {
        final d7 = AdminAnalyticsRepository.fetchDashboardData(
          rangeType: AdminDateRangeType.days7,
        );
        expect(d7.rangeType, AdminDateRangeType.days7);
        expect(d7.overview.totalPatients, greaterThan(0));
        expect(d7.serviceAnalytics.bookingsByService.isNotEmpty, isTrue);
        expect(d7.doctorAnalytics.utilizationList.isNotEmpty, isTrue);
        expect(d7.appointmentAnalytics.bookingsOverTime.isNotEmpty, isTrue);
        expect(d7.patientAnalytics.newVsReturning.newPatients, greaterThan(0));

        final d30 = AdminAnalyticsRepository.fetchDashboardData(
          rangeType: AdminDateRangeType.days30,
        );
        expect(d30.rangeType, AdminDateRangeType.days30);
        expect(d30.overview.totalPatients, greaterThan(0));

        final d3m = AdminAnalyticsRepository.fetchDashboardData(
          rangeType: AdminDateRangeType.months3,
        );
        expect(d3m.rangeType, AdminDateRangeType.months3);
        expect(d3m.overview.totalPatients, greaterThan(0));
      },
    );

    test(
      'AdminDashboardData.fromJson correctly parses full backend response payload',
      () {
        final json = {
          'startDate': '2026-08-01T00:00:00Z',
          'endDate': '2026-08-17T00:00:00Z',
          'overview': {
            'totalPatients': 1284,
            'patientTrend': '+14.2%',
            'patientTrendSub': '+18 new',
            'totalDoctors': 4,
            'activeDoctorsNow': 4,
            'doctorSub': 'All rooms staffed',
            'todayAppointments': 14,
            'confirmedAppointments': 11,
            'inRoomAppointments': 2,
            'pendingAppointments': 3,
            'todaySessions': 18,
            'completedSessions': 8,
            'ongoingSessions': 10,
          },
          'serviceAnalytics': {
            'bookingsByService': [
              {
                'serviceName': 'HydraFacial Glow',
                'category': 'FACIAL',
                'bookingsCount': 142,
                'percentage': 34.0,
                'revenue': '₪63,900',
                'iconKey': 'spa',
                'accentColorHex': '#E11D48',
              },
            ],
            'growthOverTime': [
              {
                'dateLabel': '1 Aug',
                'laserCount': 12.0,
                'facialCount': 20.0,
                'contourCount': 6.0,
                'injectableCount': 10.0,
              },
            ],
            'topService': 'HydraFacial Glow',
            'growthPercentage': '+18.4%',
          },
          'doctorAnalytics': {
            'utilizationList': [
              {
                'doctorName': 'Dr. Hana Nasser',
                'specialty': 'Cosmetic Dermatology',
                'bookedHours': 34.5,
                'totalAvailableHours': 40.0,
                'utilizationPercentage': 86.2,
                'status': 'High Demand',
                'statusColorHex': '#E11D48',
              },
            ],
            'availableSlotsList': [
              {
                'doctorName': 'Dr. Hana Nasser',
                'specialty': 'Cosmetic Dermatology',
                'avatarInitials': 'HN',
                'availableSlotsCount': 3,
                'slots': ['14:30', '16:15'],
                'nextAvailable': 'Today 14:30',
                'room': 'Suite 101',
              },
            ],
            'averageUtilization': 86.2,
            'totalFreeSlotsToday': 3,
          },
          'appointmentAnalytics': {
            'bookingsOverTime': [
              {
                'dateLabel': '1 Aug',
                'booked': 22.0,
                'completed': 18.0,
                'cancelled': 2.0,
              },
            ],
            'outcomes': {
              'completed': 78,
              'cancelled': 7,
              'noShow': 3,
              'rescheduled': 12,
              'completedRate': 78.0,
              'cancelledRate': 7.0,
              'noShowRate': 3.0,
              'rescheduledRate': 12.0,
            },
            'peakBookingTimes': [
              {'timeSlot': '02:00 PM', 'bookingVolume': 46, 'isPeak': true},
            ],
            'busiestDayOfWeek': 'Thursday',
            'busiestTimeWindow': '2:00 PM – 5:30 PM',
            'rescheduled': {
              'totalRescheduled': 12,
              'rescheduleRate': 8.4,
              'avgNoticeTime': '26 hours ahead',
              'topReasons': [
                {
                  'reason': 'Patient Schedule Conflict',
                  'count': 7,
                  'percentage': 58.3,
                },
              ],
            },
          },
          'patientAnalytics': {
            'newVsReturning': {
              'newPatients': 34,
              'returningPatients': 94,
              'newPercentage': 26.6,
              'returningPercentage': 73.4,
            },
            'growthTimeline': [
              {
                'dateLabel': 'Aug 2026',
                'totalCumulative': 1284.0,
                'monthlyNew': 86.0,
              },
            ],
            'retention': {
              'retentionRate': 86.4,
              'averageReturnDays': 24,
              'repeatBookingRate': 78.5,
              'activeLoyaltyMembers': 112,
              'retentionTrend': '+4.8%',
            },
          },
          'operations': {
            'todayAppointments': [
              {
                'id': 'appt-1',
                'time': '09:15',
                'patientName': 'Nour Al-Khalil',
                'treatmentName': 'Laser Resurfacing',
                'doctorName': 'Dr. Hana',
                'status': 'In Room',
              },
            ],
            'staffList': [
              {
                'name': 'Dr. Hana Nasser',
                'role': 'Dermatologist',
                'appointmentsCount': 4,
                'status': 'Available',
                'isDoctor': true,
              },
            ],
          },
        };

        final data = AdminDashboardData.fromJson(
          json,
          rangeType: AdminDateRangeType.days30,
        );
        expect(data.overview.totalPatients, 1284);
        expect(data.serviceAnalytics.topService, 'HydraFacial Glow');
        expect(
          data.doctorAnalytics.utilizationList.first.doctorName,
          'Dr. Hana Nasser',
        );
        expect(data.appointmentAnalytics.outcomes.completed, 78);
        expect(data.patientAnalytics.retention.retentionRate, 86.4);
        expect(
          data.operations.todayAppointments.first.patientName,
          'Nour Al-Khalil',
        );
        expect(data.operations.staffList.first.name, 'Dr. Hana Nasser');
      },
    );

    test(
      'fetchDashboardDataAsync falls back gracefully when apiClient is null',
      () async {
        final data = await AdminAnalyticsRepository.fetchDashboardDataAsync(
          rangeType: AdminDateRangeType.days30,
        );
        expect(data.overview.totalPatients, greaterThan(0));
      },
    );
  });

  group('Admin Analytics Widgets', () {
    testWidgets(
      'AdminDateFilterBar displays range chips and reacts to selection',
      (tester) async {
        AdminDateRangeType? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminDateFilterBar(
                selectedRangeType: AdminDateRangeType.days30,
                customDateRange: null,
                formattedRange: '18 Jul 2026 – 17 Aug 2026',
                onRangeSelected: (type, customRange) {
                  selected = type;
                },
              ),
            ),
          ),
        );

        expect(find.text('30 Days'), findsOneWidget);
        expect(find.text('7 Days'), findsOneWidget);
        expect(find.text('3 Months'), findsOneWidget);
        expect(find.text('Custom'), findsOneWidget);

        await tester.tap(find.text('7 Days'));
        await tester.pump();
        expect(selected, AdminDateRangeType.days7);
      },
    );

    testWidgets('ServiceBookingsBarChart renders rows correctly', (
      tester,
    ) async {
      final data =
          AdminAnalyticsRepository.fetchDashboardData().serviceAnalytics;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServiceBookingsBarChart(data: data),
            ),
          ),
        ),
      );

      expect(find.text('Bookings by Service'), findsOneWidget);
      expect(find.text('HydraFacial Glow'), findsWidgets);
    });
  });
}
