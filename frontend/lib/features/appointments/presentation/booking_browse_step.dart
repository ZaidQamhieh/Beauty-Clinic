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
    required this.alreadyInVisit,
    required this.selectedTreatment,
    required this.slots,
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

  /// Treatment names already held in the visit, offered greyed out.
  final Set<String> alreadyInVisit;
  final Treatment? selectedTreatment;

  final List<FreeSlot>? slots;

  /// Open time shown before a treatment narrows the roster. Not bookable: a
  /// slot is only real once measured in the chosen treatment's own length.
  final List<FreeSlot>? openSlots;
  final bool slotsLoading;
  final String? slotsError;

  /// True once a treatment is held, pinning the visit to its day.
  final bool dayLocked;

  /// Reschedule may change day; drops the kept cart.
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
          // Stretched, so the left column is height-bounded and its calendar can fill.
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

  // fill: the column owns a bounded height, so the calendar takes what is left
  // rather than running past the panel and forcing a scroll to reach its end.
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
        // Laid out after the fixed children, so the note below keeps its space.
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
      // Unset when filling: the Expanded above hands down the height.
      height: fill ? null : 320,
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
    // Unfiltered: the whole roster, since no treatment has narrowed it yet.
    if (selectedTreatment == null) return _directory();
    final free = slots ?? const <FreeSlot>[];
    if (free.isEmpty) {
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

  // ─── Unfiltered: every doctor, before a treatment narrows them ────────────

  // Open time comes from the shortest treatment everyone qualifies for, so it
  // reads as "when this doctor is free" rather than as bookable slots.
  Widget _directory() {
    final open = openSlots ?? const <FreeSlot>[];

    // The toggle still decides the shape; only the source of the times differs.
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
                // Hover a block to see its hour range.
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

  // An hour per row, empty ones kept: a gap in the day is information, and
  // pills alone left it to be inferred from times that were simply missing.
  Widget _agenda(List<FreeSlot> slots) {
    final byHour = <int, List<FreeSlot>>{};
    for (final slot in slots) {
      byHour
          .putIfAbsent(ClinicTime.at(slot.startTime).hour, () => [])
          .add(slot);
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
                            for (final slot in byHour[hour]!) _timeChip(slot),
                          ],
                        ),
                ),
              ],
            ),
          ),
      ],
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

  // ─── By time: chronological cards grouped by period ────────────────────────

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
    _groupByPeriod(slots).forEach((label, list) {
      if (list.isEmpty) return;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(label, style: AppTypography.labelSmall()),
        ),
      );
      for (final slot in list) {
        children.add(_slotCard(slot));
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _slotCard(FreeSlot slot) {
    final treatment = selectedTreatment;
    final doctor = doctorsById[slot.practitionerUserId];
    // Unfiltered, the row is a free time and nothing more: no work is planned
    // for it, so naming a speciality or a length would invent one.
    final specialty =
        treatment != null && (doctor?.categoryTags.isNotEmpty ?? false)
        ? doctor!.categoryTags.first
        : '';
    final duration = treatment?.durationMinutes;
    final subtitle = [
      if (specialty.isNotEmpty) specialty,
      if (duration != null) '$duration min',
    ].join(' · ');

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
            child: Text(
              BookingFormat.time12(slot.startTime),
              style: AppTypography.labelMedium(color: AppColors.roseDark),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.practitionerName, style: AppTypography.labelLarge()),
                // Dropped rather than left blank, so the row closes up.
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppTypography.bodySmall()),
              ],
            ),
          ),
          // Booking needs a treatment: the cart item is built from one.
          if (selectedTreatment != null)
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

/// The treatment filter. Stateful only to own the field's controller, which is
/// what makes clearing the text mean "no treatment" rather than nothing at all.
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

  late bool _empty = _controller.text.isEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  // Emptied by hand: drop the filter and show the whole roster again.
  void _onTextChanged() {
    final empty = _controller.text.isEmpty;

    // Only on the edge, so the trailing icon swaps without rebuilding per keystroke.
    if (empty != _empty) {
      setState(() => _empty = empty);
    }
    if (empty && widget.selected != null) {
      widget.onChanged(null);
    }
  }

  // Clears a typed filter as well as a selection: both live in this field.
  void _clear() {
    _controller.clear();
    widget.onChanged(null);
  }

  // A selection made elsewhere still has to reach the field.
  @override
  void didUpdateWidget(covariant _TreatmentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final label = widget.selected?.label ?? '';
    if (widget.selected != oldWidget.selected && _controller.text != label) {
      _controller.text = label;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Widget _clearButton() {
    return IconButton(
      icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
      tooltip: 'Clear treatment',
      splashRadius: 18,
      onPressed: _clear,
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return DropdownMenu<Treatment>(
      controller: _controller,
      initialSelection: widget.selected,
      // The magnifier promised filtering the old dropdown never did.
      enableFilter: true,
      requestFocusOnTap: true,
      expandedInsets: EdgeInsets.zero,
      hintText: 'Search treatments',
      leadingIcon: const Icon(Icons.search, size: 16, color: AppColors.rose),
      textStyle: AppTypography.bodyMedium(),
      // Nothing to clear when the field is empty, so the chevron stands in.
      trailingIcon: _empty
          ? const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted)
          : _clearButton(),
      selectedTrailingIcon: _empty
          ? const Icon(Icons.keyboard_arrow_up, color: AppColors.textMuted)
          : _clearButton(),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.rose),
        ),
      ),
      // Uncapped on purpose. DropdownMenu never calls its own scrollToHighlight,
      // so arrow keys walk the highlight out of a scrolling menu and it stays put.
      // The catalogue is short enough to show whole, which sidesteps it.
      menuStyle: MenuStyle(
        // Hangs off the field's bottom edge instead of floating over it.
        alignment: Alignment.bottomLeft,
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
      dropdownMenuEntries: [
        for (final treatment in widget.treatments)
          DropdownMenuEntry(
            value: treatment,
            // Name only, so typing filters on the treatment and not on its length.
            label: treatment.label,
            // A treatment is done once a visit, so its own row says why.
            enabled: !widget.alreadyInVisit.contains(treatment.name),
            leadingIcon: Icon(
              widget.alreadyInVisit.contains(treatment.name)
                  ? Icons.check_circle_outline
                  : Icons.spa_outlined,
              size: 18,
              color: widget.alreadyInVisit.contains(treatment.name)
                  ? AppColors.sage
                  : AppColors.rose,
            ),
            trailingIcon: Text(
              widget.alreadyInVisit.contains(treatment.name)
                  ? 'in this visit'
                  : '${treatment.durationMinutes} min',
              style: AppTypography.bodySmall(),
            ),
            style: MenuItemButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: AppTypography.bodyMedium(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
      onSelected: widget.onChanged,
    );
  }
}
