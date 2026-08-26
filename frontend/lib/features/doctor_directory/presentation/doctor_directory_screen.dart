import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/skeleton.dart';
import '../../appointments/data/doctor_api.dart';
import '../../appointments/data/doctor_summary.dart';
import '../../doctor_availability/data/doctor_availability_api.dart';

class DoctorDirectoryScreen extends StatefulWidget {
  const DoctorDirectoryScreen({
    super.key,
    required this.doctorApi,
    required this.availabilityApi,
  });

  final DoctorApi doctorApi;
  final DoctorAvailabilityApi availabilityApi;

  @override
  State<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends State<DoctorDirectoryScreen> {
  late final Future<List<DoctorSummary>> _doctors;

  @override
  void initState() {
    super.initState();
    _doctors = widget.doctorApi.list();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DoctorSummary>>(
      future: _doctors,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SkeletonGrid();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load doctor profiles.',
              style: AppTypography.bodyMedium(color: AppColors.textMuted),
            ),
          );
        }

        final doctors = snapshot.data ?? const <DoctorSummary>[];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Doctors', style: AppTypography.displayTitle()),
            const SizedBox(height: 4),
            Text(
              'View specialties and current availability for appointment booking.',
              style: AppTypography.bodySmall(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            if (doctors.isEmpty)
              Text(
                'No doctors are currently available.',
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
              )
            else
              ...doctors.map(_buildDoctorCard),
          ],
        );
      },
    );
  }

  Widget _buildDoctorCard(DoctorSummary doctor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.bgLavender,
              child: Text(
                doctor.initials,
                style: AppTypography.labelLarge(color: AppColors.lavDark),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor.fullName, style: AppTypography.labelLarge()),
                  if (doctor.yearsOfExperience != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${doctor.yearsOfExperience} years of experience',
                      style: AppTypography.bodySmall(color: AppColors.textSub),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: doctor.specializations
                        .map(
                          (specialty) => Chip(
                            label: Text(_formatSpecialty(specialty)),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppColors.bgRose,
                            labelStyle: AppTypography.labelSmall(
                              color: AppColors.roseDark,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<DoctorAvailability>>(
                    future: widget.availabilityApi.listForDoctor(doctor.userId),
                    builder: (context, availabilitySnapshot) {
                      if (availabilitySnapshot.connectionState !=
                          ConnectionState.done) {
                        return const LinearProgressIndicator(minHeight: 3);
                      }
                      final availability =
                          availabilitySnapshot.data ?? const [];
                      return _buildAvailabilitySummary(availability);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilitySummary(List<DoctorAvailability> availability) {
    final regular =
        availability
            .where((item) => item.kind == AvailabilityKind.regular)
            .toList()
          ..sort(
            (a, b) => _dayOrder(a.dayOfWeek).compareTo(_dayOrder(b.dayOfWeek)),
          );
    final exceptions =
        availability
            .where((item) => item.kind != AvailabilityKind.regular)
            .toList()
          ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

    if (regular.isEmpty && exceptions.isEmpty) {
      return Text(
        'Availability not published',
        style: AppTypography.bodySmall(color: AppColors.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (regular.isNotEmpty) ...[
          _availabilityHeading('Weekly schedule', Icons.repeat_rounded),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: regular.map(_regularChip).toList(),
          ),
        ],
        if (exceptions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _availabilityHeading('Exceptions', Icons.event_note_outlined),
          const SizedBox(height: 6),
          ...exceptions.map((item) => _exceptionRow(item, exceptions)),
        ],
      ],
    );
  }

  Widget _availabilityHeading(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.labelSmall(color: AppColors.textSub)),
      ],
    );
  }

  // REGULAR is always open; there's no closed variant of it anymore.
  Widget _regularChip(DoctorAvailability item) {
    const color = AppColors.sageDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '${_formatSpecialty(item.dayOfWeek?.name ?? '')} ${_shortTime(item.startTime)}-${_shortTime(item.endTime)}',
        style: AppTypography.labelSmall(color: color),
      ),
    );
  }

  Widget _exceptionRow(
    DoctorAvailability item,
    List<DoctorAvailability> exceptions,
  ) {
    final date = item.effectiveFrom.toLocal().toString().split(' ').first;
    final sameDate = exceptions
        .where(
          (other) =>
              other.effectiveFrom.toLocal().toString().split(' ').first == date,
        )
        .length;
    final conflict = sameDate > 1;
    // VACATION is the only closed exception; MODIFIED/EXTRA_DAY are open windows.
    final isOpen = item.kind != AvailabilityKind.vacation;
    final color = isOpen ? AppColors.sageDark : AppColors.rose;
    final timeText = item.startTime == null || item.endTime == null
        ? 'All day'
        : '${_shortTime(item.startTime)}-${_shortTime(item.endTime)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.check_circle_outline : Icons.block_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$date · $timeText',
              style: AppTypography.bodySmall(color: AppColors.textSub),
            ),
          ),
          if (conflict)
            Text(
              'Conflict',
              style: AppTypography.labelSmall(color: AppColors.rose),
            ),
        ],
      ),
    );
  }

  int _dayOrder(AvailabilityDay? day) {
    const order = {
      AvailabilityDay.monday: 1,
      AvailabilityDay.tuesday: 2,
      AvailabilityDay.wednesday: 3,
      AvailabilityDay.thursday: 4,
      AvailabilityDay.friday: 5,
      AvailabilityDay.saturday: 6,
      AvailabilityDay.sunday: 7,
    };
    return order[day] ?? 99;
  }

  String _shortTime(String? value) =>
      value == null || value.length < 5 ? (value ?? '') : value.substring(0, 5);

  String _formatSpecialty(String value) {
    return value
        .toLowerCase()
        .split('_')
        .map(
          (part) =>
              part.isEmpty ? part : part[0].toUpperCase() + part.substring(1),
        )
        .join(' ');
  }
}
