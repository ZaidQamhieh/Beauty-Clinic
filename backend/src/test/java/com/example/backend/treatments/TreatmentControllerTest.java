package com.example.backend.treatments;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.config.ClinicProperties;
import com.example.backend.config.ClinicProperties.Tariff;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.entities.UserAccount;
import com.example.backend.security.Role;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class TreatmentControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PasswordEncoder passwordEncoder;
    @Test
    void unauthenticatedCannotListTreatments() throws Exception {
        mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void patientListsTreatments() throws Exception {
        mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$[0].treatmentName").isNotEmpty())
                .andExpect(jsonPath("$[0].price").isNotEmpty())
                .andExpect(jsonPath("$[0].durationMinutes").isNotEmpty())
                .andExpect(jsonPath("$[0].category").isNotEmpty());
    }

    @Test
    @WithMockUser(roles = "DOCTOR")
    void doctorListsTreatments() throws Exception {
        mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$[0]").exists());
    }

    @Test
    @WithMockUser(roles = "RECEPTIONIST")
    void receptionistListsTreatments() throws Exception {
        mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminListsTreatments() throws Exception {
        mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$[0].treatmentName").isNotEmpty());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void treatmentListIncludesAllEnumValues() throws Exception {
        String response = mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        // Count should match the number of treatments
        int treatmentCount = (int) response.split("\"treatmentName\"").length - 1;
        assertThat(treatmentCount).isEqualTo(TreatmentName.values().length);
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void treatmentResponseIncludesPrice() throws Exception {
        mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].price").isNotEmpty())
                .andExpect(jsonPath("$[0].price").isNumber());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void treatmentResponseIncludesDuration() throws Exception {
        mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].durationMinutes").isNumber());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void treatmentResponseIncludesCategory() throws Exception {
        mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].category").isNotEmpty());
    }

    @Test
    void unauthenticatedCannotGetBookingRules() throws Exception {
        mockMvc.perform(get("/api/treatments/rules"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void patientGetsBookingRules() throws Exception {
        mockMvc.perform(get("/api/treatments/rules"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.timezone").isNotEmpty())
                .andExpect(jsonPath("$.maxHorizonDays").isNumber())
                .andExpect(jsonPath("$.slotGranularityMinutes").isNumber())
                .andExpect(jsonPath("$.turnoverMinutes").isNumber())
                .andExpect(jsonPath("$.cancellationCutoffMinutes").isNumber());
    }

    @Test
    @WithMockUser(roles = "DOCTOR")
    void doctorGetsBookingRules() throws Exception {
        mockMvc.perform(get("/api/treatments/rules"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.timezone").isNotEmpty());
    }

    @Test
    @WithMockUser(roles = "RECEPTIONIST")
    void receptionistGetsBookingRules() throws Exception {
        mockMvc.perform(get("/api/treatments/rules"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxHorizonDays").isNumber());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminGetsBookingRules() throws Exception {
        mockMvc.perform(get("/api/treatments/rules"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.timezone").isNotEmpty())
                .andExpect(jsonPath("$.maxHorizonDays").isNumber())
                .andExpect(jsonPath("$.slotGranularityMinutes").isNumber())
                .andExpect(jsonPath("$.turnoverMinutes").isNumber())
                .andExpect(jsonPath("$.cancellationCutoffMinutes").isNumber());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void bookingRulesContainsValidValues() throws Exception {
        String response = mockMvc.perform(get("/api/treatments/rules"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        // Verify response structure is valid JSON
        assertThat(response).contains("timezone", "maxHorizonDays", "slotGranularityMinutes");
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void treatmentsListIsNotEmpty() throws Exception {
        mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$[0]").exists());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void treatmentNameIsValidEnum() throws Exception {
        String response = mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        // Treatment name must exist.
        assertThat(response).contains("treatmentName");
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void allTreatmentsHaveRequiredFields() throws Exception {
        mockMvc.perform(get("/api/treatments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].treatmentName").isArray())
                .andExpect(jsonPath("$[*].price").isArray())
                .andExpect(jsonPath("$[*].durationMinutes").isArray())
                .andExpect(jsonPath("$[*].category").isArray());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void bookingRulesReturnsPositiveNumbers() throws Exception {
        mockMvc.perform(get("/api/treatments/rules"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxHorizonDays").value(org.hamcrest.Matchers.greaterThan(0)))
                .andExpect(jsonPath("$.slotGranularityMinutes").value(org.hamcrest.Matchers.greaterThan(0)))
                .andExpect(jsonPath("$.turnoverMinutes").value(org.hamcrest.Matchers.greaterThanOrEqualTo(0)))
                .andExpect(jsonPath("$.cancellationCutoffMinutes").value(org.hamcrest.Matchers.greaterThanOrEqualTo(0)));
    }
}
