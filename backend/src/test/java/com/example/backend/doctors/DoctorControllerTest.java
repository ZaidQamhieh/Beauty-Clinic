package com.example.backend.doctors;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.dtos.CreateDoctorAvailabilityRequest;
import com.example.backend.dtos.DoctorProfileRequest;
import com.example.backend.dtos.SplitDoctorAvailabilityRequest;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.DoctorProfile.Specialization;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.DoctorAvailabilityRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.example.backend.services.AccessTokenService;
import tools.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.security.core.context.SecurityContextHolder.getContext;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DoctorControllerTest extends AbstractIntegrationTest {

    private static final LocalDate TODAY = LocalDate.now();

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private DoctorProfileRepository doctorProfileRepository;

    @Autowired
    private UserAccountRepository userAccountRepository;

    @Autowired
    private DoctorAvailabilityRepository availabilityRepository;

    @Autowired
    private TransactionTemplate transactions;

    private JwtAuthenticationToken adminToken;
    private JwtAuthenticationToken doctorToken;
    private JwtAuthenticationToken patientToken;
    private UUID doctorId;
    private UUID adminId;
    private UUID patientId;

    @BeforeEach
    void setupTokens() {
        String unique = UUID.randomUUID().toString().substring(0, 8);

        doctorId = transactions.execute(status -> {
            UserAccount doc = userAccountRepository.save(
                    new UserAccount("doc-" + unique + "@example.com", "hash",
                            "Dr", "Test", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(doc);
            doctorProfileRepository.save(profile);
            return doc.getId();
        });

        adminId = transactions.execute(status -> {
            UserAccount admin = userAccountRepository.save(
                    new UserAccount("admin-" + unique + "@example.com", "hash",
                            "Admin", "User", Role.ADMIN));
            return admin.getId();
        });

        patientId = transactions.execute(status -> {
            UserAccount patient = userAccountRepository.save(
                    new UserAccount("patient-" + unique + "@example.com", "hash",
                            "Patient", "User", Role.PATIENT));
            return patient.getId();
        });

        adminToken = createToken(adminId, Role.ADMIN);
        doctorToken = createToken(doctorId, Role.DOCTOR);
        patientToken = createToken(patientId, Role.PATIENT);
    }

    @AfterEach
    void clearContext() {
        getContext().setAuthentication(null);
    }

    @Test
    void listDoctorsAuthenticatedOnly() throws Exception {
        mockMvc.perform(get("/api/doctors")
                .with(authentication(doctorToken)))
                .andExpect(status().isOk());
    }

    @Test
    void listDoctorsRejectsUnauthenticated() throws Exception {
        mockMvc.perform(get("/api/doctors"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void readDoctorAuthenticatedOnly() throws Exception {
        mockMvc.perform(get("/api/doctors/" + doctorId)
                .with(authentication(doctorToken)))
                .andExpect(status().isOk());
    }

    @Test
    void readDoctorNotFound() throws Exception {
        UUID fakeId = UUID.randomUUID();
        mockMvc.perform(get("/api/doctors/" + fakeId)
                .with(authentication(doctorToken)))
                .andExpect(status().isNotFound());
    }

    @Test
    void registerDoctorAdminOnly() throws Exception {
        UUID newDoctorId = transactions.execute(status -> {
            UserAccount account = userAccountRepository.save(
                    new UserAccount("newdoc@example.com", "hash", "New", "Doc", Role.DOCTOR));
            return account.getId();
        });

        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.DERMATOLOGY), 5);

        mockMvc.perform(post("/api/doctors/" + newDoctorId)
                .with(authentication(adminToken))
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }

    @Test
    void registerDoctorRejectsDoctorSelf() throws Exception {
        String email = "newdoc-" + UUID.randomUUID().toString().substring(0, 8) + "@test.com";
        UUID newDoctorId = transactions.execute(status -> {
            UserAccount account = userAccountRepository.save(
                    new UserAccount(email, "hash", "New", "Doc", Role.DOCTOR));
            return account.getId();
        });

        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.DERMATOLOGY), 5);

        mockMvc.perform(post("/api/doctors/" + newDoctorId)
                .with(authentication(doctorToken))
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isForbidden());
    }

    @Test
    void updateProfileDoctorSelfAllowed() throws Exception {
        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.COSMETIC_DERMATOLOGY), 10);

        mockMvc.perform(put("/api/doctors/" + doctorId)
                .with(authentication(doctorToken))
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }

    @Test
    void updateProfileAdminAllowed() throws Exception {
        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.COSMETIC_DERMATOLOGY), 10);

        mockMvc.perform(put("/api/doctors/" + doctorId)
                .with(authentication(adminToken))
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }

    @Test
    void updateProfileRejectsOtherDoctor() throws Exception {
        DoctorProfileRequest request = new DoctorProfileRequest(
                List.of(Specialization.COSMETIC_DERMATOLOGY), 10);

        mockMvc.perform(put("/api/doctors/" + doctorId)
                .with(authentication(doctorToken))
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }

    @Test
    void deleteDoctorAdminOnly() throws Exception {
        UUID targetDoctorId = transactions.execute(status -> {
            UserAccount account = userAccountRepository.save(
                    new UserAccount("target@example.com", "hash", "Target", "Doc", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(account);
            doctorProfileRepository.save(profile);
            return account.getId();
        });

        mockMvc.perform(delete("/api/doctors/" + targetDoctorId)
                .with(authentication(adminToken)))
                .andExpect(status().isNoContent());
    }

    @Test
    void deleteDoctorRejectsDoctorSelf() throws Exception {
        mockMvc.perform(delete("/api/doctors/" + doctorId)
                .with(authentication(doctorToken)))
                .andExpect(status().isForbidden());
    }

    @Test
    void addAvailabilityDoctorSelfOrAdmin() throws Exception {
        CreateDoctorAvailabilityRequest request = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.REGULAR,
                DayOfWeek.MONDAY,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TODAY,
                null,
                false);

        mockMvc.perform(post("/api/doctors/" + doctorId + "/availability")
                .with(authentication(doctorToken))
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }

    @Test
    void addAvailabilityRejectsPatient() throws Exception {
        CreateDoctorAvailabilityRequest request = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.REGULAR,
                DayOfWeek.MONDAY,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TODAY,
                null,
                false);

        mockMvc.perform(post("/api/doctors/" + doctorId + "/availability")
                .with(authentication(patientToken))
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isForbidden());
    }

    @Test
    void updateAvailabilityDoctorSelfOrAdmin() throws Exception {
        UUID availId = transactions.execute(status -> {
            DoctorProfile doctor = doctorProfileRepository.findById(doctorId).orElseThrow();
            DoctorAvailability avail = new DoctorAvailability(
                    doctor, AvailabilityKind.REGULAR, DayOfWeek.MONDAY,
                    LocalTime.of(9, 0), LocalTime.of(17, 0), TODAY);
            DoctorAvailability saved = availabilityRepository.save(avail);
            return saved.getId();
        });

        CreateDoctorAvailabilityRequest request = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.REGULAR,
                DayOfWeek.MONDAY,
                LocalTime.of(8, 0),
                LocalTime.of(18, 0),
                TODAY,
                null,
                false);

        mockMvc.perform(put("/api/doctors/" + doctorId + "/availability/" + availId)
                .with(authentication(doctorToken))
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }

    @Test
    void splitAvailabilityDoctorSelfOrAdmin() throws Exception {
        UUID availId = transactions.execute(status -> {
            DoctorProfile doctor = doctorProfileRepository.findById(doctorId).orElseThrow();
            DoctorAvailability avail = new DoctorAvailability(
                    doctor, AvailabilityKind.MODIFIED, null,
                    LocalTime.of(9, 0), LocalTime.of(17, 0), TODAY.plusDays(1));
            avail.setEffectiveTo(TODAY.plusDays(7));
            DoctorAvailability saved = availabilityRepository.save(avail);
            return saved.getId();
        });

        LocalDate splitDate = TODAY.plusDays(3);

        SplitDoctorAvailabilityRequest request = new SplitDoctorAvailabilityRequest(
                splitDate, null);

        mockMvc.perform(post("/api/doctors/" + doctorId + "/availability/" + availId + "/split")
                .with(authentication(doctorToken))
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }

    private JwtAuthenticationToken createToken(UUID userId, Role role) {
        Jwt token = Jwt.withTokenValue("test")
                .header("alg", "none")
                .claim(AccessTokenService.USER_ID_CLAIM, userId.toString())
                .build();

        return new JwtAuthenticationToken(token, List.of(role.authority()));
    }
}
