package com.example.backend.appointments;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.Appointment.AppointmentStatus;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.PatientProfile.SkinType;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.example.backend.services.AppointmentSessionService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

// Two treatments of one visit cancelled at the same moment. Before the appointment row was
// locked, each transaction read the other session as still live under READ COMMITTED, so both
// committed and left a BOOKED visit with nothing live in it.
@SpringBootTest
@ActiveProfiles("test")
class ConcurrentCancellationTest extends AbstractIntegrationTest {

    @Autowired
    private AppointmentSessionService sessionService;

    @Autowired
    private TransactionTemplate transactions;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private DoctorProfileRepository doctors;

    @Autowired
    private PatientProfileRepository patients;

    @Autowired
    private AppointmentRepository appointments;

    @Autowired
    private AppointmentSessionRepository sessions;

    @Test
    void neverLeavesVisitBookedAndEmpty() throws Exception {
        Fixture fixture = visitWithTwoTreatments();

        CyclicBarrier bothReady = new CyclicBarrier(2);
        ExecutorService pool = Executors.newFixedThreadPool(2);

        try {
            Future<Void> first = pool.submit(cancel(fixture.appointmentId(), fixture.firstSessionId(), bothReady));
            Future<Void> second = pool.submit(cancel(fixture.appointmentId(), fixture.secondSessionId(), bothReady));

            first.get(30, TimeUnit.SECONDS);
            second.get(30, TimeUnit.SECONDS);
        } finally {
            pool.shutdownNow();
        }

        Appointment settled = appointments.findById(fixture.appointmentId()).orElseThrow();
        List<AppointmentSession> ofVisit = sessions.findByAppointmentId(fixture.appointmentId());

        assertThat(ofVisit)
                .allMatch(session -> session.getStatus() == SessionStatus.CANCELLED);

        // The property that was violated: BOOKED with nothing live left in it.
        assertThat(settled.getStatus()).isEqualTo(AppointmentStatus.CANCELLED);
    }

    private java.util.concurrent.Callable<Void> cancel(UUID appointmentId, UUID sessionId, CyclicBarrier bothReady) {
        return () -> {
            bothReady.await(30, TimeUnit.SECONDS);

            transactions.executeWithoutResult(status -> sessionService.cancel(appointmentId, sessionId));
            return null;
        };
    }

    private record Fixture(UUID appointmentId, UUID firstSessionId, UUID secondSessionId) {
    }

    // Rows are written directly: the booking rules are not what is under test here.
    private Fixture visitWithTwoTreatments() {
        return transactions.execute(status -> {
            String unique = UUID.randomUUID().toString().substring(0, 8);

            UserAccount doctorAccount = users.save(new UserAccount(
                    "doctor-" + unique + "@example.com", "hash", "Dee", "Oakes", Role.DOCTOR));
            DoctorProfile doctor = doctors.save(new DoctorProfile(doctorAccount));

            UserAccount patientAccount = users.save(new UserAccount(
                    "patient-" + unique + "@example.com", "hash", "Pat", "Ient", Role.PATIENT));
            PatientProfile patient = new PatientProfile(patientAccount);
            patient.setSkinType(SkinType.NORMAL);
            patients.save(patient);

            // Far enough out that the patient-side cancellation cutoff is still open.
            Instant start = Instant.now().plus(3, ChronoUnit.DAYS).truncatedTo(ChronoUnit.HOURS);

            Appointment appointment = appointments.save(new Appointment(patient, start));

            AppointmentSession first = sessions.save(session(appointment, doctor, start));
            AppointmentSession second = sessions.save(
                    session(appointment, doctor, start.plus(2, ChronoUnit.HOURS)));

            return new Fixture(appointment.getId(), first.getId(), second.getId());
        });
    }

    private AppointmentSession session(Appointment appointment, DoctorProfile doctor, Instant start) {
        return new AppointmentSession(
                appointment,
                doctor,
                TreatmentName.CONSULTATION.category(),
                TreatmentName.CONSULTATION,
                new BigDecimal("100.00"),
                30,
                start,
                start.plus(30, ChronoUnit.MINUTES));
    }
}
