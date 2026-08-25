package com.example.backend.activity;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.ActivityLogRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class ActivityLogControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private ActivityLogRepository activityLogs;

    @Autowired
    private PatientProfileRepository patientProfiles;

    @Test
    @WithMockUser(roles = "ADMIN")
    void returnsNamesWithoutIds() throws Exception {
        UserAccount actor = users.save(new UserAccount(
                "actor@example.com", "hash", "Alex", "Admin", Role.ADMIN));
        UserAccount patient = users.save(new UserAccount(
                "patient@example.com", "hash", "Pat", "Ient", Role.PATIENT));
        patientProfiles.save(new PatientProfile(patient));
        activityLogs.save(ActivityLog.onEntity(
                actor.getId(), patient.getId(), ActivityAction.PROFILE_UPDATED,
                "user_account", UUID.randomUUID()));

        mockMvc.perform(get("/api/activity-logs")
                        .param("search", "actor@example.com")
                        .param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].actorName").value("Alex Admin"))
                .andExpect(jsonPath("$.content[0].patientName").value("Pat Ient"))
                .andExpect(jsonPath("$.content[0].id").doesNotExist())
                .andExpect(jsonPath("$.content[0].userId").doesNotExist())
                .andExpect(jsonPath("$.content[0].patientUserId").doesNotExist())
                .andExpect(jsonPath("$.content[0].entityId").doesNotExist());
    }
}
