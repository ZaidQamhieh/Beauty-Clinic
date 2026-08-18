package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.dtos.AddSessionRequest;
import com.example.backend.dtos.AppointmentResponse;
import com.example.backend.dtos.AppointmentSessionResponse;
import com.example.backend.dtos.BookAppointmentRequest;
import com.example.backend.dtos.DayVersionResponse;
import com.example.backend.dtos.FreeSlotQuery;
import com.example.backend.dtos.FreeSlotResponse;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.Appointment.AppointmentStatus;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.CurrentUser;
import com.example.backend.security.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

// Visits only; sessions live elsewhere.
@Service
@RequiredArgsConstructor
public class AppointmentService {

    private final AppointmentRepository appointments;
    private final AppointmentSessionRepository sessions;
    private final AppointmentSessionService sessionService;
    private final DoctorAvailabilityService availability;
    private final PatientProfileRepository patients;
    private final DoctorProfileRepository doctors;
    private final UserAccountRepository users;
    private final CurrentUser currentUser;
    private final ClinicProperties clinic;
    private final ActivityLogService activityLogs;
    private final CancellationPolicy cancellation;
    private final Clock clock;

    @Transactional
    public AppointmentResponse book(BookAppointmentRequest request) {
        // Doctor, admin, patient; patient self only.
        if (currentUser.hasRole(Role.PATIENT) && !currentUser.is(request.patientUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Patients may only book for themselves");
        }

        // Appointment before patient, or deadlock.
        Appointment replaced = lockReplaced(request.replacesAppointmentId(), request.patientUserId());

        // Appointment lock, taken before the patient's.
        Appointment sameDay = lockVisitThatDay(request, replaced);

        // Locked next; the seen list ages.
        PatientProfile patient = patients.lockForBooking(request.patientUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));

        // Doctor reads it before treating.
        if (!patient.hasCompletedHealthForm()) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "The patient's health form is not filled in");
        }

        // Patient lock serialises, so re-read here.
        assertDayUnchangedUnderLock(request, replaced, sameDay);

        // Both visits move, or neither.
        releaseReplaced(replaced);

        // Earliest first, checked against placed.
        List<AddSessionRequest> requested = request.sessions().stream()
                .sorted(Comparator.comparing(AddSessionRequest::startTime))
                .toList();

        assertVisitFitsOneDay(requested);
        assertVisitDoesNotClashWithItself(requested);
        assertOneOfEachTreatment(requested);
        lockPractitioners(requested);

        // One day is one visit, so join.
        boolean joining = sameDay != null;

        // Joining edits a visit already held.
        if (joining) {
            cancellation.assertEditable(sameDay.getScheduledAt());
        }

        Appointment appointment = joining
                ? sameDay
                : newVisit(patient, requested.get(0).startTime(), replaced);

        List<AppointmentSessionResponse> booked = requested.stream()
                .map(session -> AppointmentSessionResponse.of(sessionService.schedule(appointment, session)))
                .toList();

        // Joined visit was already booked.
        if (!joining) {
            record(replaced == null
                    ? ActivityAction.APPOINTMENT_BOOKED
                    : ActivityAction.APPOINTMENT_RESCHEDULED, appointment);
        }

        // Whole day, so a join answers fully.
        return AppointmentResponse.of(appointment, joining ? liveSessionsOf(appointment) : booked);
    }

    private Appointment newVisit(PatientProfile patient, Instant startTime, Appointment replaced) {
        Appointment appointment = new Appointment(patient, startTime);
        currentUser.id().ifPresent(id -> appointment.setCreatedBy(users.getReferenceById(id)));
        appointment.setReplaces(replaced);
        appointments.save(appointment);
        return appointment;
    }

    private List<AppointmentSessionResponse> liveSessionsOf(Appointment appointment) {
        return sessions.findByAppointmentId(appointment.getId()).stream()
                .filter(session -> session.getStatus() != SessionStatus.CANCELLED)
                .sorted(Comparator.comparing(AppointmentSession::getStartTime))
                .map(AppointmentSessionResponse::of)
                .toList();
    }

    // Null when day free; visit to join.
    private Appointment lockVisitThatDay(BookAppointmentRequest request, Appointment replaced) {
        List<UUID> ids = bookedIdsThatDay(request, replaced);

        if (ids.isEmpty()) {
            return null;
        }

        return appointments.findWithLockById(ids.get(0))
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "No such appointment"));
    }

    // Read before the lock may be stale.
    private void assertDayUnchangedUnderLock(
            BookAppointmentRequest request, Appointment replaced, Appointment locked) {
        List<UUID> ids = bookedIdsThatDay(request, replaced);

        UUID held = locked == null ? null : locked.getId();
        UUID actual = ids.isEmpty() ? null : ids.get(0);

        if (!Objects.equals(held, actual)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "That day's visit changed while this booking was being made. Try again.");
        }
    }

    private List<UUID> bookedIdsThatDay(BookAppointmentRequest request, Appointment replaced) {
        Instant earliest = request.sessions().stream()
                .map(AddSessionRequest::startTime)
                .min(Comparator.naturalOrder())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "A visit needs at least one treatment"));

        LocalDate day = earliest.atZone(clinic.zone()).toLocalDate();

        return appointments.findBookedIdsForPatientBetween(
                request.patientUserId(),
                startOfDay(day),
                startOfDay(day.plusDays(1)),
                replaced == null ? null : replaced.getId());
    }

    // Sorted by id, or two visits deadlock.
    private void lockPractitioners(List<AddSessionRequest> requested) {
        requested.stream()
                .map(AddSessionRequest::practitionerUserId)
                .distinct()
                .sorted()
                .forEach(doctors::lockForBooking);
    }

    // Not found, not forbidden; ownership hides.
    private Appointment lockReplaced(UUID replacedId, UUID patientUserId) {
        if (replacedId == null) {
            return null;
        }

        Appointment replaced = requireLocked(replacedId);

        if (!replaced.getPatient().getUserId().equals(patientUserId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment");
        }

        return replaced;
    }

    // Flushed, or old slots still block.
    private void releaseReplaced(Appointment replaced) {
        if (replaced == null) {
            return;
        }

        cancelVisit(replaced);
        appointments.flush();
    }

    @Transactional
    public AppointmentResponse cancel(UUID id) {
        Appointment appointment = requireLocked(id);
        cancelVisit(appointment);

        return withSessions(appointment);
    }

    // Drops the visit and pending treatments.
    private void cancelVisit(Appointment appointment) {
        assertBooked(appointment);
        cancellation.assertCancellable(appointment.getScheduledAt());

        appointment.cancel();
        sessionService.cancelEveryPlannedIn(appointment);

        record(ActivityAction.APPOINTMENT_CANCELLED, appointment);
    }

    @Transactional(readOnly = true)
    public AppointmentResponse read(UUID id) {
        return withSessions(require(id));
    }

    @Transactional(readOnly = true)
    public Page<AppointmentResponse> readOwnAsPatient(Pageable pageable) {
        return withSessions(
                appointments.findNotSupersededForPatient(currentUser.requireId(), pageable));
    }

    @Transactional(readOnly = true)
    public Page<AppointmentResponse> readOwnUpcoming(Pageable pageable) {
        return readUpcomingFor(currentUser.requireId(), pageable);
    }

    @Transactional(readOnly = true)
    public Page<AppointmentResponse> readOwnHistory(Pageable pageable) {
        return readHistoryFor(currentUser.requireId(), pageable);
    }

    // Booked, not yet started, soonest first.
    @Transactional(readOnly = true)
    public Page<AppointmentResponse> readUpcomingFor(UUID patientUserId, Pageable pageable) {
        return withSessions(appointments.findUpcomingForPatient(
                patientUserId, clock.instant(), pageable));
    }

    // Started or cancelled, most recent first.
    @Transactional(readOnly = true)
    public Page<AppointmentResponse> readHistoryFor(UUID patientUserId, Pageable pageable) {
        return withSessions(appointments.findHistoryForPatient(
                patientUserId, clock.instant(), pageable));
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> readOwnSchedule(LocalDate date) {
        return scheduleFor(currentUser.requireId(), date);
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> readSchedule(UUID doctorId, LocalDate date) {
        if (doctorId != null) {
            return scheduleFor(doctorId, date);
        }

        LocalDate day = dayOrToday(date);
        return sorted(appointments.findBetween(startOfDay(day), startOfDay(day.plusDays(1))).stream()
                .filter(a -> a.getStatus() == AppointmentStatus.BOOKED)
                .toList());
    }

    // Slots change only when sessions do.
    @Transactional(readOnly = true)
    public DayVersionResponse dayVersion(LocalDate date) {
        LocalDate day = dayOrToday(date);
        Object[] fingerprint = sessions.dayFingerprint(
                startOfDay(day), startOfDay(day.plusDays(1)));

        // Max is null on an empty day.
        long count = fingerprint[0] == null ? 0L : ((Number) fingerprint[0]).longValue();
        Instant changed = (Instant) fingerprint[1];

        return new DayVersionResponse(
                day, count + ":" + (changed == null ? "0" : changed.toEpochMilli()));
    }

    // Per treatment, across qualified doctors.
    @Transactional(readOnly = true)
    public List<FreeSlotResponse> freeSlots(FreeSlotQuery request) {
        FreeSlotQuery query = withDefaults(request);

        if (currentUser.hasRole(Role.PATIENT)
                && query.patientUserId() != null
                && !currentUser.is(query.patientUserId())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Patients may only search their own diary");
        }

        // Only a visit the caller may free.
        if (query.replacesAppointmentId() != null) {
            requireOwnAppointment(query.replacesAppointmentId());
        }

        List<DoctorProfile> qualified = qualifiedDoctors(query.doctorId(), query.treatmentName());
        if (qualified.isEmpty()) {
            return List.of();
        }

        LocalDate date = query.date();
        Duration duration = Duration.ofMinutes(clinic.tariffFor(query.treatmentName()).durationMinutes());
        Instant dayStart = startOfDay(date);
        Instant dayEnd = startOfDay(date.plusDays(1));

        Map<UUID, List<Instant[]>> doctorBusy = doctorBusyOn(qualified, query, dayStart, dayEnd);
        List<Instant[]> patientBusy = patientBusyOn(query, dayStart, dayEnd);

        // Whole roster at once, not per doctor.
        Map<UUID, List<TimeRange>> openWindows = availability.openWindowsOn(
                qualified.stream().map(DoctorProfile::getUserId).toList(), date);

        Instant now = clock.instant();
        Instant latest = now.plus(clinic.horizon());

        return qualified.stream()
                .flatMap(doctor -> slotsFor(
                        doctor,
                        date,
                        duration,
                        busyFor(doctor, query, doctorBusy, patientBusy),
                        openWindows.getOrDefault(doctor.getUserId(), List.of())).stream())
                .filter(slot -> !slot.startTime().isBefore(now) && !slot.startTime().isAfter(latest))
                // Never advertise what book() would reject.
                .filter(slot -> cancellation.leavesRoomToCancel(slot.startTime(), now))
                .sorted(Comparator.comparing(FreeSlotResponse::startTime)
                        .thenComparing(FreeSlotResponse::practitionerName))
                .toList();
    }

    // Omitted date means today, patient means caller.
    private FreeSlotQuery withDefaults(FreeSlotQuery query) {
        UUID patientUserId = query.patientUserId();
        if (patientUserId == null && currentUser.hasRole(Role.PATIENT)) {
            patientUserId = currentUser.requireId();
        }

        return new FreeSlotQuery(
                query.treatmentName(),
                dayOrToday(query.date()),
                query.doctorId(),
                patientUserId,
                query.held(),
                query.replacesAppointmentId());
    }

    // Unqualified named doctor offers nothing.
    private List<DoctorProfile> qualifiedDoctors(UUID doctorId, TreatmentName treatment) {
        if (doctorId != null) {
            DoctorProfile named = doctors.findById(doctorId)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));

            if (!treatment.category().qualifies(named.getSpecializations())) {
                return List.of();
            }
            return List.of(named);
        }

        return doctors.findAll().stream()
                .filter(doctor -> treatment.category().qualifies(doctor.getSpecializations()))
                .toList();
    }

    // Whole day, one read, every candidate.
    private Map<UUID, List<Instant[]>> doctorBusyOn(
            List<DoctorProfile> qualified, FreeSlotQuery query, Instant dayStart, Instant dayEnd
    ) {
        List<UUID> doctorIds = qualified.stream().map(DoctorProfile::getUserId).toList();

        // Every status but CANCELLED holds.
        return sessions.findForPractitionersBetween(doctorIds, dayStart, dayEnd).stream()
                .filter(s -> s.getStatus() != SessionStatus.CANCELLED)
                .filter(s -> stillHolds(s, query))
                .collect(Collectors.groupingBy(
                        s -> s.getPractitioner().getUserId(),
                        Collectors.mapping(
                                s -> withTurnover(s.getStartTime(), s.getEndTime()),
                                Collectors.toList())));
    }

    // Replaced visit releases its own times.
    private boolean stillHolds(AppointmentSession session, FreeSlotQuery query) {
        if (query.replacesAppointmentId() == null
                || !query.replacesAppointmentId().equals(session.getAppointment().getId())) {
            return true;
        }

        return session.getStatus() != SessionStatus.PLANNED;
    }

    // Patient holds block every doctor.
    private List<Instant[]> patientBusyOn(FreeSlotQuery query, Instant dayStart, Instant dayEnd) {
        List<Instant[]> busy = query.held().stream()
                .map(held -> new Instant[]{held.startTime(), held.endTime()})
                .collect(Collectors.toCollection(ArrayList::new));

        if (query.patientUserId() != null) {
            sessions.findForPatientBetween(query.patientUserId(), dayStart, dayEnd).stream()
                    .filter(s -> s.getStatus() != SessionStatus.CANCELLED)
                    .filter(s -> stillHolds(s, query))
                    .map(s -> new Instant[]{s.getStartTime(), s.getEndTime()})
                    .forEach(busy::add);
        }

        return busy;
    }

    private List<Instant[]> busyFor(
            DoctorProfile doctor,
            FreeSlotQuery query,
            Map<UUID, List<Instant[]>> doctorBusy,
            List<Instant[]> patientBusy
    ) {
        List<Instant[]> busy = new ArrayList<>(doctorBusy.getOrDefault(doctor.getUserId(), List.of()));

        // An earlier pick holds this chair.
        query.held().stream()
                .filter(held -> doctor.getUserId().equals(held.practitionerUserId()))
                .map(held -> withTurnover(held.startTime(), held.endTime()))
                .forEach(busy::add);

        busy.addAll(patientBusy);
        return busy;
    }

    private List<FreeSlotResponse> slotsFor(
            DoctorProfile doctor, LocalDate date, Duration duration, List<Instant[]> busy,
            List<TimeRange> openWindows
    ) {
        return openWindows.stream()
                .flatMap(window -> slotsWithin(doctor, date, window, duration, busy).stream())
                .toList();
    }

    private Instant[] withTurnover(Instant startTime, Instant endTime) {
        Duration turnover = clinic.turnover();
        return new Instant[]{startTime.minus(turnover), endTime.plus(turnover)};
    }

    // One treatment per visit; repeats are mistakes.
    private void assertOneOfEachTreatment(List<AddSessionRequest> requested) {
        Set<TreatmentName> seen = EnumSet.noneOf(TreatmentName.class);

        for (AddSessionRequest session : requested) {
            if (!seen.add(session.treatmentName())) {
                throw new ResponseStatusException(
                        HttpStatus.CONFLICT,
                        "That treatment is already in this visit");
            }
        }
    }

    // One trip; treatments share a day.
    private void assertVisitFitsOneDay(List<AddSessionRequest> requested) {
        LocalDate day = requested.get(0).startTime().atZone(clinic.zone()).toLocalDate();

        boolean sameDay = requested.stream()
                .allMatch(s -> s.startTime().atZone(clinic.zone()).toLocalDate().equals(day));

        if (!sameDay) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Every treatment in one visit must be on the same day");
        }
    }

    // Named here, not by a constraint.
    private void assertVisitDoesNotClashWithItself(List<AddSessionRequest> requested) {
        Duration turnover = clinic.turnover();

        for (int first = 0; first < requested.size(); first++) {
            AddSessionRequest earlier = requested.get(first);
            Instant earlierEnd = earlier.startTime().plus(lengthOf(earlier));

            for (int second = first + 1; second < requested.size(); second++) {
                AddSessionRequest later = requested.get(second);

                // Sorted by start; later one clashes.
                boolean sameDoctor = earlier.practitionerUserId().equals(later.practitionerUserId());
                Instant freeFrom = sameDoctor ? earlierEnd.plus(turnover) : earlierEnd;

                if (later.startTime().isBefore(freeFrom)) {
                    throw new ResponseStatusException(
                            HttpStatus.CONFLICT,
                            "Two treatments in this visit are booked over each other");
                }
            }
        }
    }

    private Duration lengthOf(AddSessionRequest request) {
        return Duration.ofMinutes(clinic.tariffFor(request.treatmentName()).durationMinutes());
    }

    // Who changed which visit, for whom.
    private void record(ActivityAction action, Appointment appointment) {
        activityLogs.recordAppointment(
                currentUser.id().orElse(null),
                appointment.getPatient().getUserId(),
                action,
                appointment.getId());
    }

    // Walks free stretches on the grid.
    private List<FreeSlotResponse> slotsWithin(
            DoctorProfile doctor, LocalDate date, TimeRange window, Duration duration, List<Instant[]> busy
    ) {
        Instant windowStart = date.atTime(window.start()).atZone(clinic.zone()).toInstant();
        Instant windowEnd = date.atTime(window.end()).atZone(clinic.zone()).toInstant();

        Duration stride = clinic.slotGranularity();
        List<FreeSlotResponse> free = new ArrayList<>();

        for (Instant[] gap : gapsIn(windowStart, windowEnd, busy)) {
            Instant cursor = onGrid(gap[0], stride);
            while (!cursor.plus(duration).isAfter(gap[1])) {
                free.add(new FreeSlotResponse(
                        doctor.getUserId(),
                        doctor.getUser().fullName(),
                        cursor,
                        cursor.plus(duration)));
                cursor = cursor.plus(stride);
            }
        }

        return free;
    }

    // Next grid mark from clinic midnight.
    private Instant onGrid(Instant candidate, Duration stride) {
        ZonedDateTime local = candidate.atZone(clinic.zone());
        ZonedDateTime midnight = local.toLocalDate().atStartOfDay(clinic.zone());

        long strideMinutes = stride.toMinutes();
        long elapsed = Duration.between(midnight, local).toMinutes();
        long marks = (elapsed + strideMinutes - 1) / strideMinutes;

        Instant aligned = midnight.plusMinutes(marks * strideMinutes).toInstant();

        // Never round down past the gap.
        if (aligned.isBefore(candidate)) {
            return candidate;
        }

        return aligned;
    }

    // Window minus what holds it.
    private List<Instant[]> gapsIn(Instant windowStart, Instant windowEnd, List<Instant[]> busy) {
        List<Instant[]> held = busy.stream()
                .filter(h -> h[0].isBefore(windowEnd) && h[1].isAfter(windowStart))
                .sorted(Comparator.comparing((Instant[] h) -> h[0]))
                .toList();

        List<Instant[]> gaps = new ArrayList<>();
        Instant cursor = windowStart;

        for (Instant[] taken : held) {
            if (taken[0].isAfter(cursor)) {
                gaps.add(new Instant[]{cursor, taken[0]});
            }
            // Bookings overlap; never walk backwards.
            if (taken[1].isAfter(cursor)) {
                cursor = taken[1];
            }
        }

        if (cursor.isBefore(windowEnd)) {
            gaps.add(new Instant[]{cursor, windowEnd});
        }

        return gaps;
    }

    // Deduped; only this practitioner's work.
    private List<AppointmentResponse> scheduleFor(UUID doctorUserId, LocalDate date) {
        Map<UUID, List<AppointmentSessionResponse>> byVisit = new LinkedHashMap<>();
        Map<UUID, Appointment> visits = new LinkedHashMap<>();

        sessionsFor(doctorUserId, dayOrToday(date)).stream()
                .filter(s -> s.getStatus() != SessionStatus.CANCELLED)
                .forEach(s -> {
                    visits.putIfAbsent(s.getAppointment().getId(), s.getAppointment());
                    byVisit.computeIfAbsent(s.getAppointment().getId(), id -> new ArrayList<>())
                            .add(AppointmentSessionResponse.of(s));
                });

        return visits.values().stream()
                .map(a -> AppointmentResponse.of(a, byVisit.getOrDefault(a.getId(), List.of())))
                .sorted(Comparator.comparing(AppointmentResponse::scheduledAt))
                .toList();
    }

    private List<AppointmentSession> sessionsFor(UUID doctorUserId, LocalDate date) {
        return sessions.findForPractitionerBetween(
                doctorUserId, startOfDay(date), startOfDay(date.plusDays(1)));
    }

    private void assertBooked(Appointment appointment) {
        if (appointment.getStatus() != AppointmentStatus.BOOKED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Appointment is not booked");
        }
    }

    private LocalDate dayOrToday(LocalDate date) {
        if (date != null) {
            return date;
        }
        return LocalDate.now(clinic.zone());
    }

    private Instant startOfDay(LocalDate date) {
        return date.atStartOfDay(clinic.zone()).toInstant();
    }

    private AppointmentResponse withSessions(Appointment appointment) {
        return AppointmentResponse.of(appointment, sessions.findByAppointmentId(appointment.getId()).stream()
                .map(AppointmentSessionResponse::of)
                .toList());
    }

    private List<AppointmentResponse> sorted(List<Appointment> found) {
        Map<UUID, List<AppointmentSessionResponse>> byAppointment = sessionsFor(found);

        return found.stream()
                .map(a -> AppointmentResponse.of(a, byAppointment.getOrDefault(a.getId(), List.of())))
                .sorted(Comparator.comparing(AppointmentResponse::scheduledAt))
                .toList();
    }

    // Query ordered it; keep the sequence.
    private Page<AppointmentResponse> withSessions(Page<Appointment> page) {
        Map<UUID, List<AppointmentSessionResponse>> byAppointment = sessionsFor(page.getContent());

        return page.map(a -> AppointmentResponse.of(a, byAppointment.getOrDefault(a.getId(), List.of())));
    }

    // Whole page of sessions, one query.
    private Map<UUID, List<AppointmentSessionResponse>> sessionsFor(List<Appointment> found) {
        if (found.isEmpty()) {
            return Map.of();
        }

        return sessions.findByAppointmentIdIn(found.stream().map(Appointment::getId).toList()).stream()
                .collect(Collectors.groupingBy(
                        s -> s.getAppointment().getId(),
                        Collectors.mapping(AppointmentSessionResponse::of, Collectors.toList())));
    }

    private Appointment require(UUID id) {
        return appointments.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment"));
    }

    // For writes; reads use require().
    private Appointment requireLocked(UUID id) {
        return appointments.findWithLockById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment"));
    }

    // Staff reach any; patients only theirs.
    private void requireOwnAppointment(UUID id) {
        Appointment appointment = require(id);

        if (currentUser.isClinicStaff() || currentUser.is(appointment.getPatient().getUserId())) {
            return;
        }

        throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment");
    }
}
