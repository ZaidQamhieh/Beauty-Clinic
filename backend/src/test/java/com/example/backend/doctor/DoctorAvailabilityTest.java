package com.example.backend.doctor;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.Doctor;
import com.example.backend.entities.WorkingHours;
import com.example.backend.repositories.DoctorRepository;
import com.example.backend.security.Role;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.test.context.ActiveProfiles;

import java.time.LocalTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class DoctorAvailabilityTest extends AbstractIntegrationTest {

    @Autowired
    private DoctorRepository doctors;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private EntityManager entityManager;

    @Test
    void storesWorkingHoursAsJsonAndReadsThemBack() {
        Doctor saved = doctors.save(profileFor("hours@clinic.com"));
        saved.setAvailability(List.of(
                new WorkingHours((short) 0, LocalTime.of(9, 0), LocalTime.of(17, 0)),
                new WorkingHours((short) 3, LocalTime.of(14, 30), LocalTime.of(18, 0))
        ));

        entityManager.flush();
        entityManager.clear();

        Doctor reloaded = doctors.findById(saved.getUserId()).orElseThrow();

        assertThat(reloaded.getAvailability())
                .containsExactly(
                        new WorkingHours((short) 0, LocalTime.of(9, 0), LocalTime.of(17, 0)),
                        new WorkingHours((short) 3, LocalTime.of(14, 30), LocalTime.of(18, 0))
                );
    }

    @Test
    void defaultsToNoWorkingHours() {
        Doctor saved = doctors.save(profileFor("no-hours@clinic.com"));

        entityManager.flush();
        entityManager.clear();

        assertThat(doctors.findById(saved.getUserId()).orElseThrow().getAvailability())
                .isEmpty();
    }

    private Doctor profileFor(String email) {
        UserAccount account = users.save(new UserAccount(
                email, "{bcrypt}hash", "Doctor Test", Role.DOCTOR
        ));
        return new Doctor(account);
    }
}
