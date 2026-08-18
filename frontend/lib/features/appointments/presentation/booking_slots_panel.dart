import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/clinic_time.dart';
import '../data/doctor_summary.dart';
import '../data/free_slot.dart';
import '../data/treatment.dart';
import 'booking_format.dart';
import 'booking_slot_groups.dart';
import 'booking_result_steps.dart';

/// Browse's times half: who, and when.
class BookingSlotsPanel extends StatelessWidget {
  const BookingSlotsPanel({
    super.key,
    required this.selectedDay,
    required this.selectedTreatment,
    required this.slots,
    required this.takenSlot,
    required this.openSlots,
    required this.slotsLoading,
    required this.slotsError,
    required this.doctorsById,
    required this.viewByDoctor,
    required this.chosenDoctorId,
    required this.onDoctorChosen,
    required this.onSlotChosen,
    required this.onRetrySlots,
  });

  final DateTime selectedDay;
  final Treatment? selectedTreatment;

  final List<FreeSlot>? slots;

  /// Lost to another booking; offered disabled.
  final FreeSlot? takenSlot;

  /// Open time before treatment narrows roster.
  final List<FreeSlot>? openSlots;
  final bool slotsLoading;
  final String? slotsError;

  final Map<String, DoctorSummary> doctorsById;
  final bool viewByDoctor;

  /// Set once a doctor is picked.
  final String? chosenDoctorId;

  /// Null steps back to all doctors.
  final ValueChanged<String?> onDoctorChosen;
  final ValueChanged<FreeSlot> onSlotChosen;
  final VoidCallback onRetrySlots;

  @override
  Widget build(BuildContext context) => _rightPanel();

  Widget _rightPanel() {
    if (slotsLoading) {
      return const BookingSlotsSkeleton();
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

    final byDoctor = groupByDoctor(open);

    final roster = doctorsById.values.toList()
      ..sort((a, b) {
        final free = freeHours(
          byDoctor[b.userId] ?? const [],
        ).length.compareTo(freeHours(byDoctor[a.userId] ?? const []).length);
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
    final openHours = freeHours(open).length;

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
              if (open.isNotEmpty) _hoursBadge(openHours),
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
    final byDoctor = groupByDoctor(slots);
    final ids = byDoctor.keys.toList()
      ..sort(
        (a, b) => freeHours(
          byDoctor[b]!,
        ).length.compareTo(freeHours(byDoctor[a]!).length),
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
    final openHours = freeHours(slots).length;
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
              _hoursBadge(openHours),
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
    final free = freeHours(slots);
    final (start, end) = timelineSpan(slots);
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
    final doctorSlots = groupByDoctor(slots)[doctorId] ?? const <FreeSlot>[];
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
        _agenda(doctorSlots),
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
    groupByPeriod(rows).forEach((label, list) {
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
}
