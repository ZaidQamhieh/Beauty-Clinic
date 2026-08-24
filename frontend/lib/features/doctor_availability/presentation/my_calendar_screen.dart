import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../appointments/data/appointment_api.dart';
import '../data/doctor_availability_api.dart';
import 'widgets/availability_sessions_view.dart';

/// A doctor's own day-by-day timeline of availability and booked sessions -
/// the doctor-facing counterpart to the "Availability & Sessions" tab in the
/// admin's per-doctor detail view.
class MyCalendarScreen extends StatelessWidget {
  const MyCalendarScreen({
    super.key,
    required this.appointmentApi,
    required this.availabilityApi,
    this.onBack,
  });

  final AppointmentApi appointmentApi;
  final DoctorAvailabilityApi availabilityApi;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Dashboard'),
              ),
            ),
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
