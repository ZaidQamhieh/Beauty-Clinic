package com.example.backend.services;

import com.example.backend.dtos.CreateDoctorAvailabilityRequest;
import com.example.backend.dtos.DayAvailabilityStatus;
import com.example.backend.dtos.DoctorAvailabilityDayStatus;
import com.example.backend.dtos.DoctorAvailabilityResponse;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.repositories.DoctorAvailabilityRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.DayOfWeek;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DoctorAvailabilityService {

    private final DoctorAvailabilityRepository availabilities;
    private final DoctorProfileRepository doctors;
    private final CurrentUser currentUser;
    private final ActivityLogService activityLogs;

    @Transactional(readOnly = true)
    public List<DoctorAvailabilityResponse> list(UUID doctorUserId) {
        boolean staff = currentUser.isClinicStaff();

        return availabilities.findByDoctorUserId(doctorUserId).stream()
                .filter(availability -> staff || !isClosure(availability))
                .map(DoctorAvailabilityResponse::of)
                .toList();
    }

    // A dated closure is a sick day or a holiday. The desk may see it; the public
    // may not.
    private static boolean isClosure(DoctorAvailability availability) {
        return availability.getKind() == AvailabilityKind.OVERRIDE && !availability.isAvailable();
    }

    @Transactional
    public DoctorAvailabilityResponse add(UUID doctorUserId, CreateDoctorAvailabilityRequest request) {
        DoctorProfile doctor = doctors.findById(doctorUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));

        rejectRedundantOverlap(doctorUserId, null, request);

        DoctorAvailability availability = new DoctorAvailability(
                doctor,
                request.kind(),
                request.dayOfWeek(),
                request.startTime(),
                request.endTime(),
                request.effectiveFrom());
        availability.setAvailable(request.available());
        availability.setEffectiveTo(request.effectiveTo());

        DoctorAvailability saved = availabilities.save(availability);

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

        availability.setKind(request.kind());
        availability.setDayOfWeek(request.dayOfWeek());
        availability.setStartTime(request.startTime());
        availability.setEndTime(request.endTime());
        availability.setAvailable(request.available());
        availability.setEffectiveFrom(request.effectiveFrom());
        availability.setEffectiveTo(request.effectiveTo());
        return DoctorAvailabilityResponse.of(availabilities.save(availability));
    }

    @Transactional
    public void remove(UUID doctorUserId, UUID availabilityId) {
        DoctorAvailability availability = availabilities.findById(availabilityId)
                .filter(a -> a.getDoctor().getUserId().equals(doctorUserId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such availability window"));
        ZonedDateTime nextStart = nextOccurrence(availability);
        if (nextStart == null) {
            availabilities.delete(availability);
            return;
        }
        ZonedDateTime cancellationCutoff = nextStart.minusHours(1);
        if (!ZonedDateTime.now(ZoneId.systemDefault()).isBefore(cancellationCutoff)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "Availability can only be cancelled at least one hour before it starts");
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
                        && timesOverlap(
                                existing.getStartTime(), existing.getEndTime(),
                                request.startTime(), request.endTime()));

        if (overlaps) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "This availability overlaps an existing window; edit the existing window instead");
        }
    }

    private boolean sameScheduleScope(
            DoctorAvailability existing,
            CreateDoctorAvailabilityRequest request) {
        return existing.getKind() == AvailabilityKind.OVERRIDE
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

    private ZonedDateTime nextOccurrence(DoctorAvailability availability) {
        ZonedDateTime now = ZonedDateTime.now(ZoneId.systemDefault());
        if (availability.getKind() == AvailabilityKind.OVERRIDE) {
            ZonedDateTime start = availability.getEffectiveFrom()
                    .atTime(availability.getStartTime())
                    .atZone(now.getZone());
            return start.isAfter(now) ? start : start;
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

    // The weekly pattern settles first, then the day's overrides go on top and win.
    @Transactional(readOnly = true)
    public List<TimeRange> openWindowsOn(UUID doctorUserId, LocalDate date) {
        return windowsFrom(availabilities.findEffectiveOn(
                doctorUserId, date, date.getDayOfWeek()));
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
                status = windowsFrom(effective).isEmpty()
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
                .filter(a -> a.getKind() == AvailabilityKind.OVERRIDE || a.getDayOfWeek() == dayOfWeek)
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
            windows.put(doctorUserId, windowsFrom(byDoctor.getOrDefault(doctorUserId, List.of())));
        }
        return windows;
    }

    private List<TimeRange> windowsFrom(List<DoctorAvailability> effective) {
        List<DoctorAvailability> recurring = ofKind(effective, AvailabilityKind.RECURRING);
        List<DoctorAvailability> overrides = ofKind(effective, AvailabilityKind.OVERRIDE);

        List<TimeRange> open = TimeRange.subtract(
                TimeRange.union(spansOf(recurring, true)), spansOf(recurring, false));

        // Closures first, so an override that opens time is not cut by one that closes
        // it.
        open = TimeRange.subtract(open, spansOf(overrides, false));
        open.addAll(spansOf(overrides, true));

        return TimeRange.union(open);
    }

    private List<DoctorAvailability> ofKind(List<DoctorAvailability> rows, AvailabilityKind kind) {
        return rows.stream().filter(a -> a.getKind() == kind).toList();
    }

    // Do these wall-clock times fit inside one open window?
    @Transactional(readOnly = true)
    public boolean isOpenFor(UUID doctorUserId, LocalDate date, LocalTime start, LocalTime end) {
        return openWindowsOn(doctorUserId, date).stream().anyMatch(window -> window.covers(start, end));
    }

    private List<TimeRange> spansOf(List<DoctorAvailability> rows, boolean available) {
        return rows.stream()
                .filter(a -> a.isAvailable() == available)
                .map(a -> new TimeRange(a.getStartTime(), a.getEndTime()))
                .toList();
    }
}
