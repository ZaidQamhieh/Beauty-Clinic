import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/doctor_summary.dart';
import '../data/free_slot.dart';
import '../data/treatment.dart';
import 'booking_slots_panel.dart';
import 'booking_treatment_field.dart';

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
        if (!dayLocked && isReschedule && alreadyInVisit.isNotEmpty) ...[
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
    return BookingTreatmentField(
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

  Widget _rightPanel() {
    return BookingSlotsPanel(
      selectedDay: selectedDay,
      selectedTreatment: selectedTreatment,
      slots: slots,
      takenSlot: takenSlot,
      openSlots: openSlots,
      slotsLoading: slotsLoading,
      slotsError: slotsError,
      doctorsById: doctorsById,
      viewByDoctor: viewByDoctor,
      chosenDoctorId: chosenDoctorId,
      onDoctorChosen: onDoctorChosen,
      onSlotChosen: onSlotChosen,
      onRetrySlots: onRetrySlots,
    );
  }
}
