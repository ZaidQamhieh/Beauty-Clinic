import '../../../core/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../network/api_client.dart';
import '../../appointments/data/appointment_api.dart';
import '../../appointments/data/doctor_api.dart';
import '../../appointments/data/doctor_summary.dart';
import '../../appointments/data/treatment_api.dart';
import '../../appointments/presentation/booking_flow_sheet.dart';
import '../../doctor_availability/data/doctor_availability_api.dart';
import '../../patients/presentation/patient_picker.dart';

/// Doctor directory for front-desk booking.
class DoctorDirectoryScreen extends StatefulWidget {
  const DoctorDirectoryScreen({
    super.key,
    required this.doctorApi,
    required this.availabilityApi,
    required this.apiClient,
    required this.appointmentApi,
    required this.treatmentApi,
  });

  final DoctorApi doctorApi;
  final DoctorAvailabilityApi availabilityApi;
  final ApiClient apiClient;
  final AppointmentApi appointmentApi;
  final TreatmentApi treatmentApi;

  @override
  State<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends State<DoctorDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DoctorSummary> _doctors = const [];
  Map<String, List<DoctorAvailability>> _availability = const {};
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // One pass up front; no per-card spinners.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doctors = await widget.doctorApi.list();
      final schedules = await Future.wait(
        doctors.map((doctor) async {
          try {
            return await widget.availabilityApi.listForDoctor(doctor.userId);
          } catch (_) {
            return const <DoctorAvailability>[];
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _doctors = doctors;
        _availability = {
          for (var index = 0; index < doctors.length; index++)
            doctors[index].userId: schedules[index],
        };
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load doctor profiles.';
      });
    }
  }

