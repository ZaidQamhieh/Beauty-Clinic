package com.example.backend.appointments;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.dtos.AddSessionRequest;
import com.example.backend.dtos.AppointmentSessionResponse;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.PatientProfile.SkinType;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorAvailabilityRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.example.backend.services.AppointmentSessionService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
class AppointmentSessionServiceTest extends AbstractIntegrationTest {

    private static final LocalDate DAY = LocalDate.now(ZoneOffset.UTC).plusDays(5);

    @Autowired
    private AppointmentSessionService sessionService;

    @Autowired
    private AppointmentRepository appointmentRepository;

    @Autowired
    private AppointmentSessionRepository sessionRepository;

    @Autowired
    private DoctorProfileRepository doctorProfileRepository;

    @Autowired
    private PatientProfileRepository patientProfileRepository;

    @Autowired
    private UserAccountRepository userAccountRepository;

    @Autowired
    private DoctorAvailabilityRepository availabilityRepository;

    @Autowired
    private TransactionTemplate transactions;

    @Test
    void addSessionToVisitHappyPath() {
        Fixture fixture = setupFixture();
        Instant sessionTime = at(10, 0);
        UUID appointmentId = createAppointmentWithSession(fixture, sessionTime, TreatmentName.MICRONEEDLING);

        AddSessionRequest request = new AddSessionRequest(
                fixture.doctorId(), TreatmentName.CONSULTATION, at(11, 0));

        AppointmentSessionResponse response = sessionService.add(appointmentId, request);

        assertThat(response).isNotNull();
        assertThat(response.treatmentName()).isEqualTo(TreatmentName.CONSULTATION);
        assertThat(sessionRepository.findByAppointmentId(appointmentId)).hasSize(2);
    }

