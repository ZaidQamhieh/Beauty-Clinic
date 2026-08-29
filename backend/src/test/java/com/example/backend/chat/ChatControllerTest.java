package com.example.backend.chat;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.dtos.ChatReply;
import com.example.backend.dtos.ChatRequest;
import com.example.backend.dtos.ChatTurn;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import tools.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class ChatControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void unauthenticatedCannotChat() throws Exception {
        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": "Hello"}
                                """))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void patientCanChat() throws Exception {
        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": "What treatments do you offer?"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.text").isNotEmpty())
                .andExpect(jsonPath("$.wrote").isBoolean());
    }

    @Test
    @WithMockUser(roles = "DOCTOR")
    void doctorCanChat() throws Exception {
        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": "What services exist?"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.text").isNotEmpty());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void chatWithEmptyMessageFails() throws Exception {
        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": ""}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void chatWithOversizedMessageFails() throws Exception {
        String longMessage = "x".repeat(301);

        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": "%s"}
                                """.formatted(longMessage)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void chatAcceptsHistory() throws Exception {
        List<ChatTurn> history = List.of(
                new ChatTurn(true, "What is your name?"),
                new ChatTurn(false, "I am Yasmine")
        );

        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new ChatRequest("Can you help?", history)
                        )))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.text").isNotEmpty());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void chatRejectsOversizedHistory() throws Exception {
        List<ChatTurn> largeTurns = List.of(
                new ChatTurn(true, "x".repeat(4001))
        );

        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new ChatRequest("Hello", largeTurns)
                        )))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void chatRejectsMoreThan40HistoryItems() throws Exception {
        List<ChatTurn> manyTurns = new java.util.ArrayList<>();
        for (int i = 0; i < 41; i++) {
            manyTurns.add(new ChatTurn(true, "Message " + i));
        }

        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new ChatRequest("Hello", manyTurns)
                        )))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(roles = "PATIENT", username = "patient@test.com")
    void chatReturnsWroteFlag() throws Exception {
        MvcResult result = mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": "What time is it?"}
                                """))
                .andExpect(status().isOk())
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();
        ChatReply reply = objectMapper.readValue(responseBody, ChatReply.class);

        assertThat(reply.text()).isNotEmpty();
        assertThat(reply.wrote()).isFalse();
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void chatWithoutRoleRejection() throws Exception {
        // All authenticated users allowed.
        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": "Hello?"}
                                """))
                .andExpect(status().isOk());
    }

    @Test
    void chatHistoryWithNullTextHandled() throws Exception {
        // Null text in history gracefully.
        users.save(new UserAccount(
                "chat@test.com",
                passwordEncoder.encode("password"),
                "Test",
                "User",
                Role.PATIENT
        ));

        List<ChatTurn> historyWithNull = List.of(
                new ChatTurn(true, null)
        );

        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new ChatRequest("Hello", historyWithNull)
                        ))
                        .header("Authorization", "Bearer mock"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void chatNullMessageFails() throws Exception {
        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": null}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminCanChat() throws Exception {
        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": "Tell me about today."}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.text").isNotEmpty());
    }

    @Test
    @WithMockUser(roles = "RECEPTIONIST")
    void receptionistCanChat() throws Exception {
        mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": "Hello"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.text").isNotEmpty());
    }

    @Test
    @WithMockUser(roles = "PATIENT")
    void chatReplyStructureIsValid() throws Exception {
        MvcResult result = mockMvc.perform(post("/api/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message": "Hi"}
                                """))
                .andExpect(status().isOk())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        ChatReply reply = objectMapper.readValue(body, ChatReply.class);

        assertThat(reply).isNotNull();
        assertThat(reply.text()).isNotNull();
        assertThat(reply.text()).isNotEmpty();
    }
}
