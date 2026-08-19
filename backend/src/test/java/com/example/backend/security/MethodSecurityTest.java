package com.example.backend.security;

import com.example.backend.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MethodSecurityTest extends AbstractIntegrationTest {

    private static final UUID SUBJECT = UUID.fromString("11111111-2222-3333-4444-555555555555");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AccessRules access;

    @Test
    @WithMockUser(roles = "DOCTOR")
    void allowsRequestWithRequiredRole() throws Exception {
        mockMvc.perform(get("/test/doctor-only"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void deniesRequestWithoutRequiredRole() throws Exception {
        mockMvc.perform(get("/test/doctor-only"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.title").value("Access Denied"))
                .andExpect(jsonPath("$.requiredRoles").doesNotExist());
    }

    // 401, not 403: the filter chain refuses anonymous callers before method security.
    @Test
    void deniesUnauthenticatedRequest() throws Exception {
        mockMvc.perform(get("/test/doctor-only"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/test/meta/any"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void allowsAuthenticatedRequestToUnrestrictedEndpoint() throws Exception {
        mockMvc.perform(get("/test/open"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "RECEPTIONIST")
    void clinicStaffAnnotationAdmitsReception() throws Exception {
        mockMvc.perform(get("/test/meta/staff"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void clinicStaffAnnotationRejectsPatients() throws Exception {
        mockMvc.perform(get("/test/meta/staff"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminAnnotationAdmitsAdmins() throws Exception {
        mockMvc.perform(get("/test/meta/admin"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "DOCTOR")
    void adminAnnotationRejectsDoctors() throws Exception {
        mockMvc.perform(get("/test/meta/admin"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void patientAnnotationAdmitsPatients() throws Exception {
        mockMvc.perform(get("/test/meta/patient"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "RECEPTIONIST")
    void patientAnnotationRejectsStaff() throws Exception {
        mockMvc.perform(get("/test/meta/patient"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void authenticatedAnnotationAdmitsAnySignedInRole() throws Exception {
        mockMvc.perform(get("/test/meta/any"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "DOCTOR")
    void doctorAnnotationAdmitsDoctors() throws Exception {
        mockMvc.perform(get("/test/meta/doctor"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void doctorAnnotationRejectsPatients() throws Exception {
        mockMvc.perform(get("/test/meta/doctor"))
                .andExpect(status().isForbidden());
    }

    // Ownership is stubbed, so the annotation is what is under test.
    @Test
    @WithMockUser(roles = "RECEPTIONIST")
    void staffOrSelfAdmitsStaffWithoutOwnership() throws Exception {
        mockMvc.perform(get("/test/meta/self/" + SUBJECT))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void staffOrSelfAdmitsMatchingPatient() throws Exception {
        when(access.isSelf(SUBJECT)).thenReturn(true);

        mockMvc.perform(get("/test/meta/self/" + SUBJECT))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void staffOrSelfRejectsDifferentPatient() throws Exception {
        mockMvc.perform(get("/test/meta/self/" + SUBJECT))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "DOCTOR")
    void appointmentOwnerAdmitsStaffWithoutOwnership() throws Exception {
        mockMvc.perform(get("/test/meta/appointment/" + SUBJECT))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void appointmentOwnerAdmitsOwner() throws Exception {
        when(access.ownsAppointment(SUBJECT)).thenReturn(true);

        mockMvc.perform(get("/test/meta/appointment/" + SUBJECT))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void appointmentOwnerRejectsNonOwner() throws Exception {
        mockMvc.perform(get("/test/meta/appointment/" + SUBJECT))
                .andExpect(status().isForbidden());
    }

    @Test
    void healthProbeNeedsNoToken() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk());
    }

    @Test
    void roleAuthorityUsesSpringPrefix() {
        assertThat(Role.DOCTOR.authority().getAuthority()).isEqualTo("ROLE_DOCTOR");
    }
}
