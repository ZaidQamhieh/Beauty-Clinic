import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/clinic_time.dart';
import '../data/doctor_summary.dart';
import '../data/enum_label.dart';
import '../data/free_slot.dart';
import '../data/treatment.dart';
import 'booking_format.dart';
import 'booking_result_steps.dart';

// The clinic day the timeline bar spans.
const int _dayStartHour = 9;
const int _dayEndHour = 18;

/// Picks day, treatment, and time.
class BookingBrowseStep extends StatelessWidget {
  const BookingBrowseStep({
    super.key,
    required this.today,
    required this.selectedDay,
    required this.maxHorizonDays,
    required this.treatments,
    required this.alreadyInVisit,
    required this.selectedTreatment,
    required this.slots,
    required this.takenSlot,
    required this.openSlots,
    required this.slotsLoading,
    required this.slotsError,
    required this.dayLocked,
    required this.isReschedule,
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

  /// Names held in visit, shown greyed.
  final Set<String> alreadyInVisit;
  final Treatment? selectedTreatment;

  final List<FreeSlot>? slots;

  /// Lost to another booking; offered disabled.
  final FreeSlot? takenSlot;

  /// Open time before treatment narrows roster.
  final List<FreeSlot>? openSlots;
  final bool slotsLoading;
  final String? slotsError;

  /// True once a treatment pins the day.
  final bool dayLocked;

  /// Reschedule may change day, dropping cart.
  final bool isReschedule;

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
          // Stretched, so left calendar can fill.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 340, child: _leftPanel(context, fill: true)),
              const SizedBox(width: 24),
              Expanded(child: SingleChildScrollView(child: _rightPanel())),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _leftPanel(context, fill: false),
              const SizedBox(height: 20),
              _rightPanel(),
            ],
          ),
        );
      },
    );
  }

  // Bounded height lets calendar take remainder.
  Widget _leftPanel(BuildContext context, {required bool fill}) {
    final calendar = _calendar(context, fill: fill);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text('SELECTED TREATMENT', style: AppTypography.labelSmall()),
        const SizedBox(height: 8),
        _treatmentCombobox(),
        const SizedBox(height: 16),
        Text('AVAILABILITY VIEW', style: AppTypography.labelSmall()),
        const SizedBox(height: 8),
        _viewToggle(),
        const SizedBox(height: 16),
        Text('DATE', style: AppTypography.labelSmall()),
        const SizedBox(height: 8),
        // After fixed children, note keeps space.
        if (fill) Expanded(child: calendar) else calendar,
        if (dayLocked) ...[
          const SizedBox(height: 8),
          Text(
            'One visit is one day. Remove your treatments to pick another date.',
            style: AppTypography.bodySmall(),
          ),
        ] else if (isReschedule && alreadyInVisit.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Picking a different day starts this visit over — kept '
            'treatments will need to be re-added.',
            style: AppTypography.bodySmall(),
          ),
        ],
      ],
    );
  }

  Widget _calendar(BuildContext context, {required bool fill}) {
    final calendar = Container(
      // Filling: Expanded hands down the height.
      height: fill ? null : 320,
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      // Recolour Material calendar to rose.
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.rose,
            onPrimary: AppColors.white,
            onSurface: AppColors.text,
          ),
        ),
        // A locked day offers only itself.
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

    return calendar;
  }

  Widget _treatmentCombobox() {
    return _TreatmentField(
      treatments: treatments,
      alreadyInVisit: alreadyInVisit,
      selected: selectedTreatment,
      onChanged: onTreatmentChanged,
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
              'View by Doctor',
              viewByDoctor,
              () => onViewChanged(true),
            ),
          ),
          Expanded(
            child: _toggleButton(
              'View by Time',
              !viewByDoctor,
              () => onViewChanged(false),
            ),
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
                color: active ? AppColors.rose : AppColors.textMuted,
              ),
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
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
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
    // Whole roster, no treatment narrowing yet.
    if (selectedTreatment == null) return _directory();
    final free = slots ?? const <FreeSlot>[];
    if (free.isEmpty && _taken == null) {
      return SizedBox(
        height: 240,
        child: BookingMessage(
          icon: Icons.event_busy_outlined,
          text:
              'No free times for ${selectedTreatment?.label ?? 'this treatment'} on '
              '${BookingFormat.calendarDay(selectedDay)}. Try another day or treatment.',
        ),
      );
    }
    if (!viewByDoctor) return _byTime(free);
    if (chosenDoctorId != null) return _doctorTimes(chosenDoctorId!);
    // No doctor cards to host it.
    if (free.isEmpty) return _byTime(free);
    return _byDoctor();
  }

  // Kept only for the shown day.
  FreeSlot? get _taken {
    final slot = takenSlot;
    if (slot == null || selectedTreatment == null) return null;
    final start = ClinicTime.at(slot.startTime);
    final sameDay =
        start.year == selectedDay.year &&
        start.month == selectedDay.month &&
        start.day == selectedDay.day;
    return sameDay ? slot : null;
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

  // ─── Unfiltered roster ────────────

  // Open time reads as free, not bookable.
  Widget _directory() {
    final open = openSlots ?? const <FreeSlot>[];

    // Toggle decides shape; time source differs.
    if (!viewByDoctor) {
      if (open.isEmpty) {
        return SizedBox(
          height: 240,
          child: BookingMessage(
            icon: Icons.event_busy_outlined,
            text:
                'Nothing free on ${BookingFormat.calendarDay(selectedDay)}. '
                'Try another day.',
          ),
        );
      }
      return _byTime(open);
    }

    final byDoctor = _groupByDoctor(open);

    final roster = doctorsById.values.toList()
      ..sort((a, b) {
        final free = _freeHours(
          byDoctor[b.userId] ?? const [],
        ).length.compareTo(_freeHours(byDoctor[a.userId] ?? const []).length);
        return free != 0 ? free : a.fullName.compareTo(b.fullName);
      });

    if (roster.isEmpty) {
      return const SizedBox(
        height: 240,
        child: BookingMessage(
          icon: Icons.person_off_outlined,
          text: 'No doctors are listed yet.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelHeader(
          'Our Doctors — ${BookingFormat.calendarDay(selectedDay)}',
          'Pick a treatment to book',
        ),
        for (final doctor in roster)
          _directoryCard(doctor, byDoctor[doctor.userId] ?? const []),
      ],
    );
  }

  Widget _directoryCard(DoctorSummary doctor, List<FreeSlot> open) {
    final tags = doctor.categoryTags;
    final freeHours = _freeHours(open).length;

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
                child: Text(
                  doctor.initials,
                  style: AppTypography.labelLarge(color: AppColors.rose),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doctor.fullName, style: AppTypography.labelLarge()),
                    Text(
                      // No specialization qualifies for consultations alone.
                      tags.isEmpty ? 'Consultations' : tags.join(', '),
                      style: AppTypography.bodySmall(),
                    ),
                  ],
                ),
              ),
              if (open.isNotEmpty) _hoursBadge(freeHours),
            ],
          ),
          if (open.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Nothing free on ${BookingFormat.calendarDay(selectedDay)}.',
              style: AppTypography.bodySmall(),
            ),
          ] else ...[
            const SizedBox(height: 14),
            _timelineBar(open),
            const SizedBox(height: 14),
            Text(
              'Free from ${BookingFormat.time12(open.map((s) => s.startTime).reduce((a, b) => a.isBefore(b) ? a : b))}',
              style: AppTypography.bodySmall(),
            ),
          ],
        ],
      ),
    );
  }

  // ─── By doctor: cards, then times ─────────────────────────────────────────

  Widget _byDoctor() {
    final byDoctor = _slotsByDoctor();
    final ids = byDoctor.keys.toList()
      ..sort(
        (a, b) => _freeHours(
          byDoctor[b]!,
        ).length.compareTo(_freeHours(byDoctor[a]!).length),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelHeader(
          'Available Doctors — ${BookingFormat.calendarDay(selectedDay)}',
          'Sorted by availability',
        ),
        for (final id in ids) _doctorCard(id, byDoctor[id]!),
      ],
    );
  }

  Widget _doctorCard(String doctorId, List<FreeSlot> slots) {
    final doctor = doctorsById[doctorId];
    final tags = doctor?.categoryTags ?? const [];
    final freeHours = _freeHours(slots).length;
    final earliest = slots
        .map((s) => s.startTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);

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
                child: Text(
                  doctor?.initials ?? '?',
                  style: AppTypography.labelLarge(color: AppColors.rose),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slots.first.practitionerName,
                      style: AppTypography.labelLarge(),
                    ),
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
              Text(
                'Earliest slot: ${BookingFormat.time12(earliest)}',
                style: AppTypography.bodySmall(),
              ),
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
      child: Text(
        '$hours hours free',
        style: AppTypography.labelSmall(color: AppColors.sageDark),
      ),
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
                // Hover shows the hour range.
                child: Tooltip(
                  message: BookingFormat.hourRange12(hour),
                  waitDuration: const Duration(milliseconds: 200),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: free.contains(hour)
                          ? AppColors.rose
                          : AppColors.bgAlt,
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
        _panelHeader(
          '${doctor?.fullName ?? 'Doctor'} — pick a time',
          BookingFormat.calendarDay(selectedDay),
        ),
        _agenda(slots),
      ],
    );
  }

  // Empty hours kept: a gap is information.
  Widget _agenda(List<FreeSlot> slots) {
    final taken = _taken;
    final byHour = <int, List<FreeSlot>>{};
    for (final slot in slots) {
      byHour
          .putIfAbsent(ClinicTime.at(slot.startTime).hour, () => [])
          .add(slot);
    }
    // Its own doctor still shows it, disabled.
    if (taken != null && taken.practitionerUserId == chosenDoctorId) {
      byHour
          .putIfAbsent(ClinicTime.at(taken.startTime).hour, () => [])
          .add(taken);
    }
    if (byHour.isEmpty) {
      return Text('No free times.', style: AppTypography.bodySmall());
    }

    for (final list in byHour.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    final hours = byHour.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var hour = hours.first; hour <= hours.last; hour++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 62,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      BookingFormat.hour12(hour),
                      style: AppTypography.labelSmall(),
                    ),
                  ),
                ),
                Expanded(
                  child: byHour[hour] == null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('—', style: AppTypography.bodySmall()),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final slot in byHour[hour]!)
                              slot == taken
                                  ? _takenChip(slot)
                                  : _timeChip(slot),
                          ],
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // No InkWell, so nothing is pickable.
  Widget _takenChip(FreeSlot slot) {
    return Tooltip(
      message: 'Booked by someone else',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          BookingFormat.time12(slot.startTime),
          style: AppTypography.labelMedium(
            color: AppColors.textMuted,
          ).copyWith(decoration: TextDecoration.lineThrough),
        ),
      ),
    );
  }

  Widget _timeChip(FreeSlot slot) {
    return Material(
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
          child: Text(
            BookingFormat.time12(slot.startTime),
            style: AppTypography.labelMedium(color: AppColors.roseDark),
          ),
        ),
      ),
    );
  }

  // ─── By time ────────────────────────

  Widget _byTime(List<FreeSlot> slots) {
    final children = <Widget>[
      _panelHeader(
        selectedTreatment == null
            ? 'Open Times — ${BookingFormat.calendarDay(selectedDay)}'
            : 'Available Slots — ${BookingFormat.calendarDay(selectedDay)}',
        selectedTreatment == null
            ? 'Pick a treatment to book'
            : 'Chronological timeline',
      ),
    ];
    final taken = _taken;
    // Merged in, so it keeps its place.
    final rows = taken == null || slots.contains(taken)
        ? slots
        : [...slots, taken];
    _groupByPeriod(rows).forEach((label, list) {
      if (list.isEmpty) return;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(label, style: AppTypography.labelSmall()),
        ),
      );
      for (final slot in list) {
        children.add(_slotCard(slot, taken: slot == taken));
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _slotCard(FreeSlot slot, {bool taken = false}) {
    final treatment = selectedTreatment;
    final doctor = doctorsById[slot.practitionerUserId];
    // Unfiltered rows plan no work.
    final specialty =
        treatment != null && (doctor?.categoryTags.isNotEmpty ?? false)
        ? doctor!.categoryTags.first
        : '';
    final duration = treatment?.durationMinutes;
    final subtitle = taken
        ? 'Booked by someone else'
        : [
            if (specialty.isNotEmpty) specialty,
            if (duration != null) '$duration min',
          ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: taken ? AppColors.bgAlt : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: taken ? AppColors.bgCard : AppColors.rosePale,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              BookingFormat.time12(slot.startTime),
              style: taken
                  ? AppTypography.labelMedium(
                      color: AppColors.textMuted,
                    ).copyWith(decoration: TextDecoration.lineThrough)
                  : AppTypography.labelMedium(color: AppColors.roseDark),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.practitionerName,
                  style: AppTypography.labelLarge(
                    color: taken ? AppColors.textMuted : AppColors.text,
                  ),
                ),
                // Dropped, so the row closes up.
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppTypography.bodySmall()),
              ],
            ),
          ),
          // Cart item is built from a treatment.
          if (selectedTreatment != null)
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: taken ? AppColors.bgAlt : AppColors.rose,
                foregroundColor: taken ? AppColors.textMuted : AppColors.white,
                minimumSize: const Size(34, 34),
              ),
              icon: const Icon(Icons.arrow_forward, size: 16),
              // Null disables the button outright.
              onPressed: taken ? null : () => onSlotChosen(slot),
            ),
        ],
      ),
    );
  }

  // ─── Slot grouping helpers ────────────────────────────────────────────────

  Map<String, List<FreeSlot>> _slotsByDoctor() => _groupByDoctor(slots);

  Map<String, List<FreeSlot>> _groupByDoctor(List<FreeSlot>? source) {
    final byDoctor = <String, List<FreeSlot>>{};
    for (final slot in source ?? const <FreeSlot>[]) {
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
      final lastMinute = ClinicTime.at(
        slot.endTime,
      ).subtract(const Duration(minutes: 1));
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

  // Slots by period, each in start order.
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

/// The treatment filter, owning its controller.
class _TreatmentField extends StatefulWidget {
  const _TreatmentField({
    required this.treatments,
    required this.alreadyInVisit,
    required this.selected,
    required this.onChanged,
  });

  final List<Treatment> treatments;
  final Set<String> alreadyInVisit;
  final Treatment? selected;
  final ValueChanged<Treatment?> onChanged;

  @override
  State<_TreatmentField> createState() => _TreatmentFieldState();
}

class _TreatmentFieldState extends State<_TreatmentField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.selected?.label ?? '',
  );

  final MenuController _menu = MenuController();
  final FocusNode _focus = FocusNode();

  /// Set while the field mirrors a selection.
  bool _syncing = false;

  /// Null means every category.
  String? _category;

  bool get _empty => _controller.text.isEmpty;

  // Catalogue order, one entry per category.
  List<String> get _categories {
    final seen = <String>[];
    for (final treatment in widget.treatments) {
      if (!seen.contains(treatment.category)) seen.add(treatment.category);
    }
    return seen;
  }

  // Typed text narrows, unless naming the pick.
  List<Treatment> get _visible {
    final query = _controller.text.trim().toLowerCase();
    final chosen = widget.selected?.label.toLowerCase();
    final typed = query.isEmpty || query == chosen ? '' : query;
    return widget.treatments.where((treatment) {
      final inCategory = _category == null || treatment.category == _category;
      final matches =
          typed.isEmpty || treatment.label.toLowerCase().contains(typed);
      return inCategory && matches;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  // Emptied by hand drops the filter.
  void _onTextChanged() {
    if (_syncing) return;
    setState(() {});
    if (_empty && widget.selected != null) {
      widget.onChanged(null);
    }
  }

  // Mirrors a selection without re-entering the listener.
  void _setText(String text) {
    _syncing = true;
    _controller.text = text;
    _syncing = false;
  }

  void _select(Treatment treatment) {
    _setText(treatment.label);
    _menu.close();
    widget.onChanged(treatment);
  }

  // Clears typed text and selection.
  void _clear() {
    _setText('');
    setState(() {});
    widget.onChanged(null);
  }

  // Typed text compounds with a narrowed list.
  void _pickCategory(String? category) {
    setState(() {
      _category = category;
      if (category != null) _setText('');
    });
    if (category != null && widget.selected != null) {
      widget.onChanged(null);
    }
  }

  // A selection made elsewhere reaches the field.
  @override
  void didUpdateWidget(covariant _TreatmentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final label = widget.selected?.label ?? '';
    if (widget.selected != oldWidget.selected && _controller.text != label) {
      _setText(label);
    }
    // A selection outside the filter hides itself.
    if (widget.selected != null && widget.selected!.category != _category) {
      _category = null;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Pinned above the list, outside its scroll.
  Widget _categoryBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          _categoryChip('All', _category == null, () => _pickCategory(null)),
          for (final category in _categories) ...[
            const SizedBox(width: 6),
            _categoryChip(
              humanizeEnum(category),
              _category == category,
              () => _pickCategory(category),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryChip(String label, bool active, VoidCallback onTap) {
    return Material(
      color: active ? AppColors.rosePale : AppColors.bgAlt,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.borderRose : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall(
              color: active ? AppColors.roseDark : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _treatmentItem(Treatment treatment) {
    final held = widget.alreadyInVisit.contains(treatment.name);
    return MenuItemButton(
      // Once a visit, so row says why.
      onPressed: held ? null : () => _select(treatment),
      leadingIcon: Icon(
        held ? Icons.check_circle_outline : Icons.spa_outlined,
        size: 18,
        color: held ? AppColors.sage : AppColors.rose,
      ),
      trailingIcon: Text(
        held ? 'in this visit' : '${treatment.durationMinutes} min',
        style: AppTypography.bodySmall(),
      ),
      style: MenuItemButton.styleFrom(
        minimumSize: const Size.fromHeight(36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: AppTypography.bodyMedium(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(treatment.label),
    );
  }

  Widget _clearButton() {
    return IconButton(
      icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
      tooltip: 'Clear treatment',
      splashRadius: 18,
      onPressed: _clear,
    );
  }

  Widget _field() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return TextField(
      controller: _controller,
      focusNode: _focus,
      style: AppTypography.bodyMedium(),
      onTap: _menu.open,
      // The magnifier now really filters.
      onChanged: (_) {
        if (!_menu.isOpen) _menu.open();
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.bgCard,
        hintText: 'Search treatments',
        hintStyle: AppTypography.bodyMedium(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.rose),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        // Empty field has nothing to clear.
        suffixIcon: _empty
            ? IconButton(
                icon: Icon(
                  _menu.isOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                ),
                onPressed: () => _menu.isOpen ? _menu.close() : _menu.open(),
              )
            : _clearButton(),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.rose),
        ),
      ),
    );
  }

  // Own scroll, so the bar stays put.
  Widget _menuPanel(double width) {
    final visible = _visible;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _categoryBar(),
          const Divider(height: 1, color: AppColors.hairline),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            // Own scroll position, not the page's.
            child: SingleChildScrollView(
              primary: false,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Text(
                        'No treatments in this category.',
                        style: AppTypography.bodySmall(),
                      ),
                    ),
                  for (final treatment in visible) _treatmentItem(treatment),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Menu is sized to its field.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MenuAnchor(
          controller: _menu,
          alignmentOffset: const Offset(0, 4),
          // Repaints the chevron, which reads the menu.
          onOpen: () => setState(() {}),
          onClose: () => setState(() {}),
          style: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.bgCard),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(4),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 4),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          menuChildren: [_menuPanel(width)],
          builder: (context, controller, child) => _field(),
        );
      },
    );
  }
}
