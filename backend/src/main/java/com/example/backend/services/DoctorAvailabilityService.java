package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.dtos.CreateDoctorAvailabilityRequest;
import com.example.backend.dtos.DayAvailabilityStatus;
import com.example.backend.dtos.DoctorAvailabilityDayStatus;
import com.example.backend.dtos.DoctorAvailabilityResponse;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.exception.AvailabilityConflictException;
import com.example.backend.exception.AvailabilityConflictException.ConflictingSession;
import com.example.backend.exception.AvailabilityShadowConfirmationRequiredException;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorAvailabilityRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DoctorAvailabilityService {

    private final DoctorAvailabilityRepository availabilities;
    private final DoctorProfileRepository doctors;
    private final CurrentUser currentUser;
    private final ActivityLogService activityLogs;
    private final AppointmentSessionRepository appointmentSessions;
    private final ClinicProperties clinic;

    @Transactional(readOnly = true)
    public List<DoctorAvailabilityResponse> list(UUID doctorUserId) {
        boolean staff = currentUser.isClinicStaff();

        return availabilities.findByDoctorUserId(doctorUserId).stream()
                .filter(availability -> staff || !isClosure(availability))
                .map(DoctorAvailabilityResponse::of)
                .toList();
    }

    // A vacation is a sick day or a holiday. The desk may see it; the public may not.
    private static boolean isClosure(DoctorAvailability availability) {
        return availability.getKind() == AvailabilityKind.VACATION;
    }

    @Transactional
    public DoctorAvailabilityResponse add(UUID doctorUserId, CreateDoctorAvailabilityRequest request) {
        DoctorProfile doctor = doctors.findById(doctorUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));

        rejectRedundantOverlap(doctorUserId, null, request);

        DoctorAvailability candidate = new DoctorAvailability(
                doctor,
                request.kind(),
                request.dayOfWeek(),
                request.startTime(),
                request.endTime(),
                request.effectiveFrom());
        candidate.setEffectiveTo(request.effectiveTo());

        List<LocalDate> affectedDates = datesCoveredBy(
                request.kind(), request.dayOfWeek(), request.effectiveFrom(), request.effectiveTo());
        List<DoctorAvailability> simulated = new ArrayList<>(availabilities.findByDoctorUserId(doctorUserId));
        simulated.add(candidate);
        rejectIfBookedAppointmentsWouldBeOrphaned(doctorUserId, simulated, affectedDates);
        checkShadowing(doctorUserId, null, request, affectedDates);

        DoctorAvailability saved = availabilities.save(candidate);

        activityLogs.record(
                currentUser.id().orElse(null), null, ActivityAction.AVAILABILITY_ADDED,
                "doctor_availability", saved.getId());

        return DoctorAvailabilityResponse.of(saved);
    }

    @Transactional
    public DoctorAvailabilityResponse update(
            UUID doctorUserId,
            UUID availabilityId,
            CreateDoctorAvailabilityRequest request) {
        DoctorAvailability availability = availabilities.findById(availabilityId)
                .filter(a -> a.getDoctor().getUserId().equals(doctorUserId))
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "No such availability window"));

        rejectRedundantOverlap(doctorUserId, availabilityId, request);

        // A transient stand-in for what `availability` is about to become, used only to
        // simulate the proposed schedule for the checks below - the real entity is
        // mutated afterward, once both checks have passed.
        DoctorAvailability candidate = new DoctorAvailability(
                availability.getDoctor(),
                request.kind(),
                request.dayOfWeek(),
                request.startTime(),
                request.endTime(),
                request.effectiveFrom());
        candidate.setEffectiveTo(request.effectiveTo());

        List<LocalDate> affectedDates = datesCoveredBy(
                request.kind(), request.dayOfWeek(), request.effectiveFrom(), request.effectiveTo());
        List<DoctorAvailability> simulated = availabilities.findByDoctorUserId(doctorUserId).stream()
                .filter(a -> !a.getId().equals(availabilityId))
                .collect(Collectors.toCollection(ArrayList::new));
        simulated.add(candidate);
        rejectIfBookedAppointmentsWouldBeOrphaned(doctorUserId, simulated, affectedDates);
        checkShadowing(doctorUserId, availabilityId, request, affectedDates);

        availability.setKind(request.kind());
        availability.setDayOfWeek(request.dayOfWeek());
        availability.setStartTime(request.startTime());
        availability.setEndTime(request.endTime());
        availability.setEffectiveFrom(request.effectiveFrom());
        availability.setEffectiveTo(request.effectiveTo());
        return DoctorAvailabilityResponse.of(availabilities.save(availability));
    }

    @Transactional
    public void remove(UUID doctorUserId, UUID availabilityId) {
        DoctorAvailability availability = availabilities.findById(availabilityId)
                .filter(a -> a.getDoctor().getUserId().equals(doctorUserId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such availability window"));

        List<LocalDate> affectedDates = datesCoveredBy(
                availability.getKind(), availability.getDayOfWeek(),
                availability.getEffectiveFrom(), availability.getEffectiveTo());
        List<DoctorAvailability> simulated = availabilities.findByDoctorUserId(doctorUserId).stream()
                .filter(a -> !a.getId().equals(availabilityId))
                .toList();
        rejectIfBookedAppointmentsWouldBeOrphaned(doctorUserId, simulated, affectedDates);

        ZonedDateTime nextStart = nextOccurrence(availability);
        if (nextStart != null) {
            ZonedDateTime cancellationCutoff = nextStart.minusHours(1);
            if (!ZonedDateTime.now(clinic.zone()).isBefore(cancellationCutoff)) {
                throw new ResponseStatusException(
                        HttpStatus.CONFLICT,
                        "Availability can only be cancelled at least one hour before it starts");
            }
        }
        availabilities.delete(availability);

        activityLogs.record(
                currentUser.id().orElse(null), null, ActivityAction.AVAILABILITY_REMOVED,
                "doctor_availability", availabilityId);
    }

    private void rejectRedundantOverlap(
            UUID doctorUserId,
            UUID ignoredAvailabilityId,
            CreateDoctorAvailabilityRequest request) {
        boolean overlaps = availabilities.findByDoctorUserId(doctorUserId).stream()
                .filter(existing -> !existing.getId().equals(ignoredAvailabilityId))
                .filter(existing -> existing.getKind() == request.kind())
                .filter(existing -> sameScheduleScope(existing, request))
                .anyMatch(existing -> datesOverlap(
                        existing.getEffectiveFrom(), existing.getEffectiveTo(),
                        request.effectiveFrom(), request.effectiveTo())
                        && (request.kind() == AvailabilityKind.VACATION
                                || timesOverlap(
                                        existing.getStartTime(), existing.getEndTime(),
                                        request.startTime(), request.endTime())));

        if (overlaps) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "This availability overlaps an existing window; edit the existing window instead");
        }
    }

    private boolean sameScheduleScope(
            DoctorAvailability existing,
            CreateDoctorAvailabilityRequest request) {
        return existing.getKind() != AvailabilityKind.REGULAR
                || existing.getDayOfWeek() == request.dayOfWeek();
    }

    private boolean datesOverlap(
            LocalDate firstFrom,
            LocalDate firstTo,
            LocalDate secondFrom,
            LocalDate secondTo) {
        return !firstFrom.isAfter(secondTo == null ? LocalDate.MAX : secondTo)
                && !(firstTo != null && firstTo.isBefore(secondFrom));
    }

    private boolean timesOverlap(
            LocalTime firstStart,
            LocalTime firstEnd,
            LocalTime secondStart,
            LocalTime secondEnd) {
        return firstStart.isBefore(secondEnd) && secondStart.isBefore(firstEnd);
    }

    // Not skippable by acknowledgeShadow: whether a rule takes effect on a date is a
    // schedule question; whether patients are already booked into it is not negotiable.
    private void rejectIfBookedAppointmentsWouldBeOrphaned(
            UUID doctorUserId, List<DoctorAvailability> simulatedRows, List<LocalDate> datesToCheck) {
        if (datesToCheck.isEmpty()) {
            return;
        }

        LocalDate from = datesToCheck.get(0);
        LocalDate to = datesToCheck.get(datesToCheck.size() - 1);
        Instant rangeStart = from.atStartOfDay(clinic.zone()).toInstant();
        Instant rangeEnd = to.plusDays(1).atStartOfDay(clinic.zone()).toInstant();

        List<AppointmentSession> sessions = appointmentSessions
                .findForPractitionerBetween(doctorUserId, rangeStart, rangeEnd).stream()
                .filter(session -> session.getStatus() != SessionStatus.CANCELLED)
                .toList();
        if (sessions.isEmpty()) {
            return;
        }

        Set<LocalDate> datesToCheckSet = new HashSet<>(datesToCheck);
        Map<LocalDate, List<AppointmentSession>> byDate = sessions.stream()
                .collect(Collectors.groupingBy(session -> session.getStartTime().atZone(clinic.zone()).toLocalDate()));

        List<ConflictingSession> conflicts = new ArrayList<>();
        for (LocalDate date : datesToCheckSet) {
            List<AppointmentSession> daySessions = byDate.get(date);
            if (daySessions == null) {
                continue;
            }
            List<TimeRange> windows = resolveDay(effectiveOn(simulatedRows, date), date);
            for (AppointmentSession session : daySessions) {
                LocalTime start = session.getStartTime().atZone(clinic.zone()).toLocalTime();
                LocalTime end = session.getEndTime().atZone(clinic.zone()).toLocalTime();
                if (windows.stream().noneMatch(window -> window.covers(start, end))) {
                    conflicts.add(new ConflictingSession(
                            session.getId(), date, start, end, session.getTreatmentName()));
                }
            }
        }

        if (!conflicts.isEmpty()) {
            String message = conflicts.size() == 1
                    ? "1 booked appointment would no longer be within working hours."
                    : conflicts.size() + " booked appointments would no longer be within working hours.";
            throw new AvailabilityConflictException(message, conflicts);
        }
    }

    // Blocking, but skippable: acknowledgeShadow=true (a resubmission of a request the
    // caller was already told about) skips straight past this.
    private void checkShadowing(
            UUID doctorUserId,
            UUID ignoredAvailabilityId,
            CreateDoctorAvailabilityRequest request,
            List<LocalDate> affectedDates) {
        // VACATION outranks everything in the baseline; nothing can shadow it.
        if (request.acknowledgeShadow() || request.kind() == AvailabilityKind.VACATION) {
            return;
        }

        List<DoctorAvailability> others = availabilities.findByDoctorUserId(doctorUserId).stream()
                .filter(a -> !a.getId().equals(ignoredAvailabilityId))
                .toList();

        List<LocalDate> shadowedDates = new ArrayList<>();
        AvailabilityKind shadowedBy = null;

        for (LocalDate date : affectedDates) {
            List<DoctorAvailability> onDate = effectiveOn(others, date);
            if (request.kind() == AvailabilityKind.REGULAR) {
                if (!ofKind(onDate, AvailabilityKind.VACATION).isEmpty()) {
                    shadowedDates.add(date);
                    shadowedBy = AvailabilityKind.VACATION;
                } else if (!ofKind(onDate, AvailabilityKind.MODIFIED).isEmpty()) {
                    shadowedDates.add(date);
                    if (shadowedBy != AvailabilityKind.VACATION) {
                        shadowedBy = AvailabilityKind.MODIFIED;
                    }
                }
            } else if (request.kind() == AvailabilityKind.MODIFIED) {
                if (!ofKind(onDate, AvailabilityKind.VACATION).isEmpty()) {
                    shadowedDates.add(date);
                    shadowedBy = AvailabilityKind.VACATION;
                }
            } else if (request.kind() == AvailabilityKind.EXTRA_DAY) {
                if (!resolveDay(onDate, date).isEmpty()) {
                    // Not one named kind: it's whatever the day's own baseline already is.
                    shadowedDates.add(date);
                }
            }
        }

        if (!shadowedDates.isEmpty()) {
            throw new AvailabilityShadowConfirmationRequiredException(
                    shadowMessage(shadowedBy, shadowedDates), shadowedBy, shadowedDates);
        }
    }

    private String shadowMessage(AvailabilityKind shadowedBy, List<LocalDate> dates) {
        String datesText = dates.size() == 1
                ? dates.get(0).toString()
                : dates.get(0) + " through " + dates.get(dates.size() - 1) + " (" + dates.size() + " day(s))";
        if (shadowedBy == null) {
            return "This won't take effect on " + datesText
                    + " because the day already has working hours scheduled.";
        }
        return "This won't take effect on " + datesText + " because of an existing " + shadowedBy + " entry.";
    }

    // Bounded to the booking horizon: nothing can ever be booked past it, so neither
    // the shadow check nor the appointment-conflict check needs to look further.
    private List<LocalDate> datesCoveredBy(
            AvailabilityKind kind, DayOfWeek dayOfWeek, LocalDate effectiveFrom, LocalDate effectiveTo) {
        LocalDate today = LocalDate.now(clinic.zone());
        LocalDate horizon = today.plusDays(clinic.maxHorizonDays());
        LocalDate from = effectiveFrom.isAfter(today) ? effectiveFrom : today;
        LocalDate to = effectiveTo == null || effectiveTo.isAfter(horizon) ? horizon : effectiveTo;
        if (to.isBefore(from)) {
            return List.of();
        }

        List<LocalDate> dates = new ArrayList<>();
        for (LocalDate date = from; !date.isAfter(to); date = date.plusDays(1)) {
            if (kind != AvailabilityKind.REGULAR || date.getDayOfWeek() == dayOfWeek) {
                dates.add(date);
            }
        }
        return dates;
    }

    private ZonedDateTime nextOccurrence(DoctorAvailability availability) {
        ZonedDateTime now = ZonedDateTime.now(clinic.zone());
        if (availability.getKind() != AvailabilityKind.REGULAR) {
            if (availability.getStartTime() == null) {
                // VACATION carries no time of day; its "start" is the first day's midnight.
                return availability.getEffectiveFrom().atStartOfDay(now.getZone());
            }
            return availability.getEffectiveFrom()
                    .atTime(availability.getStartTime())
                    .atZone(now.getZone());
        }

        DayOfWeek day = availability.getDayOfWeek();
        ZonedDateTime occurrence = availability.getEffectiveFrom()
                .atTime(availability.getStartTime())
                .atZone(now.getZone());
        while (occurrence.isBefore(now)
                || occurrence.getDayOfWeek() != day) {
            occurrence = occurrence.plusDays(1);
        }
        if (availability.getEffectiveTo() != null
                && occurrence.toLocalDate().isAfter(availability.getEffectiveTo())) {
            return null;
        }
        return occurrence;
    }

    // The weekly pattern settles first, then exceptions apply by priority.
    @Transactional(readOnly = true)
    public List<TimeRange> openWindowsOn(UUID doctorUserId, LocalDate date) {
        return resolveDay(availabilities.findEffectiveOn(
                doctorUserId, date, date.getDayOfWeek()), date);
    }

    // One fetch for the whole range; the per-date resolution loop runs over this
    // already-fetched list in memory, so a month view costs one round trip regardless
    // of how many days it spans - no N+1 per-date queries.
    @Transactional(readOnly = true)
    public List<DoctorAvailabilityDayStatus> calendarStatus(UUID doctorUserId, LocalDate from, LocalDate to) {
        if (to.isBefore(from)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "to must not be before from");
        }

        List<DoctorAvailability> rows = availabilities.findByDoctorUserId(doctorUserId);
        List<DoctorAvailabilityDayStatus> days = new ArrayList<>();

        for (LocalDate date = from; !date.isAfter(to); date = date.plusDays(1)) {
            List<DoctorAvailability> effective = effectiveOn(rows, date);
            DayAvailabilityStatus status;
            if (effective.isEmpty()) {
                status = DayAvailabilityStatus.NONE;
            } else {
                status = resolveDay(effective, date).isEmpty()
                        ? DayAvailabilityStatus.UNAVAILABLE
                        : DayAvailabilityStatus.AVAILABLE;
            }
            days.add(new DoctorAvailabilityDayStatus(date, status));
        }
        return days;
    }

    // Mirrors findEffectiveOn's WHERE clause, evaluated in memory over one already-fetched
    // list instead of one query per date.
    private List<DoctorAvailability> effectiveOn(List<DoctorAvailability> rows, LocalDate date) {
        DayOfWeek dayOfWeek = date.getDayOfWeek();
        return rows.stream()
                .filter(a -> !a.getEffectiveFrom().isAfter(date))
                .filter(a -> a.getEffectiveTo() == null || !a.getEffectiveTo().isBefore(date))
                .filter(a -> a.getKind() != AvailabilityKind.REGULAR || a.getDayOfWeek() == dayOfWeek)
                .toList();
    }

    // One roster, one query, not per doctor.
    @Transactional(readOnly = true)
    public Map<UUID, List<TimeRange>> openWindowsOn(Collection<UUID> doctorUserIds, LocalDate date) {
        if (doctorUserIds.isEmpty()) {
            return Map.of();
        }

        Map<UUID, List<DoctorAvailability>> byDoctor = availabilities
                .findEffectiveOnForAll(doctorUserIds, date, date.getDayOfWeek()).stream()
                .collect(Collectors.groupingBy(a -> a.getDoctor().getUserId()));

        Map<UUID, List<TimeRange>> windows = new LinkedHashMap<>();
        for (UUID doctorUserId : doctorUserIds) {
            windows.put(doctorUserId, resolveDay(byDoctor.getOrDefault(doctorUserId, List.of()), date));
        }
        return windows;
    }

    // VACATION blocks MODIFIED and REGULAR outright; MODIFIED blocks REGULAR; EXTRA_DAY
    // is a pure fallback that only ever fills a day whose baseline resolved to nothing -
    // never additive on top of a working day, never itself suppressed.
    private List<TimeRange> resolveDay(List<DoctorAvailability> effective, LocalDate date) {
        List<TimeRange> baseline;
        if (!ofKind(effective, AvailabilityKind.VACATION).isEmpty()) {
            baseline = List.of();
        } else {
            List<DoctorAvailability> modified = ofKind(effective, AvailabilityKind.MODIFIED);
            if (!modified.isEmpty()) {
                baseline = TimeRange.union(spansOf(modified));
            } else {
                List<DoctorAvailability> regular = ofKind(effective, AvailabilityKind.REGULAR).stream()
                        .filter(a -> a.getDayOfWeek() == date.getDayOfWeek())
                        .toList();
                baseline = TimeRange.union(spansOf(regular));
            }
        }

        if (baseline.isEmpty()) {
            List<DoctorAvailability> extraDay = ofKind(effective, AvailabilityKind.EXTRA_DAY);
            if (!extraDay.isEmpty()) {
                return TimeRange.union(spansOf(extraDay));
            }
        }
        return baseline;
    }

    private List<DoctorAvailability> ofKind(List<DoctorAvailability> rows, AvailabilityKind kind) {
        return rows.stream().filter(a -> a.getKind() == kind).toList();
    }

    // Do these wall-clock times fit inside one open window?
    @Transactional(readOnly = true)
    public boolean isOpenFor(UUID doctorUserId, LocalDate date, LocalTime start, LocalTime end) {
        return openWindowsOn(doctorUserId, date).stream().anyMatch(window -> window.covers(start, end));
    }

    private List<TimeRange> spansOf(List<DoctorAvailability> rows) {
        return rows.stream()
                .map(a -> new TimeRange(a.getStartTime(), a.getEndTime()))
                .toList();
    }
}
