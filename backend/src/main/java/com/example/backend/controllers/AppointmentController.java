package com.example.backend.controllers;

import com.example.backend.dtos.AppointmentResponse;
import com.example.backend.dtos.BookAppointmentRequest;
import com.example.backend.dtos.FreeSlotResponse;
import com.example.backend.dtos.RescheduleAppointmentRequest;
import com.example.backend.security.access.AppointmentReader;
import com.example.backend.security.access.ClinicStaffOnly;
import com.example.backend.security.access.DoctorOnly;
import com.example.backend.security.access.PatientOnly;
import com.example.backend.services.AppointmentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
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
    @ClinicStaffOnly
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

    @GetMapping("/me")
    @PatientOnly
    public List<AppointmentResponse> readOwn() {
        return appointments.readOwnAsPatient();
    }

    @GetMapping("/me/schedule")
    @DoctorOnly
    public List<AppointmentResponse> readOwnSchedule(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        return appointments.readOwnSchedule(date);
    }

    @GetMapping("/free-slots")
    @ClinicStaffOnly
    public List<FreeSlotResponse> freeSlots(
            @RequestParam UUID doctorId,
            @RequestParam UUID serviceId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        return appointments.freeSlots(doctorId, serviceId, date);
    }

    @GetMapping("/{id}")
    @AppointmentReader
    public AppointmentResponse read(@PathVariable UUID id) {
        return appointments.read(id);
    }

    @PutMapping("/{id}/reschedule")
    @ClinicStaffOnly
    public AppointmentResponse reschedule(
            @PathVariable UUID id,
            @Valid @RequestBody RescheduleAppointmentRequest request
    ) {
        return appointments.reschedule(id, request);
    }

    @PutMapping("/{id}/cancel")
    @ClinicStaffOnly
    public AppointmentResponse cancel(@PathVariable UUID id) {
        return appointments.cancel(id);
    }

    @PutMapping("/{id}/attended")
    @ClinicStaffOnly
    public AppointmentResponse markAttended(@PathVariable UUID id) {
        return appointments.markAttended(id);
    }

    @PutMapping("/{id}/no-show")
    @ClinicStaffOnly
    public AppointmentResponse markNoShow(@PathVariable UUID id) {
        return appointments.markNoShow(id);
    }
}
