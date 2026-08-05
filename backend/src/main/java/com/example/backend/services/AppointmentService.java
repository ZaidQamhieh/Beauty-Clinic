package com.example.backend.services;

import com.example.backend.entities.AppointmentStatus;
import com.example.backend.clinic.ClinicProperties;
import com.example.backend.entities.WorkingHours;
import com.example.backend.dtos.AppointmentResponse;
import com.example.backend.dtos.BookAppointmentRequest;
import com.example.backend.dtos.FreeSlotResponse;
import com.example.backend.dtos.RescheduleAppointmentRequest;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.ClinicService;
import com.example.backend.entities.Doctor;
import com.example.backend.entities.Patient;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.ClinicServiceRepository;
import com.example.backend.repositories.DoctorRepository;
import com.example.backend.repositories.PatientRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.DayOfWeek;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AppointmentService {

    private final AppointmentRepository appointments;
    private final PatientRepository patients;
    private final DoctorRepository doctors;
    private final ClinicServiceRepository services;
    private final UserAccountRepository users;
    private final CurrentUser currentUser;
    private final ClinicProperties clinic;

    @Transactional
    public AppointmentResponse book(BookAppointmentRequest request) {
        Patient patient = patients.findById(request.patientId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));
        Doctor doctor = doctors.findById(request.doctorId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));
        ClinicService service = services.findById(request.serviceId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such service"));

        assertBookable(doctor, service);

        Instant startTime = request.startTime();
        Instant endTime = startTime.plus(Duration.ofMinutes(service.getDurationMinutes()));

        assertWithinWorkingHours(doctor, startTime, endTime);
        assertNoConflict(doctor.getUserId(), startTime, endTime);

        Appointment appointment = new Appointment(patient, doctor, service, startTime, endTime);
        appointment.setReason(request.reason());
        currentUser.id().ifPresent(id -> appointment.setCreatedBy(users.getReferenceById(id)));

        return AppointmentResponse.of(appointments.save(appointment));
    }

    @Transactional
    public AppointmentResponse reschedule(UUID id, RescheduleAppointmentRequest request) {
        Appointment original = require(id);
        assertBooked(original);

        Duration duration = Duration.between(original.getStartTime(), original.getEndTime());
        Instant newStartTime = request.startTime();
        Instant newEndTime = newStartTime.plus(duration);

        Doctor doctor = original.getDoctor();
        assertWithinWorkingHours(doctor, newStartTime, newEndTime);

        // A replacement may legally overlap the slot the original just freed, so the
        // cancel has to reach the database before both the conflict check below and
        // the insert at the end. Hibernate orders inserts ahead of updates inside a
        // single flush, so without this the new row would arrive while the original
        // still looked BOOKED and trip appointment_no_double_booking.
        original.cancel();
        appointments.flush();

        assertNoConflict(doctor.getUserId(), newStartTime, newEndTime);

        Appointment replacement = new Appointment(
                original.getPatient(), doctor, original.getService(), newStartTime, newEndTime
        );
        replacement.setReason(original.getReason());
        replacement.setCreatedBy(original.getCreatedBy());
        replacement.setReplaces(original);

        return AppointmentResponse.of(appointments.save(replacement));
    }

    @Transactional
    public AppointmentResponse cancel(UUID id) {
        Appointment appointment = require(id);
        assertBooked(appointment);
        appointment.cancel();
        return AppointmentResponse.of(appointment);
    }

    @Transactional
    public AppointmentResponse markAttended(UUID id) {
        Appointment appointment = require(id);
        assertBooked(appointment);
        appointment.setStatus(AppointmentStatus.COMPLETED);
        return AppointmentResponse.of(appointment);
    }

    @Transactional
    public AppointmentResponse markNoShow(UUID id) {
        Appointment appointment = require(id);
        assertBooked(appointment);
        appointment.setStatus(AppointmentStatus.NO_SHOW);
        return AppointmentResponse.of(appointment);
    }

    @Transactional(readOnly = true)
    public AppointmentResponse read(UUID id) {
        return AppointmentResponse.of(require(id));
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> readOwnAsPatient() {
        Patient patient = patients.findByUserId(currentUser.requireId())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "No patient record for this account"
                ));

        return sorted(appointments.findByPatientId(patient.getId()));
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> readOwnSchedule(LocalDate date) {
        LocalDate day = date != null ? date : today();
        return sorted(appointments.findForDoctorBetween(
                currentUser.requireId(), startOfDay(day), startOfDay(day.plusDays(1))
        ));
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> readSchedule(UUID doctorId, LocalDate date) {
        LocalDate day = date != null ? date : today();
        Instant from = startOfDay(day);
        Instant to = startOfDay(day.plusDays(1));

        List<Appointment> found = doctorId != null
                ? appointments.findForDoctorBetween(doctorId, from, to)
                : appointments.findBetween(from, to);

        return sorted(found);
    }

    @Transactional(readOnly = true)
    public List<FreeSlotResponse> freeSlots(UUID doctorId, UUID serviceId, LocalDate date) {
        Doctor doctor = doctors.findById(doctorId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));
        ClinicService service = services.findById(serviceId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such service"));

        assertBookable(doctor, service);

        Duration duration = Duration.ofMinutes(service.getDurationMinutes());
        short dayOfWeek = weekdayOf(date);

        // Everything except a cancellation holds its slot, matching both the
        // conflict check and appointment_no_double_booking.
        List<Appointment> busy = appointments.findForDoctorBetween(
                        doctorId, startOfDay(date), startOfDay(date.plusDays(1))
                ).stream()
                .filter(a -> a.getStatus() != AppointmentStatus.CANCELLED)
                .toList();

        return doctor.getAvailability().stream()
                .filter(range -> range.dayOfWeek() == dayOfWeek)
                .flatMap(range -> slotsWithin(date, range, duration, busy).stream())
                .sorted(Comparator.comparing(FreeSlotResponse::startTime))
                .toList();
    }

    private List<FreeSlotResponse> slotsWithin(
            LocalDate date, WorkingHours range, Duration duration, List<Appointment> busy
    ) {
        List<FreeSlotResponse> free = new ArrayList<>();

        LocalTime cursor = range.start();
        while (!cursor.plus(duration).isAfter(range.end())) {
            Instant start = date.atTime(cursor).atZone(clinic.zone()).toInstant();
            Instant end = start.plus(duration);

            boolean conflicts = busy.stream().anyMatch(
                    a -> start.isBefore(a.getEndTime()) && end.isAfter(a.getStartTime())
            );

            if (!conflicts) {
                free.add(new FreeSlotResponse(start, end));
            }

            cursor = cursor.plus(duration);
        }

        return free;
    }

    private void assertBookable(Doctor doctor, ClinicService service) {
        if (!service.isActive()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "That service is no longer offered");
        }

        // Compared by id rather than by instance: ClinicService keeps the default
        // identity equals, which only holds while both come from one session.
        boolean offered = doctor.getServices().stream()
                .anyMatch(offering -> offering.getId().equals(service.getId()));

        if (!offered) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "That doctor does not offer that service"
            );
        }
    }

    private void assertBooked(Appointment appointment) {
        if (appointment.getStatus() != AppointmentStatus.BOOKED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Appointment is not booked");
        }
    }

    private void assertNoConflict(UUID doctorUserId, Instant startTime, Instant endTime) {
        if (appointments.existsOverlappingActiveAppointment(doctorUserId, startTime, endTime)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Doctor already has a booking then");
        }
    }

    private void assertWithinWorkingHours(Doctor doctor, Instant startTime, Instant endTime) {
        ZoneId zone = clinic.zone();
        ZonedDateTime zonedStart = startTime.atZone(zone);
        ZonedDateTime zonedEnd = endTime.atZone(zone);

        boolean withinASingleDay = zonedStart.toLocalDate().equals(zonedEnd.toLocalDate());
        short dayOfWeek = weekdayOf(zonedStart.toLocalDate());

        boolean fits = withinASingleDay && doctor.getAvailability().stream().anyMatch(range ->
                range.dayOfWeek() == dayOfWeek
                        && !zonedStart.toLocalTime().isBefore(range.start())
                        && !zonedEnd.toLocalTime().isAfter(range.end())
        );

        if (!fits) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Outside the doctor's working hours");
        }
    }

    // WorkingHours.dayOfWeek() runs Sunday=0..Saturday=6, not java.time's Monday=1..Sunday=7.
    private short weekdayOf(LocalDate date) {
        DayOfWeek day = date.getDayOfWeek();
        return (short) (day.getValue() % 7);
    }

    private LocalDate today() {
        return LocalDate.now(clinic.zone());
    }

    private Instant startOfDay(LocalDate date) {
        return date.atStartOfDay(clinic.zone()).toInstant();
    }

    private List<AppointmentResponse> sorted(List<Appointment> found) {
        return found.stream()
                .map(AppointmentResponse::of)
                .sorted(Comparator.comparing(AppointmentResponse::startTime))
                .toList();
    }

    private Appointment require(UUID id) {
        return appointments.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment"));
    }
}
