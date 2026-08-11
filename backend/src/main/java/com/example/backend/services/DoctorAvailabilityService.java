package com.example.backend.services;

import com.example.backend.dtos.CreateDoctorAvailabilityRequest;
import com.example.backend.dtos.DoctorAvailabilityResponse;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.repositories.DoctorAvailabilityRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DoctorAvailabilityService {

    private final DoctorAvailabilityRepository availabilities;
    private final DoctorProfileRepository doctors;

    @Transactional(readOnly = true)
    public List<DoctorAvailabilityResponse> list(UUID doctorUserId) {
        return availabilities.findByDoctorUserId(doctorUserId).stream()
                .map(DoctorAvailabilityResponse::of)
                .toList();
    }

    @Transactional
    public DoctorAvailabilityResponse add(UUID doctorUserId, CreateDoctorAvailabilityRequest request) {
        DoctorProfile doctor = doctors.findById(doctorUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));

        DoctorAvailability availability = new DoctorAvailability(
                doctor,
                request.kind(),
                request.dayOfWeek(),
                request.startTime(),
                request.endTime(),
                request.effectiveFrom()
        );
        availability.setAvailable(request.available());
        availability.setEffectiveTo(request.effectiveTo());

        return DoctorAvailabilityResponse.of(availabilities.save(availability));
    }

    @Transactional
    public void remove(UUID doctorUserId, UUID availabilityId) {
        DoctorAvailability availability = availabilities.findById(availabilityId)
                .filter(a -> a.getDoctor().getUserId().equals(doctorUserId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such availability window"));
        availabilities.delete(availability);
    }

    // The weekly pattern settles first, then the day's overrides go on top and win.
    @Transactional(readOnly = true)
    public List<TimeRange> openWindowsOn(UUID doctorUserId, LocalDate date) {
        List<DoctorAvailability> effective = availabilities.findEffectiveOn(
                doctorUserId, date, date.getDayOfWeek(), AvailabilityKind.OVERRIDE);

        List<DoctorAvailability> recurring = ofKind(effective, AvailabilityKind.RECURRING);
        List<DoctorAvailability> overrides = ofKind(effective, AvailabilityKind.OVERRIDE);

        List<TimeRange> open = TimeRange.subtract(
                TimeRange.union(spansOf(recurring, true)), spansOf(recurring, false));

        // Closures first, so an override that opens time is not cut by one that closes it.
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