  List<DoctorSummary> get _visibleDoctors {
    if (_query.isEmpty) return _doctors;
    return _doctors.where((doctor) {
      final haystack = [
        doctor.fullName,
        ...doctor.specializations.map(_formatSpecialty),
        ...doctor.categoryTags,
      ].join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final doctors = _visibleDoctors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(),
          const SizedBox(height: 24),
          _buildSearchBar(),
          const SizedBox(height: 20),
          if (_loading)
            const SizedBox(height: 420, child: SkeletonGrid())
          else if (_error != null)
            _buildStateCard(
              Icons.error_outline,
              _error!,
              'Check the connection and try again.',
              action: FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
                child: const Text('Retry'),
              ),
            )
          else if (doctors.isEmpty)
            _buildStateCard(
              Icons.person_search_outlined,
              'No doctors match that search.',
              'Try a name, a specialty, or clear the search.',
            )
          else
            _buildDoctorsGrid(doctors),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgRose,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderRose),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_information_outlined,
              color: AppColors.rose,
              size: 28,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Doctors', style: AppTypography.displayTitle()),
                const SizedBox(height: 4),
                Text(
                  'Specialties and current availability for appointment booking.',
                  style: AppTypography.bodySmall(color: AppColors.textSub),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.badge_outlined,
                  size: 16,
                  color: AppColors.rose,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_doctors.length} Doctors',
                  style: AppTypography.labelLarge(color: AppColors.roseDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AppSearchField(
      controller: _searchController,
      hintText: 'Search by doctor name or specialty...',
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
      onClear: () {
        _searchController.clear();
        setState(() => _query = '');
      },
    );
  }

  Widget _buildDoctorsGrid(List<DoctorSummary> doctors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1000
            ? 3
            : constraints.maxWidth > 650
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 244,
          ),
          itemCount: doctors.length,
          itemBuilder: (_, index) => _buildDoctorCard(doctors[index]),
        );
      },
    );
  }

  Widget _buildDoctorCard(DoctorSummary doctor) {
    final tags = doctor.categoryTags.isEmpty
        ? doctor.specializations.map(_formatSpecialty).toList()
        : doctor.categoryTags;
    final today = _todayHours(doctor);

    return Material(
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDoctorDialog(doctor),
        hoverColor: AppColors.bgRose.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.bgLavender,
                    child: Text(
                      doctor.initials,
                      style: AppTypography.labelLarge(color: AppColors.lavDark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.fullName,
                          style: AppTypography.displaySubtitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doctor.yearsOfExperience == null
                              ? 'Experience not recorded'
                              : '${doctor.yearsOfExperience} years of experience',
                          style: AppTypography.bodySmall(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final tag in tags.take(3))
                    _badge(tag, AppColors.bgRose, AppColors.roseDark),
                ],
              ),
              const Spacer(),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _statusPill(today),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      today.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall(color: AppColors.textSub),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _book(doctor),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Book'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openDoctorDialog(doctor),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSub,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Schedule'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDoctorDialog(DoctorSummary doctor) {
    final schedule = _availability[doctor.userId] ?? const [];
    final overrides =
        schedule
            .where((item) => item.kind == AvailabilityKind.override)
            .toList()
          ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    final tags = doctor.categoryTags.isEmpty
        ? doctor.specializations.map(_formatSpecialty).toList()
        : doctor.categoryTags;
    final today = _todayHours(doctor);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.bgLavender,
              child: Text(
                doctor.initials,
                style: AppTypography.labelLarge(color: AppColors.lavDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor.fullName, style: AppTypography.displaySubtitle()),
                  Text(
                    doctor.specializations.isEmpty
                        ? 'No specialties recorded'
                        : doctor.specializations
                              .map(_formatSpecialty)
                              .join(', '),
                    style: AppTypography.bodySmall(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            _statusPill(today),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final tag in tags)
                    _badge(tag, AppColors.bgRose, AppColors.roseDark),
                  if (doctor.yearsOfExperience != null)
                    _badge(
                      '${doctor.yearsOfExperience} years',
                      AppColors.bgLavender,
                      AppColors.lavDark,
                    ),
                ],
              ),
              const Divider(height: 26),
              Text(
                'WEEKLY SCHEDULE',
                style: AppTypography.labelSmall(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              _buildWeekStrip(doctor),
              if (overrides.isNotEmpty) ...[
                const Divider(height: 26),
                Text(
                  'UPCOMING CHANGES',
                  style: AppTypography.labelSmall(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                for (final item in overrides.take(3)) _overrideRow(item),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _book(doctor);
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Book appointment'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(DoctorSummary doctor) {
    return Row(
      children: [
        for (final day in AvailabilityDay.values) ...[
          Expanded(child: _dayCell(day, _hoursFor(doctor, day))),
          if (day != AvailabilityDay.sunday) const SizedBox(width: 5),
        ],
      ],
    );
  }

  Widget _dayCell(AvailabilityDay day, String? hours) {
    final working = hours != null;
    return Column(
      children: [
        Text(
          _dayLabel(day),
          style: AppTypography.labelSmall(color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: working ? AppColors.sagePale : AppColors.bgAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            hours ?? '—',
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall(
              color: working ? AppColors.sageDark : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _overrideRow(DoctorAvailability item) {
    final date = DateFormat(
      'EEE d MMM yyyy',
    ).format(item.effectiveFrom.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: item.available ? AppColors.goldPale : AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            item.available ? Icons.event_available_outlined : Icons.block,
            size: 16,
            color: item.available ? AppColors.gold : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(date, style: AppTypography.labelMedium())),
          Text(
            item.available
                ? '${_shortTime(item.startTime)}–${_shortTime(item.endTime)}'
                : 'Not working',
            style: AppTypography.bodySmall(color: AppColors.textSub),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(_TodayHours today) {
    final color = today.working ? AppColors.sageDark : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: today.working ? AppColors.sagePale : AppColors.bgAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        today.working ? 'In today' : 'Off today',
        style: AppTypography.labelSmall(color: color),
      ),
    );
  }

  Widget _badge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(
          color: foreground,
        ).copyWith(fontSize: 10),
      ),
    );
  }

  Widget _buildStateCard(
    IconData icon,
    String title,
    String subtitle, {
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(title, style: AppTypography.labelLarge()),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodySmall(color: AppColors.textMuted),
          ),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }

  Future<void> _book(DoctorSummary doctor) async {
    final patientUserId = await showPatientPicker(context, widget.apiClient);
    if (patientUserId == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => BookingFlowSheet(
        patientUserId: patientUserId,
        treatmentApi: widget.treatmentApi,
        appointmentApi: widget.appointmentApi,
        doctorApi: widget.doctorApi,
      ),
    );
  }

  // Overrides for today beat the weekly pattern.
  _TodayHours _todayHours(DoctorSummary doctor) {
    final schedule = _availability[doctor.userId] ?? const [];
    final now = DateTime.now();
    for (final item in schedule) {
      if (item.kind != AvailabilityKind.override) continue;
      final date = item.effectiveFrom.toLocal();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return item.available
            ? _TodayHours(
                true,
                '${_shortTime(item.startTime)}–${_shortTime(item.endTime)} · changed for today',
              )
            : const _TodayHours(false, 'Not working today');
      }
    }

    final hours = _hoursFor(doctor, _dayFor(now.weekday));
    if (hours != null) return _TodayHours(true, hours);
    return _TodayHours(false, _nextWorkingDay(doctor));
  }

  String? _hoursFor(DoctorSummary doctor, AvailabilityDay day) {
    final schedule = _availability[doctor.userId] ?? const [];
    for (final item in schedule) {
      if (item.kind != AvailabilityKind.recurring) continue;
      if (item.dayOfWeek != day || !item.available) continue;
      return '${_shortTime(item.startTime)}–${_shortTime(item.endTime)}';
    }
    return null;
  }

  String _nextWorkingDay(DoctorSummary doctor) {
    final now = DateTime.now();
    for (var ahead = 1; ahead <= 7; ahead++) {
      final day = _dayFor(now.add(Duration(days: ahead)).weekday);
      final hours = _hoursFor(doctor, day);
      if (hours != null) {
        return 'Back ${_dayLabelLong(day)} ${hours.split('–').first}';
      }
    }
    return 'No published hours';
  }

  AvailabilityDay _dayFor(int weekday) =>
      AvailabilityDay.values[(weekday - 1).clamp(0, 6)];

  String _dayLabel(AvailabilityDay day) => switch (day) {
    AvailabilityDay.monday => 'MON',
    AvailabilityDay.tuesday => 'TUE',
    AvailabilityDay.wednesday => 'WED',
    AvailabilityDay.thursday => 'THU',
    AvailabilityDay.friday => 'FRI',
    AvailabilityDay.saturday => 'SAT',
    AvailabilityDay.sunday => 'SUN',
  };

  String _dayLabelLong(AvailabilityDay day) => switch (day) {
    AvailabilityDay.monday => 'Monday',
    AvailabilityDay.tuesday => 'Tuesday',
    AvailabilityDay.wednesday => 'Wednesday',
    AvailabilityDay.thursday => 'Thursday',
    AvailabilityDay.friday => 'Friday',
    AvailabilityDay.saturday => 'Saturday',
    AvailabilityDay.sunday => 'Sunday',
  };

  String _shortTime(String value) =>
      value.length >= 5 ? value.substring(0, 5) : value;

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

class _TodayHours {
  const _TodayHours(this.working, this.detail);

  final bool working;
  final String detail;
}
