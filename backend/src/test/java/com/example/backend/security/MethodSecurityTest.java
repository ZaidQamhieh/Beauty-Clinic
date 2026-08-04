package com.example.backend.security;

import com.example.backend.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MethodSecurityTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

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

    @Test
    void deniesUnauthenticatedRequest() throws Exception {
        mockMvc.perform(get("/test/doctor-only"))
                .andExpect(status().is4xxClientError());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void allowsAuthenticatedRequestToUnrestrictedEndpoint() throws Exception {
        mockMvc.perform(get("/test/open"))
                .andExpect(status().isOk());
    }

    @Test
    void roleAuthorityUsesSpringPrefix() {
        assertThat(Role.DOCTOR.authority().getAuthority()).isEqualTo("ROLE_DOCTOR");
    }
}
