import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/clinic_time.dart';
import '../data/doctor_summary.dart';
import '../data/free_slot.dart';
import '../data/treatment.dart';
import 'booking_format.dart';
import 'booking_result_steps.dart';

// The clinic day the timeline bar spans.
const int _dayStartHour = 9;
const int _dayEndHour = 18;

/// Picking a day, a treatment, and a time.
class BookingBrowseStep extends StatelessWidget {
  const BookingBrowseStep({
    super.key,
    required this.today,
    required this.selectedDay,
    required this.maxHorizonDays,
    required this.treatments,
    required this.selectedTreatment,
    required this.slots,
    required this.slotsLoading,
    required this.slotsError,
    required this.dayLocked,
    required this.doctorsById,
    required this.viewByDoctor,
    required this.chosenDoctorId,
    required this.onDayChanged,
    required this.onTreatmentChanged,
    required this.onViewChanged,
    required this.onDoctorChosen,
    required this.onSlotChosen,
    required this.onRetrySlots,
  });

  final DateTime today;
  final DateTime selectedDay;
  final int maxHorizonDays;

  final List<Treatment> treatments;
  final Treatment? selectedTreatment;

  final List<FreeSlot>? slots;
  final bool slotsLoading;
  final String? slotsError;

  /// True once a treatment is held, pinning the visit to its day.
  final bool dayLocked;

  final Map<String, DoctorSummary> doctorsById;
  final bool viewByDoctor;

  /// Set once a doctor is picked.
  final String? chosenDoctorId;

  final ValueChanged<DateTime> onDayChanged;
  final ValueChanged<Treatment?> onTreatmentChanged;
  final ValueChanged<bool> onViewChanged;

