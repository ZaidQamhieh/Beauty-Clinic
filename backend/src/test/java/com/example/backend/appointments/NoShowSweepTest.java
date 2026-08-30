package com.example.backend.appointments;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.Appointment;
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
import com.example.backend.services.NoShowSweep;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

// Against the real schema: a session well past the end of its attendance
// window, still PLANNED, becomes NO_SHOW; anything not eligible - too
// recent, in the future, or already resolved another way - is left exactly
// as it was. The cutoff matches the attendance window (default 60 minutes
// after the session ends) rather than its own setting, so a session goes
// to NO_SHOW at the exact moment it's no longer possible to mark it
// attended instead.
@SpringBootTest
@ActiveProfiles("test")
class NoShowSweepTest extends AbstractIntegrationTest {

    @Autowired
    private NoShowSweep sweep;

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

    // 30-minute session starting 100 minutes ago ends 70 minutes ago - past
    // the default 60-minute attendance window.
    @Test
    void aSessionWellPastItsAttendanceWindowBecomesNoShow() {
        UUID sessionId = plannedSession(Instant.now().minus(100, ChronoUnit.MINUTES));

        sweep.sweep();

        assertThat(sessions.findById(sessionId).orElseThrow().getStatus())
                .isEqualTo(SessionStatus.NO_SHOW);
    }

    // 30-minute session starting 40 minutes ago ends 10 minutes ago - well
    // inside the default 60-minute attendance window, so still safe.
    @Test
    void aSessionInsideItsAttendanceWindowIsLeftAlone() {
        UUID sessionId = plannedSession(Instant.now().minus(40, ChronoUnit.MINUTES));

        sweep.sweep();

        assertThat(sessions.findById(sessionId).orElseThrow().getStatus())
                .isEqualTo(SessionStatus.PLANNED);
    }

    @Test
    void aFutureSessionIsLeftAlone() {
        UUID sessionId = plannedSession(Instant.now().plus(1, ChronoUnit.HOURS));

        sweep.sweep();

        assertThat(sessions.findById(sessionId).orElseThrow().getStatus())
                .isEqualTo(SessionStatus.PLANNED);
    }

    @Test
    void anAlreadyCompletedSessionIsUntouched() {
        UUID sessionId = plannedSession(Instant.now().minus(100, ChronoUnit.MINUTES));
        transactions.executeWithoutResult(status -> {
            AppointmentSession session = sessions.findById(sessionId).orElseThrow();
            session.setStatus(SessionStatus.COMPLETED);
            sessions.save(session);
        });

        sweep.sweep();

        assertThat(sessions.findById(sessionId).orElseThrow().getStatus())
                .isEqualTo(SessionStatus.COMPLETED);
    }

    // Rows written directly: booking rules aren't what's under test here.
    private UUID plannedSession(Instant start) {
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

            Appointment appointment = appointments.save(new Appointment(patient, start));

            AppointmentSession session = new AppointmentSession(
                    appointment,
                    doctor,
                    TreatmentName.CONSULTATION.category(),
                    TreatmentName.CONSULTATION,
                    new BigDecimal("100.00"),
                    30,
                    start,
                    start.plus(30, ChronoUnit.MINUTES));

            return sessions.save(session).getId();
        });
    }
}
