package com.example.backend.controllers;

import com.example.backend.dtos.AppointmentResponse;
import com.example.backend.dtos.BookAppointmentRequest;
import com.example.backend.dtos.DayVersionResponse;
import com.example.backend.dtos.FreeSlotQuery;
import com.example.backend.dtos.FreeSlotResponse;
import com.example.backend.security.access.AppointmentCreator;
import com.example.backend.security.access.Authenticated;
import com.example.backend.security.access.ClinicStaffOnly;
import com.example.backend.security.access.DoctorOnly;
import com.example.backend.security.access.PatientOnly;
import com.example.backend.security.access.StaffOrAppointmentOwner;
import com.example.backend.services.AppointmentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/appointments")
@RequiredArgsConstructor
public class AppointmentController {

    private final AppointmentService appointments;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @AppointmentCreator
    public AppointmentResponse book(@Valid @RequestBody BookAppointmentRequest request) {
        return appointments.book(request);
    }

    @GetMapping
    @ClinicStaffOnly
    public List<AppointmentResponse> schedule(
            @RequestParam(required = false) UUID doctorId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        return appointments.readSchedule(doctorId, date);
    }

    @GetMapping("/all")
    @ClinicStaffOnly
    public Page<AppointmentResponse> readAllForStaff(Pageable pageable) {
        return appointments.readAllForStaff(pageable);
    }

    @GetMapping("/me")
    @PatientOnly
    public Page<AppointmentResponse> readOwn(Pageable pageable) {
        return appointments.readOwnAsPatient(pageable);
    }

    // Split so clients need not sort themselves.
    @GetMapping("/me/upcoming")
    @PatientOnly
    public Page<AppointmentResponse> readOwnUpcoming(Pageable pageable) {
        return appointments.readOwnUpcoming(pageable);
    }

    @GetMapping("/me/history")
    @PatientOnly
    public Page<AppointmentResponse> readOwnHistory(Pageable pageable) {
        return appointments.readOwnHistory(pageable);
    }

    // The same two views, for staff.
    @GetMapping("/patients/{patientId}/upcoming")
    @ClinicStaffOnly
    public Page<AppointmentResponse> readUpcomingFor(
            @PathVariable UUID patientId, Pageable pageable) {
        return appointments.readUpcomingFor(patientId, pageable);
    }

    @GetMapping("/patients/{patientId}/history")
    @ClinicStaffOnly
    public Page<AppointmentResponse> readHistoryFor(
            @PathVariable UUID patientId, Pageable pageable) {
        return appointments.readHistoryFor(patientId, pageable);
    }

    @GetMapping("/me/schedule")
    @DoctorOnly
    public List<AppointmentResponse> readOwnSchedule(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        return appointments.readOwnSchedule(date);
    }

    @GetMapping("/me/day")
    @PatientOnly
    public List<AppointmentResponse> readOwnDay(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        return appointments.readOwnDayAsPatient(date);
    }

    // Open to patients, who book. A body, because it carries picks not stored yet.
    @PostMapping("/free-slots")
    @Authenticated
    public List<FreeSlotResponse> freeSlots(@Valid @RequestBody FreeSlotQuery query) {
        return appointments.freeSlots(query);
    }

    // Polled, so it stays one aggregate read.
    @GetMapping("/day-version")
    @Authenticated
    public DayVersionResponse dayVersion(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        return appointments.dayVersion(date);
    }

    @GetMapping("/{id}")
    @StaffOrAppointmentOwner
    public AppointmentResponse read(@PathVariable UUID id) {
        return appointments.read(id);
    }

    // No reschedule: a different time is a cancellation and a fresh booking.
    @PutMapping("/{id}/cancel")
    @StaffOrAppointmentOwner
    public AppointmentResponse cancel(@PathVariable UUID id) {
        return appointments.cancel(id);
    }
}
