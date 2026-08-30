package com.example.backend.doctors;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.dtos.DoctorProfileRequest;
import com.example.backend.dtos.DoctorResponse;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.DoctorProfile.Specialization;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.security.Role;
import com.example.backend.services.DoctorService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
class DoctorServiceTest extends AbstractIntegrationTest {

    @Autowired
    private DoctorService doctorService;

    @Autowired
    private DoctorProfileRepository doctorProfileRepository;

    @Autowired
    private UserAccountRepository userAccountRepository;

    @Autowired
    private AppointmentSessionRepository sessionRepository;

    @Autowired
    private TransactionTemplate transactions;

    @Test
    void registerCreatesNewDoctor() {
        String email = "doc-" + UUID.randomUUID().toString().substring(0, 8) + "@test.com";
        UUID userId = transactions.execute(status -> {
            UserAccount account = userAccountRepository.save(
                    new UserAccount(email, "hash", "Dr", "Test", Role.DOCTOR));
            return account.getId();
        });

        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.DERMATOLOGY), 5);

        DoctorResponse response = doctorService.register(userId, request);

        assertThat(response.userId()).isEqualTo(userId);
        assertThat(response.specializations()).contains(Specialization.DERMATOLOGY);
        assertThat(response.yearsOfExperience()).isEqualTo(5);
    }

    @Test
    void registerRejectsNonexistentAccount() {
        UUID fakeId = UUID.randomUUID();
        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.DERMATOLOGY), 5);

        assertThatThrownBy(() -> doctorService.register(fakeId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void registerRejectsNonDoctorAccount() {
        String email = "staff-" + UUID.randomUUID().toString().substring(0, 8) + "@test.com";
        UUID userId = transactions.execute(status -> {
            UserAccount account = userAccountRepository.save(
                    new UserAccount(email, "hash", "Staff", "User", Role.RECEPTIONIST));
            return account.getId();
        });

        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.DERMATOLOGY), 5);

        assertThatThrownBy(() -> doctorService.register(userId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void registerRejectsAlreadyRegisteredDoctor() {
        String email = "doc2-" + UUID.randomUUID().toString().substring(0, 8) + "@test.com";
        UUID userId = transactions.execute(status -> {
            UserAccount account = userAccountRepository.save(
                    new UserAccount(email, "hash", "Dr", "Test", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(account);
            profile.setSpecializations(List.of(Specialization.DERMATOLOGY));
            doctorProfileRepository.save(profile);
            return account.getId();
        });

        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.COSMETIC_DERMATOLOGY), 3);

        assertThatThrownBy(() -> doctorService.register(userId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void listReturnsAllDoctors() {
        String email1 = "alice-" + UUID.randomUUID().toString().substring(0, 8) + "@test.com";
        String email2 = "bob-" + UUID.randomUUID().toString().substring(0, 8) + "@test.com";
        transactions.execute(status -> {
            userAccountRepository.save(new UserAccount(
                    email1, "hash", "Alice", "Doctor", Role.DOCTOR));
            userAccountRepository.save(new UserAccount(
                    email2, "hash", "Bob", "Doctor", Role.DOCTOR));
            return null;
        });

        List<DoctorResponse> response = doctorService.list();

        assertThat(response).hasSizeGreaterThanOrEqualTo(2);
    }

    @Test
    void readReturnsDoctor() {
        String email = "doc3-" + UUID.randomUUID().toString().substring(0, 8) + "@test.com";
        UUID userId = transactions.execute(status -> {
            UserAccount account = userAccountRepository.save(
                    new UserAccount(email, "hash", "Dr", "Test", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(account);
            profile.setSpecializations(List.of(Specialization.DERMATOLOGY));
            doctorProfileRepository.save(profile);
            return account.getId();
        });

        DoctorResponse response = doctorService.read(userId);

        assertThat(response.userId()).isEqualTo(userId);
        assertThat(response.specializations()).contains(Specialization.DERMATOLOGY);
    }

    @Test
    void readThrowsForMissingDoctor() {
        UUID fakeId = UUID.randomUUID();

        assertThatThrownBy(() -> doctorService.read(fakeId))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void updateProfileChangesSpecializations() {
        String email = "doc4-" + UUID.randomUUID().toString().substring(0, 8) + "@test.com";
        UUID userId = transactions.execute(status -> {
            UserAccount account = userAccountRepository.save(
                    new UserAccount(email, "hash", "Dr", "Test", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(account);
            profile.setSpecializations(List.of(Specialization.DERMATOLOGY));
            profile.setYearsOfExperience(5);
            doctorProfileRepository.save(profile);
            return account.getId();
        });

        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.COSMETIC_DERMATOLOGY, Specialization.LASER_THERAPY), 10);

        DoctorResponse response = doctorService.updateProfile(userId, request);

        assertThat(response.specializations())
                .containsExactlyInAnyOrder(Specialization.COSMETIC_DERMATOLOGY, Specialization.LASER_THERAPY);
        assertThat(response.yearsOfExperience()).isEqualTo(10);
    }

    @Test
    void updateProfileThrowsForMissingDoctor() {
        UUID fakeId = UUID.randomUUID();
        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.DERMATOLOGY), 5);

        assertThatThrownBy(() -> doctorService.updateProfile(fakeId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void updateProfileHandlesDuplicateSpecializations() {
        String email = "doc5-" + UUID.randomUUID().toString().substring(0, 8) + "@test.com";
        UUID userId = transactions.execute(status -> {
            UserAccount account = userAccountRepository.save(
                    new UserAccount(email, "hash", "Dr", "Test", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(account);
            doctorProfileRepository.save(profile);
            return account.getId();
        });

        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.DERMATOLOGY, Specialization.DERMATOLOGY), 5);

        DoctorResponse response = doctorService.updateProfile(userId, request);

        assertThat(response.specializations())
                .containsExactly(Specialization.DERMATOLOGY);
    }

    @Test
    void deleteRemovesDoctor() {
        String email = "doc6-" + UUID.randomUUID().toString().substring(0, 8) + "@test.com";
        UUID userId = transactions.execute(status -> {
            UserAccount account = userAccountRepository.save(
                    new UserAccount(email, "hash", "Dr", "Test", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(account);
            doctorProfileRepository.save(profile);
            return account.getId();
        });

        doctorService.delete(userId);

        assertThat(doctorProfileRepository.findById(userId)).isEmpty();
    }

    @Test
    void deleteThrowsForMissingDoctor() {
        UUID fakeId = UUID.randomUUID();

        assertThatThrownBy(() -> doctorService.delete(fakeId))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.NOT_FOUND);
    }
}

