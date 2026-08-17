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
    this.initialSessions = const [],
    this.onBooked,
  });

  final TreatmentApi treatmentApi;
  final AppointmentApi appointmentApi;
  final DoctorApi doctorApi;

  final String? replacesAppointmentId;

  /// Kept as-is; a new day drops them.
  final List<AppointmentSession> initialSessions;
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

  /// Open time before treatment narrows it.
  List<FreeSlot>? _openSlots;
  bool _slotsLoading = false;
  String? _slotsError;
  int _slotRequest = 0; // newest slot search; older replies are dropped

  final List<BookingCartItem> _cart = [];

  /// Snapshot of reschedule's start, to detect edits.
  List<BookingCartItem> _keptCart = const [];
  String? _reviewError;

  /// Why the last confirm failed.
  String? _conflictMessage;
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
      // One wait; a failure can't orphan others.
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
      // Unset on purpose; patient picks, not inherits.
      _selectedTreatment = null;

      if (!patient.healthFormComplete) {
        setState(() => _step = _Step.gateBlocked);
        return;
      }

      _cart.addAll(_keptCartItems(treatments));
      _keptCart = List.of(_cart);
      if (_cart.isNotEmpty) {
        // Clinic day, not UTC.
        final day = ClinicTime.at(_cart.first.slot.startTime);
        _selectedDay = DateTime(day.year, day.month, day.day);
      }

      if (_cart.isNotEmpty) {
        setState(() => _step = _Step.review);
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

  // Rebuilds cart; missing treatments are dropped.
  List<BookingCartItem> _keptCartItems(List<Treatment> treatments) {
    final byName = {for (final t in treatments) t.name: t};
    return [
      for (final session in widget.initialSessions)
        if (byName[session.treatmentName] case final treatment?)
          BookingCartItem(
            treatment: treatment,
            slot: FreeSlot(
              practitionerUserId: session.practitionerUserId,
              practitionerName: session.practitionerName,
              startTime: session.startTime,
              endTime: session.endTime,
            ),
          ),
    ];
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _step = _Step.fatalError;
      _fatalMessage = message;
    });
  }

  // Consultation is shortest; best free-time proxy.
  Treatment? get _probeTreatment {
    if (_treatments.isEmpty) return null;
    for (final treatment in _treatments) {
      if (treatment.name == 'CONSULTATION') return treatment;
    }
    return _treatments.reduce(
      (a, b) => a.durationMinutes <= b.durationMinutes ? a : b,
    );
  }

  Future<void> _loadSlots() async {
    // No treatment yet; probe shows open time.
    final probing = _selectedTreatment == null;
    final treatment = _selectedTreatment ?? _probeTreatment;
    if (treatment == null) return;
    final request = ++_slotRequest;
    setState(() {
      if (probing) {
        _openSlots = null;
      } else {
        _slots = null;
      }
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
        if (probing) {
          _openSlots = slots;
        } else {
          _slots = slots;
        }
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

  // One visit, one day; reschedule excepted.
  void _selectDay(DateTime day) {
    final newDay = DateTime(day.year, day.month, day.day);
    if (newDay == _selectedDay) return;
    if (_cart.isNotEmpty) {
      if (!_isReschedule) return;
      _cart.clear();
    }
    setState(() => _selectedDay = newDay);
    _loadSlots();
  }

  // Null clears the field; shows full roster.
  void _selectTreatment(Treatment? treatment) {
    if (treatment?.name == _selectedTreatment?.name) return;
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
      _conflictMessage = null;
      _step = _Step.review;
    });
  }

  // Refetch drops held slots; clears stale selection.
  void _addAnother() {
    setState(() {
      _step = _Step.browse;
      _selectedTreatment = null;
    });
    _loadSlots();
  }

  /// Already in visit; shown greyed, not hidden.
  Set<String> get _alreadyInVisit =>
      _cart.map((item) => item.treatment.name).toSet();

  void _removeCartItem(int index) {
    setState(() {
      _cart.removeAt(index);
      if (_cart.isEmpty) _step = _Step.browse;
    });
    // Empty cart releases its times; refetch.
    if (_cart.isEmpty) _loadSlots();
  }

  // Nothing changed; nothing to submit.
  bool get _unedited => _isReschedule && _sameCartContents(_cart, _keptCart);

  static bool _sameCartContents(
    List<BookingCartItem> a,
    List<BookingCartItem> b,
  ) {
    if (a.length != b.length) return false;
    String signature(BookingCartItem item) =>
        '${item.treatment.name}@${item.slot.practitionerUserId}@'
        '${item.slot.startTime.toIso8601String()}';
    final sortedA = a.map(signature).toList()..sort();
    final sortedB = b.map(signature).toList()..sort();
    for (var i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  // ─── Submission ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Guards against a second tap firing twice.
    if (_submitting) return;
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
      _handleConflict(error.message, error.treatmentName);
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

  // Drops the lost pick, then browses again.
  void _handleConflict(String message, String? treatmentName) {
    if (!mounted) return;

    final lost = _treatmentNamed(treatmentName);

    // Visit-wide refusal: nothing to re-pick.
    if (lost == null) {
      _submitFail(message);
      return;
    }

    setState(() {
      _submitting = false;
      _reviewError = null;
      _conflictMessage = message;
      _cart.removeWhere((item) => item.treatment.name == lost.name);
      // Preselected, so the next pick replaces it.
      _selectedTreatment = lost;
      _step = _Step.browse;
    });
    _loadSlots();
  }

  Treatment? _treatmentNamed(String? name) {
    if (name == null) return null;

    for (final treatment in _treatments) {
      if (treatment.name == name) return treatment;
    }
    return null;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  bool get _fillsHeight => _step == _Step.browse;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: AppColors.bgCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        // Browse needs width; other steps stay narrow.
        constraints: BoxConstraints(
          maxWidth: _fillsHeight ? 1000 : 480,
          maxHeight: size.height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // Only browse needs full height.
            mainAxisSize: _fillsHeight ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _header(),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 12),
              if (_fillsHeight)
                Expanded(child: _body())
              else
                Flexible(child: _body()),
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

  // Names the lost slot above fresh times.
  Widget _withConflictBanner(Widget browse) {
    final message = _conflictMessage;
    if (message == null) return browse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookingErrorBanner(message: message),
        const SizedBox(height: 12),
        Expanded(child: browse),
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
        return _withConflictBanner(
          BookingBrowseStep(
            today: _today,
            selectedDay: _selectedDay,
            maxHorizonDays: _rules?.maxHorizonDays ?? 180,
            treatments: _treatments,
            alreadyInVisit: _alreadyInVisit,
            selectedTreatment: _selectedTreatment,
            slots: _slots,
            openSlots: _openSlots,
            slotsLoading: _slotsLoading,
            slotsError: _slotsError,
            // Reschedule may change day; costs kept cart.
            dayLocked: !_isReschedule && _cart.isNotEmpty,
            isReschedule: _isReschedule,
            doctorsById: _doctorsById,
            viewByDoctor: _viewByDoctor,
            chosenDoctorId: _chosenDoctorId,
            onDayChanged: _selectDay,
            onTreatmentChanged: _selectTreatment,
            onViewChanged: _selectView,
            onDoctorChosen: _chooseDoctor,
            onSlotChosen: _chooseSlot,
            onRetrySlots: _loadSlots,
          ),
        );
      case _Step.review:
        return BookingReviewStep(
          items: _cart,
          submitting: _submitting,
          isReschedule: _isReschedule,
          unedited: _unedited,
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
