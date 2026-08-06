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

    // Windows doctor open for on a date. OVERRIDE beats RECURRING, so holiday holds.
    @Transactional(readOnly = true)
    public List<DoctorAvailability> openWindowsOn(UUID doctorUserId, LocalDate date) {
        List<DoctorAvailability> all = availabilities.findByDoctorUserId(doctorUserId);

        List<DoctorAvailability> overrides = all.stream()
                .filter(a -> a.getKind() == AvailabilityKind.OVERRIDE)
                .filter(a -> covers(a, date))
                .toList();

        if (!overrides.isEmpty()) {
            return overrides.stream().filter(DoctorAvailability::isAvailable).toList();
        }

        return all.stream()
                .filter(a -> a.getKind() == AvailabilityKind.RECURRING)
                .filter(a -> a.getDayOfWeek() == date.getDayOfWeek())
                .filter(a -> covers(a, date))
                .filter(DoctorAvailability::isAvailable)
                .toList();
    }

    // Do these wall-clock times fit inside one open window?
    @Transactional(readOnly = true)
    public boolean isOpenFor(UUID doctorUserId, LocalDate date, LocalTime start, LocalTime end) {
        return openWindowsOn(doctorUserId, date).stream().anyMatch(window ->
                !start.isBefore(window.getStartTime()) && !end.isAfter(window.getEndTime())
        );
    }

    private boolean covers(DoctorAvailability availability, LocalDate date) {
        return !date.isBefore(availability.getEffectiveFrom())
                && (availability.getEffectiveTo() == null || !date.isAfter(availability.getEffectiveTo()));
    }
}
