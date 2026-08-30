package com.example.backend.forms;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.FormQuestion;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.FormQuestionRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class DynamicFormControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FormQuestionRepository questions;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void publishedSchemaRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/api/forms/clinical-intake"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void patientSeesPublishedSchema() throws Exception {
        questions.save(newQuestion("test_q", "Test Q", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH));
        users.save(new UserAccount("patient-schema@test.com", passwordEncoder.encode("password"), "T", "U", Role.PATIENT));
        String token = login("patient-schema@test.com");

        mockMvc.perform(get("/api/forms/clinical-intake")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.fieldKey=='test_q')]").isArray());
    }

    @Test
    void publishedSchemaMalePatientSeesOnlyMaleAndBothQuestions() throws Exception {
        questions.save(newQuestion("m_only_1", "MaleQ", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.MALE));
        questions.save(newQuestion("f_only_1", "FemaleQ", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.FEMALE));
        questions.save(newQuestion("both_1", "BothQ", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH));

        UserAccount male = new UserAccount("male-gender@test.com", passwordEncoder.encode("password"), "M", "P", Role.PATIENT);
        male.setGender(UserAccount.Gender.MALE);
        users.save(male);

        String token = login("male-gender@test.com");

        mockMvc.perform(get("/api/forms/clinical-intake")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.fieldKey=='m_only_1')]").isArray())
                .andExpect(jsonPath("$[?(@.fieldKey=='both_1')]").isArray())
                .andExpect(jsonPath("$[?(@.fieldKey=='f_only_1')]").isEmpty());
    }

    @Test
    void publishedSchemaFemalePatientSeesOnlyFemaleAndBothQuestions() throws Exception {
        questions.save(newQuestion("m_only_2", "MaleQ", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.MALE));
        questions.save(newQuestion("f_only_2", "FemaleQ", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.FEMALE));
        questions.save(newQuestion("both_2", "BothQ", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH));

        UserAccount female = new UserAccount("female-gender@test.com", passwordEncoder.encode("password"), "F", "P", Role.PATIENT);
        female.setGender(UserAccount.Gender.FEMALE);
        users.save(female);

        String token = login("female-gender@test.com");

        mockMvc.perform(get("/api/forms/clinical-intake")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.fieldKey=='f_only_2')]").isArray())
                .andExpect(jsonPath("$[?(@.fieldKey=='both_2')]").isArray())
                .andExpect(jsonPath("$[?(@.fieldKey=='m_only_2')]").isEmpty());
    }

    @Test
    void patientReadsOwnAnswers() throws Exception {
        users.save(new UserAccount("patient-ans@test.com", passwordEncoder.encode("password"), "T", "U", Role.PATIENT));
        String token = login("patient-ans@test.com");

        mockMvc.perform(get("/api/forms/clinical-intake/answers/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isMap());
    }

    @Test
    void unauthenticatedCannotReadAnswers() throws Exception {
        mockMvc.perform(get("/api/forms/clinical-intake/answers/me"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void doctorCannotReadPatientAnswers() throws Exception {
        users.save(new UserAccount("doctor-ans@test.com", passwordEncoder.encode("password"), "D", "O", Role.DOCTOR));
        String token = login("doctor-ans@test.com");

        mockMvc.perform(get("/api/forms/clinical-intake/answers/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    @Test
    void patientSavesOwnAnswers() throws Exception {
        deactivateAllQuestions();
        questions.save(newQuestion("save_q1", "SaveQ", FormQuestion.FieldType.BOOLEAN, false, FormQuestion.VisibleForGender.BOTH));
        users.save(new UserAccount("patient-save@test.com", passwordEncoder.encode("password"), "T", "U", Role.PATIENT));
        String token = login("patient-save@test.com");

        mockMvc.perform(put("/api/forms/clinical-intake/answers/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"answers": {"save_q1": true}}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.save_q1").value(true));
    }

    @Test
    void patientCannotSaveMissingRequiredField() throws Exception {
        deactivateAllQuestions();
        questions.save(newQuestion("req_new", "Required", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH));

        users.save(new UserAccount("patient-req@test.com", passwordEncoder.encode("password"), "T", "U", Role.PATIENT));
        String token = login("patient-req@test.com");

        mockMvc.perform(put("/api/forms/clinical-intake/answers/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"answers": {}}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void patientCanSkipOptionalField() throws Exception {
        deactivateAllQuestions();
        questions.save(newQuestion("skip_opt", "Optional", FormQuestion.FieldType.BOOLEAN, false, FormQuestion.VisibleForGender.BOTH));

        users.save(new UserAccount("patient-opt@test.com", passwordEncoder.encode("password"), "T", "U", Role.PATIENT));
        String token = login("patient-opt@test.com");

        mockMvc.perform(put("/api/forms/clinical-intake/answers/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"answers": {}}
                                """))
                .andExpect(status().isOk());
    }

    @Test
    void unauthenticatedCannotSaveAnswers() throws Exception {
        mockMvc.perform(put("/api/forms/clinical-intake/answers/me")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"answers": {}}
                                """))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void adminViewsAllQuestions() throws Exception {
        questions.save(newQuestion("q1", "Q1", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH));
        FormQuestion inactive = newQuestion("q2", "Q2", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH);
        inactive.setActive(false);
        questions.save(inactive);

        users.save(new UserAccount("admin-view@test.com", passwordEncoder.encode("password"), "A", "D", Role.ADMIN));
        String token = login("admin-view@test.com");

        mockMvc.perform(get("/api/forms/clinical-intake/admin/questions")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].fieldKey").value("q1"))
                .andExpect(jsonPath("$[1].fieldKey").value("q2"))
                .andExpect(jsonPath("$[1].active").value(false));
    }

    @Test
    void patientCannotViewAllQuestions() throws Exception {
        users.save(new UserAccount("patient-view@test.com", passwordEncoder.encode("password"), "P", "V", Role.PATIENT));
        String token = login("patient-view@test.com");

        mockMvc.perform(get("/api/forms/clinical-intake/admin/questions")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    @Test
    void adminCreatesQuestion() throws Exception {
        users.save(new UserAccount("admin-create@test.com", passwordEncoder.encode("password"), "A", "C", Role.ADMIN));
        String token = login("admin-create@test.com");

        mockMvc.perform(post("/api/forms/clinical-intake/admin/questions")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "fieldKey": "new_q",
                                  "label": "New Question",
                                  "helpText": "Help text",
                                  "fieldType": "BOOLEAN",
                                  "required": true,
                                  "displayOrder": 1,
                                  "visibleForGender": "BOTH",
                                  "options": []
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fieldKey").value("new_q"))
                .andExpect(jsonPath("$.label").value("New Question"))
                .andExpect(jsonPath("$.active").value(true));

        assertThat(questions.existsByFormKeyAndFieldKey("clinical-intake", "new_q")).isTrue();
    }

    @Test
    void adminCannotCreateDuplicateFieldKey() throws Exception {
        questions.save(newQuestion("duplicate", "Q1", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH));

        users.save(new UserAccount("admin-dup@test.com", passwordEncoder.encode("password"), "A", "D", Role.ADMIN));
        String token = login("admin-dup@test.com");

        mockMvc.perform(post("/api/forms/clinical-intake/admin/questions")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "fieldKey": "duplicate",
                                  "label": "Another",
                                  "fieldType": "BOOLEAN",
                                  "required": false,
                                  "displayOrder": 2,
                                  "visibleForGender": "BOTH"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void adminCreatesSelectQuestionWithOptions() throws Exception {
        users.save(new UserAccount("admin-select@test.com", passwordEncoder.encode("password"), "A", "S", Role.ADMIN));
        String token = login("admin-select@test.com");

        mockMvc.perform(post("/api/forms/clinical-intake/admin/questions")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "fieldKey": "skin_type",
                                  "label": "Skin Type",
                                  "fieldType": "SINGLE_SELECT",
                                  "required": true,
                                  "displayOrder": 1,
                                  "visibleForGender": "BOTH",
                                  "options": [
                                    {"value": "oily", "label": "Oily", "displayOrder": 1},
                                    {"value": "dry", "label": "Dry", "displayOrder": 2}
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fieldType").value("SINGLE_SELECT"))
                .andExpect(jsonPath("$.options[0].value").value("oily"))
                .andExpect(jsonPath("$.options[1].value").value("dry"));
    }

    @Test
    void adminCannotCreateSelectQuestionWithoutOptions() throws Exception {
        users.save(new UserAccount("admin-no-opt@test.com", passwordEncoder.encode("password"), "A", "N", Role.ADMIN));
        String token = login("admin-no-opt@test.com");

        mockMvc.perform(post("/api/forms/clinical-intake/admin/questions")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "fieldKey": "invalid_select",
                                  "label": "Select Without Options",
                                  "fieldType": "SINGLE_SELECT",
                                  "required": false,
                                  "displayOrder": 1,
                                  "visibleForGender": "BOTH",
                                  "options": []
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void patientCannotCreateQuestion() throws Exception {
        users.save(new UserAccount("patient-create@test.com", passwordEncoder.encode("password"), "P", "C", Role.PATIENT));
        String token = login("patient-create@test.com");

        mockMvc.perform(post("/api/forms/clinical-intake/admin/questions")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "fieldKey": "q",
                                  "label": "Q",
                                  "fieldType": "BOOLEAN",
                                  "required": false,
                                  "displayOrder": 1,
                                  "visibleForGender": "BOTH"
                                }
                                """))
                .andExpect(status().isForbidden());
    }

    @Test
    void adminUpdatesQuestion() throws Exception {
        FormQuestion q = newQuestion("q1", "Original", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH);
        UUID id = questions.save(q).getId();

        users.save(new UserAccount("admin-update@test.com", passwordEncoder.encode("password"), "A", "U", Role.ADMIN));
        String token = login("admin-update@test.com");

        mockMvc.perform(put("/api/forms/clinical-intake/admin/questions/{id}", id)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "fieldKey": "q1",
                                  "label": "Updated",
                                  "fieldType": "BOOLEAN",
                                  "required": false,
                                  "displayOrder": 2,
                                  "visibleForGender": "FEMALE"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.label").value("Updated"))
                .andExpect(jsonPath("$.visibleForGender").value("FEMALE"));
    }

    @Test
    void adminCannotUpdateNonexistentQuestion() throws Exception {
        UUID fakeId = UUID.randomUUID();

        users.save(new UserAccount("admin-fake@test.com", passwordEncoder.encode("password"), "A", "F", Role.ADMIN));
        String token = login("admin-fake@test.com");

        mockMvc.perform(put("/api/forms/clinical-intake/admin/questions/{id}", fakeId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "fieldKey": "q1",
                                  "label": "Updated",
                                  "fieldType": "BOOLEAN",
                                  "required": false,
                                  "displayOrder": 1,
                                  "visibleForGender": "BOTH"
                                }
                                """))
                .andExpect(status().isNotFound());
    }

    @Test
    void adminDeactivatesQuestion() throws Exception {
        FormQuestion q = newQuestion("q1", "Q1", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH);
        UUID id = questions.save(q).getId();

        users.save(new UserAccount("admin-deact@test.com", passwordEncoder.encode("password"), "A", "D", Role.ADMIN));
        String token = login("admin-deact@test.com");

        mockMvc.perform(delete("/api/forms/clinical-intake/admin/questions/{id}", id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());

        FormQuestion updated = questions.findById(id).orElseThrow();
        assertThat(updated.isActive()).isFalse();
    }

    @Test
    void adminActivatesQuestion() throws Exception {
        FormQuestion q = newQuestion("q1", "Q1", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH);
        q.setActive(false);
        UUID id = questions.save(q).getId();

        users.save(new UserAccount("admin-act@test.com", passwordEncoder.encode("password"), "A", "A", Role.ADMIN));
        String token = login("admin-act@test.com");

        mockMvc.perform(post("/api/forms/clinical-intake/admin/questions/{id}/activate", id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());

        FormQuestion updated = questions.findById(id).orElseThrow();
        assertThat(updated.isActive()).isTrue();
    }

    @Test
    void patientCannotDeactivateQuestion() throws Exception {
        FormQuestion q = newQuestion("q1", "Q1", FormQuestion.FieldType.BOOLEAN, true, FormQuestion.VisibleForGender.BOTH);
        UUID id = questions.save(q).getId();

        users.save(new UserAccount("patient-deact@test.com", passwordEncoder.encode("password"), "P", "D", Role.PATIENT));
        String token = login("patient-deact@test.com");

        mockMvc.perform(delete("/api/forms/clinical-intake/admin/questions/{id}", id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    private FormQuestion newQuestion(String fieldKey, String label, FormQuestion.FieldType type, boolean required, FormQuestion.VisibleForGender visible) {
        FormQuestion q = new FormQuestion();
        q.setFormKey("clinical-intake");
        q.setFieldKey(fieldKey);
        q.setLabel(label);
        q.setFieldType(type);
        q.setRequired(required);
        q.setDisplayOrder(0);
        q.setVisibleForGender(visible);
        q.setActive(true);
        return q;
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

    private void deactivateAllQuestions() {
        questions.findAll().forEach(q -> {
            q.setActive(false);
            questions.save(q);
        });
    }
}
