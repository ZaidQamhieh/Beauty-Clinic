import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../network/api_client.dart';
import '../data/appointment.dart';
import '../data/appointment_api.dart';
import '../data/booking_exceptions.dart';
import '../data/booking_patient.dart';
import '../data/booking_rules.dart';
import '../data/clinic_time.dart';
import '../data/doctor_api.dart';
import '../data/doctor_summary.dart';
import '../data/free_slot.dart';
import '../data/treatment.dart';
import '../data/treatment_api.dart';
import 'booking_browse_step.dart';
import 'booking_result_steps.dart';
import 'booking_review_step.dart';

/// The booking flow: pick treatment, doctor, time.
class BookingFlowSheet extends StatefulWidget {
  const BookingFlowSheet({
    super.key,
    required this.treatmentApi,
    required this.appointmentApi,
    required this.doctorApi,
    this.replacesAppointmentId,
    this.onBooked,
  });

  final TreatmentApi treatmentApi;
  final AppointmentApi appointmentApi;
  final DoctorApi doctorApi;

  final String? replacesAppointmentId;
  final ValueChanged<Appointment>? onBooked;

  @override
  State<BookingFlowSheet> createState() => _BookingFlowSheetState();
}

enum _Step { loading, gateBlocked, fatalError, browse, review, success }

class _BookingFlowSheetState extends State<BookingFlowSheet> {
  _Step _step = _Step.loading;
  String _fatalMessage = '';

  BookingPatient? _patient;
  List<Treatment> _treatments = const [];
  BookingRules? _rules;
  Map<String, DoctorSummary> _doctorsById = const {};

  Treatment? _selectedTreatment;
  late DateTime _today;
  late DateTime _selectedDay;
  bool _viewByDoctor = true;
  String? _chosenDoctorId; // by-doctor step two: a doctor was chosen

  List<FreeSlot>? _slots;
  bool _slotsLoading = false;
  String? _slotsError;
  int _slotRequest = 0; // newest slot search; older replies are dropped

  final List<BookingCartItem> _cart = [];
  String? _reviewError;
  bool _submitting = false;

  Appointment? _booked;

