import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../appointments/data/appointment_api.dart';
import '../data/doctor_availability_api.dart';
import 'widgets/availability_sessions_view.dart';

/// A doctor's own availability and booked sessions.
class MyCalendarScreen extends StatelessWidget {
  const MyCalendarScreen({
    super.key,
    required this.appointmentApi,
    required this.availabilityApi,
  });

  final AppointmentApi appointmentApi;
  final DoctorAvailabilityApi availabilityApi;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Calendar', style: AppTypography.displaySubtitle()),
          const SizedBox(height: 4),
          Text(
            "Your availability and booked sessions, day by day.",
            style: AppTypography.bodySmall(color: AppColors.textSub),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 700,
            child: AvailabilitySessionsView(
              fetchSessions: (date) => appointmentApi.myScheduleFor(date),
              fetchAvailability: () => availabilityApi.list(),
            ),
          ),
        ],
      ),
    );
  }
}
