package com.example.backend.appointments;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.services.AppointmentService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// Staff read a named patient's visits.
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class StaffPatientAppointmentsTest extends AbstractIntegrationTest {

    private static final UUID PATIENT = UUID.fromString("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AppointmentService appointments;

    @Test
    @WithMockUser(roles = "RECEPTIONIST")
    void staffReadUpcomingForNamedPatient() throws Exception {
        when(appointments.readUpcomingFor(eq(PATIENT), any())).thenReturn(Page.empty());

        mockMvc.perform(get("/api/appointments/patients/" + PATIENT + "/upcoming"))
                .andExpect(status().isOk());

        // Path id reaches the service, not caller's.
        verify(appointments).readUpcomingFor(eq(PATIENT), any(Pageable.class));
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void staffReadHistoryForNamedPatient() throws Exception {
        when(appointments.readHistoryFor(eq(PATIENT), any())).thenReturn(Page.empty());

        mockMvc.perform(get("/api/appointments/patients/" + PATIENT + "/history"))
                .andExpect(status().isOk());

        verify(appointments).readHistoryFor(eq(PATIENT), any(Pageable.class));
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void patientsAreDeniedTheStaffRoutes() throws Exception {
        mockMvc.perform(get("/api/appointments/patients/" + PATIENT + "/upcoming"))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/appointments/patients/" + PATIENT + "/history"))
                .andExpect(status().isForbidden());
    }

    // Unknown ids read as an empty page.
    @Test
    @WithMockUser(roles = "DOCTOR")
    void unknownPatientReadsAsEmpty() throws Exception {
        UUID unknown = UUID.randomUUID();
        when(appointments.readUpcomingFor(eq(unknown), any())).thenReturn(Page.empty());

        mockMvc.perform(get("/api/appointments/patients/" + unknown + "/upcoming"))
                .andExpect(status().isOk());
    }
}
