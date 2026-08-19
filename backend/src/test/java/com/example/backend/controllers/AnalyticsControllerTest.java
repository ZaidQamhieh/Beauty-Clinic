package com.example.backend.controllers;

import com.example.backend.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AnalyticsControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminCanAccessAnalytics() throws Exception {
        mockMvc.perform(get("/api/admin/analytics")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.overview").exists())
                .andExpect(jsonPath("$.serviceAnalytics").exists())
                .andExpect(jsonPath("$.doctorAnalytics").exists())
                .andExpect(jsonPath("$.appointmentAnalytics").exists())
                .andExpect(jsonPath("$.patientAnalytics").exists())
                .andExpect(jsonPath("$.operations").exists());
    }

    @Test
    @WithMockUser(roles = "DOCTOR")
    void doctorIsForbiddenFromAdminAnalytics() throws Exception {
        mockMvc.perform(get("/api/admin/analytics")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void patientIsForbiddenFromAdminAnalytics() throws Exception {
        mockMvc.perform(get("/api/admin/analytics")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isForbidden());
    }

    @Test
    void unauthenticatedRequestIsRejected() throws Exception {
        mockMvc.perform(get("/api/admin/analytics")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized());
    }
}