  bool get _isReschedule => widget.replacesAppointmentId != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // ─── Loading ──────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    setState(() {
      _step = _Step.loading;
      _fatalMessage = '';
    });
    try {
      // One wait, so a first failure cannot orphan the rest.
      final results = await Future.wait([
        widget.appointmentApi.me(),
        widget.treatmentApi.list(),
        widget.treatmentApi.rules(),
        widget.doctorApi.list(),
      ]);
      if (!mounted) return;

      final patient = results[0] as BookingPatient;
      final treatments = results[1] as List<Treatment>;
      final rules = results[2] as BookingRules;
      final doctors = results[3] as List<DoctorSummary>;

      _patient = patient;
      _treatments = treatments;
      _rules = rules;
      ClinicTime.use(rules.timezone);
      final clinicNow = ClinicTime.at(DateTime.now());
      _today = DateTime(clinicNow.year, clinicNow.month, clinicNow.day);
      _selectedDay = _today;
      _doctorsById = {for (final d in doctors) d.userId: d};
      _selectedTreatment = _treatments.isNotEmpty ? _treatments.first : null;

      if (!patient.healthFormComplete) {
        setState(() => _step = _Step.gateBlocked);
        return;
      }
      setState(() => _step = _Step.browse);
      _loadSlots();
    } on ForbiddenException {
      _fail('Only patients can book from here.');
    } catch (_) {
      _fail('Could not reach the clinic. Check your connection and try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _step = _Step.fatalError;
      _fatalMessage = message;
    });
  }

  Future<void> _loadSlots() async {
    final treatment = _selectedTreatment;
    if (treatment == null) return;
    final request = ++_slotRequest;
    setState(() {
      _slots = null;
      _slotsError = null;
      _slotsLoading = true;
      _chosenDoctorId = null;
    });
    try {
      final slots = await widget.appointmentApi.freeSlots(
        treatmentName: treatment.name,
        date: _selectedDay,
        patientUserId: _patient!.userId,
        held: _cart.map((item) => item.held).toList(),
        replacesAppointmentId: widget.replacesAppointmentId,
      );
      if (!mounted || request != _slotRequest) return;
      setState(() {
        _slots = slots;
        _slotsLoading = false;
      });
    } on ForbiddenException {
      _slotFail('You can only search your own diary.', request);
    } catch (_) {
      _slotFail('Could not load times. Tap to try again.', request);
    }
  }

  void _slotFail(String message, int request) {
    if (!mounted || request != _slotRequest) return;
    setState(() {
      _slotsLoading = false;
      _slotsError = message;
    });
  }

  // ─── Browse choices ───────────────────────────────────────────────────────

  // One visit is one day, so a held cart pins it.
  void _selectDay(DateTime day) {
    if (_cart.isNotEmpty) return;
    setState(() => _selectedDay = DateTime(day.year, day.month, day.day));
    _loadSlots();
  }

  void _selectTreatment(Treatment? treatment) {
    if (treatment == null || treatment.name == _selectedTreatment?.name) return;
    setState(() => _selectedTreatment = treatment);
    _loadSlots();
  }

  void _selectView(bool byDoctor) => setState(() => _viewByDoctor = byDoctor);

  void _chooseDoctor(String? doctorId) =>
      setState(() => _chosenDoctorId = doctorId);

  // ─── Cart ─────────────────────────────────────────────────────────────────

  void _chooseSlot(FreeSlot slot) {
    setState(() {
      _cart.add(BookingCartItem(treatment: _selectedTreatment!, slot: slot));
      _reviewError = null;
      _step = _Step.review;
    });
  }

  // Refetch, so held slots drop out.
  void _addAnother() {
    setState(() => _step = _Step.browse);
    _loadSlots();
  }

  void _removeCartItem(int index) {
    setState(() {
      _cart.removeAt(index);
      if (_cart.isEmpty) _step = _Step.browse;
    });
    // An empty cart releases its times, so refetch.
    if (_cart.isEmpty) _loadSlots();
  }

  // ─── Submission ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _reviewError = null;
    });
    try {
      final appointment = await widget.appointmentApi.book(
        patientUserId: _patient!.userId,
        sessions: _cart.map((item) => item.draft).toList(),
        replacesAppointmentId: widget.replacesAppointmentId,
      );
      if (!mounted) return;
      _booked = appointment;
      widget.onBooked?.call(appointment);
      setState(() {
        _submitting = false;
        _step = _Step.success;
      });
    } on BookingConflictException catch (error) {
      _handleConflict(error.message);
    } on BookingValidationException catch (error) {
      _submitFail(error.message);
    } on ForbiddenException {
      _submitFail('You are not allowed to make this booking.');
    } catch (_) {
      _submitFail('Could not reach the clinic. Try again.');
    }
  }

  void _submitFail(String message) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _reviewError = message;
    });
  }

  // The cart stands; the patient decides. Add another refetches.
  void _handleConflict(String message) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _reviewError = message;
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: AppColors.bgCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1000,
          maxHeight: size.height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 12),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'APPOINTMENT BOOKING',
                style: AppTypography.labelSmall(color: AppColors.rose),
              ),
              const SizedBox(height: 4),
              Text(
                _isReschedule
                    ? 'Reschedule Session'
                    : 'Schedule Treatment Session',
                style: AppTypography.displayTitle(color: AppColors.text),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.cancel_outlined, color: AppColors.textMuted),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.loading:
        return const Center(child: CircularProgressIndicator());
      case _Step.fatalError:
        return BookingMessage(
          icon: Icons.error_outline,
          text: _fatalMessage,
          onRetry: _bootstrap,
        );
      case _Step.gateBlocked:
        return BookingGateStep(onClose: () => Navigator.of(context).pop());
      case _Step.browse:
        return BookingBrowseStep(
          today: _today,
          selectedDay: _selectedDay,
          maxHorizonDays: _rules?.maxHorizonDays ?? 180,
          treatments: _treatments,
          selectedTreatment: _selectedTreatment,
          slots: _slots,
          slotsLoading: _slotsLoading,
          slotsError: _slotsError,
          dayLocked: _cart.isNotEmpty,
          doctorsById: _doctorsById,
          viewByDoctor: _viewByDoctor,
          chosenDoctorId: _chosenDoctorId,
          onDayChanged: _selectDay,
          onTreatmentChanged: _selectTreatment,
          onViewChanged: _selectView,
          onDoctorChosen: _chooseDoctor,
          onSlotChosen: _chooseSlot,
          onRetrySlots: _loadSlots,
        );
      case _Step.review:
        return BookingReviewStep(
          items: _cart,
          submitting: _submitting,
          isReschedule: _isReschedule,
          errorMessage: _reviewError,
          onRemove: _removeCartItem,
          onAddAnother: _addAnother,
          onSubmit: _submit,
        );
      case _Step.success:
        return BookingSuccessStep(
          appointment: _booked!,
          isReschedule: _isReschedule,
          onDone: () => Navigator.of(context).pop(true),
        );
    }
  }
}