    @Test
    void addSessionThrowsForMissingAppointment() {
        Fixture fixture = setupFixture();
        UUID fakeId = UUID.randomUUID();

        AddSessionRequest request = new AddSessionRequest(
                fixture.doctorId(), TreatmentName.CONSULTATION, at(10, 0));

        assertThatThrownBy(() -> sessionService.add(fakeId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void addSessionRejectsNonBookedAppointment() {
        Fixture fixture = setupFixture();
        UUID appointmentId = transactions.execute(status -> {
            Appointment appointment = appointmentRepository.save(
                    new Appointment(fixture.patient(), at(10, 0)));
            appointment.cancel();
            appointmentRepository.save(appointment);
            return appointment.getId();
        });

        AddSessionRequest request = new AddSessionRequest(
                fixture.doctorId(), TreatmentName.CONSULTATION, at(10, 0));

        assertThatThrownBy(() -> sessionService.add(appointmentId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void addSessionRejectsTreatmentAlreadyInVisit() {
        Fixture fixture = setupFixture();
        UUID appointmentId = createAppointmentWithSession(
                fixture, at(10, 0), TreatmentName.CONSULTATION);

        AddSessionRequest request = new AddSessionRequest(
                fixture.doctorId(), TreatmentName.CONSULTATION, at(11, 0));

        assertThatThrownBy(() -> sessionService.add(appointmentId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void addSessionRejectsIfNotQualified() {
        Fixture fixture = setupFixture();
        UUID appointmentId = createAppointmentWithSession(fixture, at(10, 0));

        UUID unqualifiedDoctorId = transactions.execute(status -> {
            String unique = UUID.randomUUID().toString().substring(0, 8);
            UserAccount account = userAccountRepository.save(
                    new UserAccount("doctor-unq-" + unique + "@example.com", "hash",
                            "Dr", "Other", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(account);
            doctorProfileRepository.save(profile);
            return profile.getUserId();
        });

        AddSessionRequest request = new AddSessionRequest(
                unqualifiedDoctorId, TreatmentName.LASER_HAIR_REMOVAL, at(11, 0));

        assertThatThrownBy(() -> sessionService.add(appointmentId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void addSessionRejectsOutsideWorkingHours() {
        Fixture fixture = setupFixture();
        UUID appointmentId = createAppointmentWithSession(fixture, at(10, 0));

        AddSessionRequest request = new AddSessionRequest(
                fixture.doctorId(), TreatmentName.CONSULTATION, at(23, 0));

        assertThatThrownBy(() -> sessionService.add(appointmentId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void addSessionRejectsOutsideBookingHorizon() {
        Fixture fixture = setupFixture();
        LocalDate farFuture = DAY.plusDays(100);
        UUID appointmentId = createAppointmentWithSession(fixture, at(10, 0));

        AddSessionRequest request = new AddSessionRequest(
                fixture.doctorId(), TreatmentName.CONSULTATION,
                farFuture.atTime(LocalTime.of(10, 0)).toInstant(ZoneOffset.UTC));

        assertThatThrownBy(() -> sessionService.add(appointmentId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void addSessionRejectsPastTime() {
        Fixture fixture = setupFixture();
        UUID appointmentId = createAppointmentWithSession(fixture, at(10, 0));

        Instant pastTime = Instant.now().minus(1, ChronoUnit.HOURS);

        AddSessionRequest request = new AddSessionRequest(
                fixture.doctorId(), TreatmentName.CONSULTATION, pastTime);

        assertThatThrownBy(() -> sessionService.add(appointmentId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void cancelSessionMarksAsCancelled() {
        Fixture fixture = setupFixture();
        UUID appointmentId = createAppointmentWithSession(fixture, at(10, 0));

        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        AppointmentSessionResponse response = sessionService.cancel(
                appointmentId, session.getId());

        assertThat(response.status()).isEqualTo(SessionStatus.CANCELLED.name());
    }

    @Test
    void cancelSessionThrowsForMissingSession() {
        Fixture fixture = setupFixture();
        UUID appointmentId = createAppointmentWithSession(fixture, at(10, 0));
        UUID fakeId = UUID.randomUUID();

        assertThatThrownBy(() -> sessionService.cancel(appointmentId, fakeId))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void cancelSessionRejectsNotPlanned() {
        Fixture fixture = setupFixture();
        UUID appointmentId = transactions.execute(status -> {
            Appointment appointment = appointmentRepository.save(
                    new Appointment(fixture.patient(), at(10, 0)));

            AppointmentSession session = sessionRepository.save(new AppointmentSession(
                    appointment, fixture.doctor(), TreatmentName.CONSULTATION.category(),
                    TreatmentName.CONSULTATION, new BigDecimal("100.00"), 20,
                    at(10, 0), at(10, 20)));
            session.setStatus(SessionStatus.COMPLETED);
            sessionRepository.save(session);

            return appointment.getId();
        });

        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        assertThatThrownBy(() -> sessionService.cancel(appointmentId, session.getId()))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void markAttendedTransitionsToCompleted() {
        Fixture fixture = setupFixture();
        Instant pastTime = Instant.now().minus(1, ChronoUnit.HOURS);
        UUID appointmentId = createAppointmentWithSession(fixture, pastTime);

        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        AppointmentSessionResponse response = sessionService.markAttended(
                appointmentId, session.getId());

        assertThat(response.status()).isEqualTo(SessionStatus.COMPLETED.name());
    }

    @Test
    void markAttendedRejectsNotStarted() {
        Fixture fixture = setupFixture();
        LocalDate future = DAY.plusDays(10);
        UUID appointmentId = transactions.execute(status -> {
            Appointment appointment = appointmentRepository.save(
                    new Appointment(fixture.patient(),
                            future.atTime(LocalTime.of(10, 0)).toInstant(ZoneOffset.UTC)));

            AppointmentSession session = sessionRepository.save(new AppointmentSession(
                    appointment, fixture.doctor(), TreatmentName.CONSULTATION.category(),
                    TreatmentName.CONSULTATION, new BigDecimal("100.00"), 20,
                    future.atTime(LocalTime.of(10, 0)).toInstant(ZoneOffset.UTC),
                    future.atTime(LocalTime.of(10, 20)).toInstant(ZoneOffset.UTC)));

            return appointment.getId();
        });

        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        assertThatThrownBy(() -> sessionService.markAttended(appointmentId, session.getId()))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void markNoShowTransitionsToNoShow() {
        Fixture fixture = setupFixture();
        Instant pastTime = Instant.now().minus(1, ChronoUnit.HOURS);
        UUID appointmentId = createAppointmentWithSession(fixture, pastTime);

        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        AppointmentSessionResponse response = sessionService.markNoShow(
                appointmentId, session.getId());

        assertThat(response.status()).isEqualTo(SessionStatus.NO_SHOW.name());
    }

    @Test
    void markNoShowRejectsNotPlanned() {
        Fixture fixture = setupFixture();
        UUID appointmentId = transactions.execute(status -> {
            Appointment appointment = appointmentRepository.save(
                    new Appointment(fixture.patient(), at(10, 0)));

            AppointmentSession session = sessionRepository.save(new AppointmentSession(
                    appointment, fixture.doctor(), TreatmentName.CONSULTATION.category(),
                    TreatmentName.CONSULTATION, new BigDecimal("100.00"), 20,
                    at(10, 0), at(10, 20)));
            session.setStatus(SessionStatus.CANCELLED);
            sessionRepository.save(session);

            return appointment.getId();
        });

        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        assertThatThrownBy(() -> sessionService.markNoShow(appointmentId, session.getId()))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    private record Fixture(
            UUID doctorId,
            DoctorProfile doctor,
            UUID patientId,
            PatientProfile patient) {
    }

    private Fixture setupFixture() {
        return transactions.execute(status -> {
            String unique = UUID.randomUUID().toString().substring(0, 8);

            UserAccount doctorAccount = userAccountRepository.save(new UserAccount(
                    "doctor-" + unique + "@example.com", "hash", "Dr", "Test", Role.DOCTOR));
            DoctorProfile doctor = new DoctorProfile(doctorAccount);
            doctor.setSpecializations(new ArrayList<>(TreatmentName.CONSULTATION.category().qualifying()));
            doctorProfileRepository.save(doctor);

            DoctorAvailability allDay = new DoctorAvailability(
                    doctor, AvailabilityKind.MODIFIED, null,
                    LocalTime.of(0, 0), LocalTime.of(23, 59), DAY);
            allDay.setEffectiveTo(DAY);
            availabilityRepository.save(allDay);

            UserAccount patientAccount = userAccountRepository.save(new UserAccount(
                    "patient-" + unique + "@example.com", "hash", "Patient", "User", Role.PATIENT));
            PatientProfile patient = new PatientProfile(patientAccount);
            patient.setSkinType(SkinType.NORMAL);
            patientProfileRepository.save(patient);

            return new Fixture(doctor.getUserId(), doctor, patient.getUserId(), patient);
        });
    }

    private UUID createAppointmentWithSession(Fixture fixture, Instant sessionTime) {
        return createAppointmentWithSession(fixture, sessionTime, TreatmentName.CONSULTATION);
    }

    private UUID createAppointmentWithSession(
            Fixture fixture, Instant sessionTime, TreatmentName treatment) {
        return transactions.execute(status -> {
            Appointment appointment = appointmentRepository.save(
                    new Appointment(fixture.patient(), sessionTime));

            sessionRepository.save(new AppointmentSession(
                    appointment, fixture.doctor(), treatment.category(), treatment,
                    new BigDecimal("100.00"), 20,
                    sessionTime, sessionTime.plus(20, ChronoUnit.MINUTES)));

            return appointment.getId();
        });
    }

    private Instant at(int hour, int minute) {
        return DAY.atTime(LocalTime.of(hour, minute)).toInstant(ZoneOffset.UTC);
    }
}
