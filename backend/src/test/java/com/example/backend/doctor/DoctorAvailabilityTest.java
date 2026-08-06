package com.example.backend.doctor;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.repositories.DoctorAvailabilityRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.security.Role;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.test.context.ActiveProfiles;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class DoctorAvailabilityTest extends AbstractIntegrationTest {

    @Autowired
    private DoctorProfileRepository doctors;

    @Autowired
    private DoctorAvailabilityRepository availabilities;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private EntityManager entityManager;

    @Test
    void storesAndReadsBackWindowsForADoctor() {
        DoctorProfile saved = doctors.save(profileFor("hours@clinic.com"));

        availabilities.save(new DoctorAvailability(
                saved, AvailabilityKind.RECURRING, DayOfWeek.SUNDAY,
                LocalTime.of(9, 0), LocalTime.of(17, 0), LocalDate.of(2026, 1, 1)
        ));
        availabilities.save(new DoctorAvailability(
                saved, AvailabilityKind.RECURRING, DayOfWeek.WEDNESDAY,
                LocalTime.of(14, 30), LocalTime.of(18, 0), LocalDate.of(2026, 1, 1)
        ));

        entityManager.flush();
        entityManager.clear();

        assertThat(availabilities.findByDoctorUserId(saved.getUserId()))
                .extracting(DoctorAvailability::getDayOfWeek, DoctorAvailability::getStartTime, DoctorAvailability::getEndTime)
                .containsExactlyInAnyOrder(
                        tuple(DayOfWeek.SUNDAY, LocalTime.of(9, 0), LocalTime.of(17, 0)),
                        tuple(DayOfWeek.WEDNESDAY, LocalTime.of(14, 30), LocalTime.of(18, 0))
                );
    }

    @Test
    void defaultsToNoAvailability() {
        DoctorProfile saved = doctors.save(profileFor("no-hours@clinic.com"));

        entityManager.flush();
        entityManager.clear();

        assertThat(availabilities.findByDoctorUserId(saved.getUserId())).isEmpty();
    }

    private DoctorProfile profileFor(String email) {
        UserAccount account = users.save(new UserAccount(
                email, "{bcrypt}hash", "Doctor", "Test", Role.DOCTOR
        ));
        return new DoctorProfile(account);
    }
}
