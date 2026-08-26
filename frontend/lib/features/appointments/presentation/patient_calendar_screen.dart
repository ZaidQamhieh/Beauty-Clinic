import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../doctor_availability/presentation/widgets/availability_sessions_view.dart';
import '../data/appointment_api.dart';

/// A patient's own day-by-day timeline of booked appointments - the
/// patient-facing counterpart to a doctor's "My Calendar" screen. Unlike the
/// doctor/admin versions, this has no availability shading (patients have no
/// working hours), and labels each session by the treating doctor rather
/// than the patient themselves.
class PatientCalendarScreen extends StatelessWidget {
  const PatientCalendarScreen({super.key, required this.appointmentApi});

  final AppointmentApi appointmentApi;

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
            'Your booked appointments, day by day.',
            style: AppTypography.bodySmall(color: AppColors.textSub),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 700,
            child: AvailabilitySessionsView(
              fetchSessions: (date) => appointmentApi.myDayFor(date),
              primaryLabel: (appointment, session) => session.practitionerName,
            ),
          ),
        ],
      ),
    );
  }
}
