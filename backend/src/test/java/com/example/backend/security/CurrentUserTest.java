package com.example.backend.security;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class CurrentUserTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void tokenCarriesTheAccountIdBackToTheRequest() throws Exception {
        UserAccount account = newAccount("current-user@example.com");
        String accessToken = login("current-user@example.com");

        mockMvc.perform(get("/test/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(content().string(account.getId().toString()));
    }

    @Test
    void ownershipRuleAllowsTheOwner() throws Exception {
        UserAccount account = newAccount("owner@example.com");
        String accessToken = login("owner@example.com");

        mockMvc.perform(get("/test/owned-by/" + account.getId())
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk());
    }

    @Test
    void ownershipRuleRejectsEveryoneElse() throws Exception {
        newAccount("not-the-owner@example.com");
        String accessToken = login("not-the-owner@example.com");

        mockMvc.perform(get("/test/owned-by/" + UUID.randomUUID())
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isForbidden());
    }

    private UserAccount newAccount(String email) {
        return users.save(new UserAccount(
                email,
                passwordEncoder.encode("password"),
                "Test",
                "User",
                Role.PATIENT
        ));
    }

    private String login(String email) throws Exception {
        String body = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "%s",
                                  "password": "password"
                                }
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(body, "$.accessToken");
    }
}