  /// Null steps back to all doctors.
  final ValueChanged<String?> onDoctorChosen;
  final ValueChanged<FreeSlot> onSlotChosen;
  final VoidCallback onRetrySlots;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 340,
                child: SingleChildScrollView(child: _leftPanel(context)),
              ),
              const SizedBox(width: 24),
              Expanded(child: SingleChildScrollView(child: _rightPanel())),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _leftPanel(context),
              const SizedBox(height: 20),
              _rightPanel(),
            ],
          ),
        );
      },
    );
  }

  Widget _leftPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _calendar(context),
        if (dayLocked) ...[
          const SizedBox(height: 8),
          Text(
            'One visit is one day. Remove your treatments to pick another date.',
            style: AppTypography.bodySmall(),
          ),
        ],
        const SizedBox(height: 20),
        Text('SELECTED TREATMENT', style: AppTypography.labelSmall()),
        const SizedBox(height: 8),
        _treatmentCombobox(),
        const SizedBox(height: 20),
        Text('AVAILABILITY VIEW', style: AppTypography.labelSmall()),
        const SizedBox(height: 8),
        _viewToggle(),
      ],
    );
  }

  Widget _calendar(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      // Recolour the Material calendar to the rose theme.
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.rose,
            onPrimary: AppColors.white,
            onSurface: AppColors.text,
          ),
        ),
        // A locked day offers only itself, so no other date is tappable.
        child: CalendarDatePicker(
          initialDate: selectedDay,
          firstDate: dayLocked ? selectedDay : today,
          lastDate: dayLocked
              ? selectedDay
              : today.add(Duration(days: maxHorizonDays)),
          onDateChanged: onDayChanged,
        ),
      ),
    );
  }

  Widget _treatmentCombobox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: AppColors.rose),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Treatment>(
                isExpanded: true,
                value: selectedTreatment,
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: AppColors.textMuted),
                items: [
                  for (final treatment in treatments)
                    DropdownMenuItem(
                      value: treatment,
                      child: Text(
                        '${treatment.label} · ${treatment.durationMinutes} min',
                        style: AppTypography.bodyMedium(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onTreatmentChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleButton(
                'View by Doctor', viewByDoctor, () => onViewChanged(true)),
          ),
          Expanded(
            child: _toggleButton(
                'View by Time', !viewByDoctor, () => onViewChanged(false)),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: active ? AppColors.bgCard : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: active
            ? const [BoxShadow(color: AppColors.shadow, blurRadius: 4)]
            : null,
      ),
      // InkWell, so the toggle is focusable.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              style: AppTypography.labelMedium(
                  color: active ? AppColors.rose : AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Right panel ───────────────────────────────────────────────────────────

  Widget _rightPanel() {
    if (slotsLoading) {
      return const SizedBox(
          height: 240, child: Center(child: CircularProgressIndicator()));
    }
    if (slotsError != null) {
      return SizedBox(
        height: 240,
        child: BookingMessage(
          icon: Icons.error_outline,
          text: slotsError!,
          onRetry: onRetrySlots,
        ),
      );
    }
    final free = slots ?? const <FreeSlot>[];
    if (free.isEmpty) {
      return SizedBox(
        height: 240,
        child: BookingMessage(
          icon: Icons.event_busy_outlined,
          text: 'No free times for ${selectedTreatment?.label ?? 'this treatment'} on '
              '${BookingFormat.calendarDay(selectedDay)}. Try another day or treatment.',
        ),
      );
    }
    if (!viewByDoctor) return _byTime(free);
    if (chosenDoctorId != null) return _doctorTimes(chosenDoctorId!);
    return _byDoctor();
  }

  Widget _panelHeader(String title, String note) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(title, style: AppTypography.labelLarge())),
          Text(note, style: AppTypography.labelSmall()),
        ],
      ),
    );
  }

  // ─── By doctor: cards, then times ─────────────────────────────────────────

  Widget _byDoctor() {
    final byDoctor = _slotsByDoctor();
    final ids = byDoctor.keys.toList()
      ..sort((a, b) =>
          _freeHours(byDoctor[b]!).length.compareTo(_freeHours(byDoctor[a]!).length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelHeader('Available Doctors — ${BookingFormat.calendarDay(selectedDay)}',
            'Sorted by availability'),
        for (final id in ids) _doctorCard(id, byDoctor[id]!),
      ],
    );
  }

  Widget _doctorCard(String doctorId, List<FreeSlot> slots) {
    final doctor = doctorsById[doctorId];
    final tags = doctor?.categoryTags ?? const [];
    final freeHours = _freeHours(slots).length;
    final earliest =
        slots.map((s) => s.startTime).reduce((a, b) => a.isBefore(b) ? a : b);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.bgRose,
                child: Text(doctor?.initials ?? '?',
                    style: AppTypography.labelLarge(color: AppColors.rose)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slots.first.practitionerName,
                        style: AppTypography.labelLarge()),
                    if (tags.isNotEmpty)
                      Text(tags.join(', '), style: AppTypography.bodySmall()),
                  ],
                ),
              ),
              _hoursBadge(freeHours),
            ],
          ),
          const SizedBox(height: 14),
          _timelineBar(slots),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Earliest slot: ${BookingFormat.time12(earliest)}',
                  style: AppTypography.bodySmall()),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rose,
                  side: const BorderSide(color: AppColors.borderRose),
                ),
                onPressed: () => onDoctorChosen(doctorId),
                child: const Text('Choose Doctor'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hoursBadge(int hours) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgSage,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$hours hours free',
          style: AppTypography.labelSmall(color: AppColors.sageDark)),
    );
  }

  Widget _timelineBar(List<FreeSlot> slots) {
    final free = _freeHours(slots);
    final (start, end) = _timelineSpan();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Both labels flex, or wide spans overflow.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'DAILY TIMELINE (${BookingFormat.hour12(start)} – ${BookingFormat.hour12(end)})',
                style: AppTypography.labelSmall(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Available blocks highlighted',
                style: AppTypography.labelSmall(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int hour = start; hour < end; hour++) ...[
              Expanded(
                // Hover a block to see its hour range.
                child: Tooltip(
                  message: BookingFormat.hourRange12(hour),
                  waitDuration: const Duration(milliseconds: 200),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: free.contains(hour) ? AppColors.rose : AppColors.bgAlt,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              if (hour < end - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }

  Widget _doctorTimes(String doctorId) {
    final slots = _slotsByDoctor()[doctorId] ?? const <FreeSlot>[];
    final doctor = doctorsById[doctorId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => onDoctorChosen(null),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('All doctors'),
          ),
        ),
        _panelHeader('${doctor?.fullName ?? 'Doctor'} — pick a time',
            BookingFormat.calendarDay(selectedDay)),
        ..._periodPills(slots),
      ],
    );
  }

  // Small tappable pills, grouped by period.
  List<Widget> _periodPills(List<FreeSlot> slots) {
    final widgets = <Widget>[];
    _groupByPeriod(slots).forEach((label, list) {
      if (list.isEmpty) return;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(label, style: AppTypography.labelSmall()),
      ));
      widgets.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final slot in list)
            Material(
              color: AppColors.rosePale,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => onSlotChosen(slot),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderRose),
                  ),
                  child: Text(BookingFormat.time12(slot.startTime),
                      style: AppTypography.labelMedium(color: AppColors.roseDark)),
                ),
              ),
            ),
        ],
      ));
    });
    return widgets;
  }

  // ─── By time: chronological cards grouped by period ────────────────────────

  Widget _byTime(List<FreeSlot> slots) {
    final children = <Widget>[
      _panelHeader('Available Slots — ${BookingFormat.calendarDay(selectedDay)}',
          'Chronological timeline'),
    ];
    _groupByPeriod(slots).forEach((label, list) {
      if (list.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(label, style: AppTypography.labelSmall()),
      ));
      for (final slot in list) {
        children.add(_slotCard(slot));
      }
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _slotCard(FreeSlot slot) {
    final doctor = doctorsById[slot.practitionerUserId];
    final specialty =
        (doctor?.categoryTags.isNotEmpty ?? false) ? doctor!.categoryTags.first : '';
    final duration = selectedTreatment?.durationMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.rosePale,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(BookingFormat.time12(slot.startTime),
                style: AppTypography.labelMedium(color: AppColors.roseDark)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.practitionerName, style: AppTypography.labelLarge()),
                Text(
                  [
                    if (specialty.isNotEmpty) specialty,
                    if (duration != null) '$duration min',
                  ].join(' · '),
                  style: AppTypography.bodySmall(),
                ),
              ],
            ),
          ),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: AppColors.white,
              minimumSize: const Size(34, 34),
            ),
            icon: const Icon(Icons.arrow_forward, size: 16),
            onPressed: () => onSlotChosen(slot),
          ),
        ],
      ),
    );
  }

  // ─── Slot grouping helpers ────────────────────────────────────────────────

  Map<String, List<FreeSlot>> _slotsByDoctor() {
    final byDoctor = <String, List<FreeSlot>>{};
    for (final slot in slots ?? const <FreeSlot>[]) {
      byDoctor.putIfAbsent(slot.practitionerUserId, () => []).add(slot);
    }
    for (final list in byDoctor.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return byDoctor;
  }

  // Every hour a slot runs through.
  Set<int> _freeHours(List<FreeSlot> slots) {
    final hours = <int>{};
    for (final slot in slots) {
      final start = ClinicTime.at(slot.startTime);
      // Last minute worked, so exact ends exclude.
      final lastMinute = ClinicTime.at(slot.endTime).subtract(
        const Duration(minutes: 1),
      );
      hours.add(start.hour);
      for (var hour = start.hour + 1; hour <= lastMinute.hour; hour++) {
        hours.add(hour);
      }
    }
    return hours;
  }

  // The usual bar, widened to cover outliers.
  (int, int) _timelineSpan() {
    var start = _dayStartHour;
    var end = _dayEndHour;
    for (final hour in _freeHours(slots ?? const <FreeSlot>[])) {
      if (hour < start) start = hour;
      if (hour >= end) end = hour + 1;
    }
    return (start, end);
  }

  // Slots bucketed by period, each in start order.
  Map<String, List<FreeSlot>> _groupByPeriod(List<FreeSlot> slots) {
    final groups = <String, List<FreeSlot>>{
      'MORNING': [],
      'AFTERNOON': [],
      'EVENING': [],
    };
    for (final slot in slots) {
      final hour = ClinicTime.at(slot.startTime).hour;
      if (hour < 12) {
        groups['MORNING']!.add(slot);
      } else if (hour < 17) {
        groups['AFTERNOON']!.add(slot);
      } else {
        groups['EVENING']!.add(slot);
      }
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return groups;
  }
}
