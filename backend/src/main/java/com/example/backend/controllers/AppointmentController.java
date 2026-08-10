package com.example.backend.controllers;

import com.example.backend.dtos.AppointmentResponse;
import com.example.backend.dtos.BookAppointmentRequest;
import com.example.backend.dtos.FreeSlotResponse;
import com.example.backend.dtos.RescheduleAppointmentRequest;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.security.access.AppointmentCreator;
import org.springframework.security.access.prepost.PreAuthorize;
import com.example.backend.security.access.Authenticated;
import com.example.backend.security.access.ClinicStaffOnly;
import com.example.backend.security.access.PatientOnly;
import com.example.backend.services.AppointmentService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Positive;
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

    @GetMapping("/me")
    @PatientOnly
    public Page<AppointmentResponse> readOwn(Pageable pageable) {
        return appointments.readOwnAsPatient(pageable);
    }

    @GetMapping("/me/schedule")
    @PreAuthorize("hasRole('DOCTOR')")
    public List<AppointmentResponse> readOwnSchedule(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        return appointments.readOwnSchedule(date);
    }

    // Open to patients too: they book, so they need free windows. No patient or visit is named.
    @GetMapping("/free-slots")
    @Authenticated
    public List<FreeSlotResponse> freeSlots(
            @RequestParam UUID doctorId,
            @RequestParam TreatmentName treatmentName,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        return appointments.freeSlots(doctorId, treatmentName, date);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('DOCTOR', 'RECEPTIONIST', 'ADMIN') or @access.ownsAppointment(#id)")
    public AppointmentResponse read(@PathVariable UUID id) {
        return appointments.read(id);
    }

    // A patient may move and cancel their own booking - story 3.1 AC3; everyone else must be staff.
    @PutMapping("/{id}/reschedule")
    @PreAuthorize("hasAnyRole('DOCTOR', 'RECEPTIONIST', 'ADMIN') or @access.ownsAppointment(#id)")
    public AppointmentResponse reschedule(
            @PathVariable UUID id,
            @Valid @RequestBody RescheduleAppointmentRequest request
    ) {
        return appointments.reschedule(id, request);
    }

    @PutMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('DOCTOR', 'RECEPTIONIST', 'ADMIN') or @access.ownsAppointment(#id)")
    public AppointmentResponse cancel(@PathVariable UUID id) {
        return appointments.cancel(id);
    }
}
