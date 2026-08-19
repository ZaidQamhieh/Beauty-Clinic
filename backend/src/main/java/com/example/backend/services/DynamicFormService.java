package com.example.backend.services;

import com.example.backend.dtos.FormQuestionRequest;
import com.example.backend.dtos.FormQuestionResponse;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.FormQuestion;
import com.example.backend.entities.FormQuestionOption;
import com.example.backend.entities.PatientFormResponse;
import com.example.backend.entities.PatientProfile;
import com.example.backend.repositories.FormQuestionRepository;
import com.example.backend.repositories.PatientFormResponseRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.security.CurrentUser;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DynamicFormService {

    public static final String CLINICAL_INTAKE = "clinical-intake";

    private final FormQuestionRepository questions;
    private final PatientFormResponseRepository responses;
    private final ActivityLogService activityLogs;
    private final PatientProfileRepository patientProfiles;
    private final CurrentUser currentUser;
    // Jackson 2 kept for Hibernate JsonNode.
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Transactional(readOnly = true)
    public List<FormQuestionResponse> schema(boolean includeInactive) {
        List<FormQuestion> rows = includeInactive
                ? questions.findByFormKeyOrderByDisplayOrderAsc(CLINICAL_INTAKE)
                : questions.findByFormKeyAndActiveTrueOrderByDisplayOrderAsc(CLINICAL_INTAKE);

        return rows.stream()
                .map(question -> FormQuestionResponse.of(question, includeInactive))
                .toList();
    }

    @Transactional
    public FormQuestionResponse create(FormQuestionRequest request) {
        if (questions.existsByFormKeyAndFieldKey(CLINICAL_INTAKE, request.fieldKey())) {
            throw bad("A question already uses that field key");
        }

        FormQuestion question = new FormQuestion();
        question.setFormKey(CLINICAL_INTAKE);
        apply(question, request);
        FormQuestion saved = questions.save(question);

        activityLogs.record(
                actor(), null, ActivityAction.FORM_QUESTION_CREATED,
                "form_question", saved.getId());

        return FormQuestionResponse.of(saved, true);
    }

    @Transactional
    public FormQuestionResponse update(UUID id, FormQuestionRequest request) {
        FormQuestion question = require(id);

        if (!question.getFieldKey().equals(request.fieldKey())
                && questions.existsByFormKeyAndFieldKey(CLINICAL_INTAKE, request.fieldKey())) {
            throw bad("A question already uses that field key");
        }

        apply(question, request);

        activityLogs.record(
                actor(), null, ActivityAction.FORM_QUESTION_UPDATED,
                "form_question", question.getId());

        return FormQuestionResponse.of(question, true);
    }

    @Transactional
    public void deactivate(UUID id) {
        require(id).setActive(false);

        activityLogs.record(
                actor(), null, ActivityAction.FORM_QUESTION_DEACTIVATED, "form_question", id);
    }

    @Transactional
    public void activate(UUID id) {
        require(id).setActive(true);

        activityLogs.record(
                actor(), null, ActivityAction.FORM_QUESTION_ACTIVATED, "form_question", id);
    }

    private UUID actor() {
        return currentUser.id().orElse(null);
    }

    @Transactional(readOnly = true)
    @SuppressWarnings("unchecked")
    public Map<String, Object> answers(UUID patientUserId) {
        PatientFormResponse stored = responses.findById(
                new PatientFormResponse.Id(patientUserId, CLINICAL_INTAKE)
        ).orElse(null);

        if (stored == null) {
            return Map.of();
        }

        return objectMapper.convertValue(stored.getAnswers(), Map.class);
    }

    @Transactional
    public Map<String, Object> saveAnswers(UUID actorId, UUID patientUserId, Map<String, Object> submitted) {
        List<FormQuestion> activeQuestions =
                questions.findByFormKeyAndActiveTrueOrderByDisplayOrderAsc(CLINICAL_INTAKE);
        validate(activeQuestions, submitted);

        PatientFormResponse.Id key = new PatientFormResponse.Id(patientUserId, CLINICAL_INTAKE);
        PatientFormResponse stored = responses.findById(key).orElseGet(() -> {
            PatientFormResponse created = new PatientFormResponse();
            created.setId(key);
            created.setAnswers(objectMapper.createObjectNode());
            return created;
        });

        Map<String, Object> merged = new LinkedHashMap<>(
                objectMapper.convertValue(stored.getAnswers(), Map.class)
        );

        for (FormQuestion question : activeQuestions) {
            if (submitted.containsKey(question.getFieldKey())) {
                merged.put(question.getFieldKey(), submitted.get(question.getFieldKey()));
            }
        }

        Map<String, Object> before = previousAnswers(stored, patientUserId);
        Map<String, Object> after = ClinicalAnswers.canonical(merged);

        // Profile changes before anything claims it.
        applyToProfile(patientUserId, submitted);

        stored.setAnswers(objectMapper.valueToTree(merged));
        responses.save(stored);

        // Nothing changed, so nothing happened.
        if (!before.equals(after)) {
            activityLogs.recordClinicalProfileUpdate(
                    actorId, patientUserId,
                    objectMapper.valueToTree(before),
                    objectMapper.valueToTree(after));
        }

        return merged;
    }

    // Falls back to profile when unanswered.
    @SuppressWarnings("unchecked")
    private Map<String, Object> previousAnswers(PatientFormResponse stored, UUID patientUserId) {
        JsonNode answers = stored.getAnswers();

        if (answers != null && !answers.isEmpty()) {
            return ClinicalAnswers.canonical(objectMapper.convertValue(answers, Map.class));
        }

        return patientProfiles.findById(patientUserId)
                .map(ClinicalAnswers::of)
                .orElseGet(Map::of);
    }

    // Rejected values must not read as stored.
    private void applyToProfile(UUID patientUserId, Map<String, Object> submitted) {
        PatientProfile profile = patientProfiles.findById(patientUserId).orElse(null);

        if (profile == null) {
            return;
        }

        if (submitted.get(ClinicalAnswers.PREGNANT) instanceof Boolean pregnant) {
            profile.setPregnantBreastfeeding(pregnant);
        }

        if (submitted.get(ClinicalAnswers.SKIN_TYPE) instanceof String skin && !skin.isBlank()) {
            profile.setSkinType(constant(PatientProfile.SkinType.class, skin, "Skin type"));
        }

        if (submitted.get(ClinicalAnswers.SMOKING) instanceof String smoking && !smoking.isBlank()) {
            profile.setSmokingStatus(
                    constant(PatientProfile.SmokingStatus.class, smoking, "Smoking status"));
        }

        List<PatientProfile.Allergy> allergies = constants(
                PatientProfile.Allergy.class, submitted.get(ClinicalAnswers.ALLERGIES), "Allergies");
        if (allergies != null) {
            profile.setAllergies(allergies);
        }

        List<PatientProfile.Medication> medications = constants(
                PatientProfile.Medication.class, submitted.get(ClinicalAnswers.MEDICATIONS), "Medications");
        if (medications != null) {
            profile.setMedications(medications);
        }

        List<PatientProfile.ChronicCondition> conditions = constants(
                PatientProfile.ChronicCondition.class,
                submitted.get(ClinicalAnswers.CONDITIONS), "Chronic conditions");
        if (conditions != null) {
            profile.setChronicConditions(conditions);
        }

        patientProfiles.save(profile);
    }

    // An unholdable option is rejected.
    private <E extends Enum<E>> E constant(Class<E> type, String value, String label) {
        try {
            return Enum.valueOf(type, value.toUpperCase());
        } catch (IllegalArgumentException unknown) {
            throw bad(label + " has an option the patient record cannot store");
        }
    }

    private <E extends Enum<E>> List<E> constants(Class<E> type, Object value, String label) {
        if (!(value instanceof List<?> items)) {
            return null;
        }

        List<E> mapped = new ArrayList<>();

        for (Object item : items) {
            if (!(item instanceof String name)) {
                continue;
            }

            E constant = constant(type, name, label);

            if (!mapped.contains(constant)) {
                mapped.add(constant);
            }
        }

        return mapped;
    }

    private void apply(FormQuestion question, FormQuestionRequest request) {
        question.setFieldKey(request.fieldKey());
        question.setLabel(request.label());
        question.setHelpText(request.helpText());
        question.setFieldType(request.fieldType());
        question.setRequired(request.required());
        question.setDisplayOrder(request.displayOrder());

        if (request.fieldType() == FormQuestion.FieldType.BOOLEAN) {
            question.getOptions().clear();
            return;
        }

        if (request.options() == null || request.options().isEmpty()) {
            throw bad("Select questions need at least one option");
        }

        var existingByValue = question.getOptions().stream()
                .collect(java.util.stream.Collectors.toMap(
                        FormQuestionOption::getValue,
                        option -> option,
                        (left, right) -> left
                ));
        var requestedValues = new HashSet<String>();
        for (FormQuestionRequest.FormOptionRequest optionRequest : request.options()) {
            if (!requestedValues.add(optionRequest.value())) {
                throw bad("Option values must be unique");
            }

            FormQuestionOption option = existingByValue.get(optionRequest.value());
            if (option == null) {
                option = new FormQuestionOption();
                option.setQuestion(question);
                question.getOptions().add(option);
            }
            option.setValue(optionRequest.value());
            option.setLabel(optionRequest.label());
            option.setDisplayOrder(optionRequest.displayOrder());
            option.setActive(true);
        }

        question.getOptions().removeIf(option -> !requestedValues.contains(option.getValue()));
    }

    private void validate(List<FormQuestion> activeQuestions, Map<String, Object> submitted) {
        for (FormQuestion question : activeQuestions) {
            Object value = submitted.get(question.getFieldKey());

            if (value == null) {
                if (question.isRequired()) {
                    throw bad(question.getLabel() + " is required");
                }
                continue;
            }

            if (question.getFieldType() == FormQuestion.FieldType.BOOLEAN) {
                if (!(value instanceof Boolean)) {
                    throw bad(question.getLabel() + " must be true or false");
                }
                continue;
            }

            Set<String> allowedValues = question.getOptions().stream()
                    .filter(FormQuestionOption::isActive)
                    .map(FormQuestionOption::getValue)
                    .collect(java.util.stream.Collectors.toSet());

            if (question.getFieldType() == FormQuestion.FieldType.SINGLE_SELECT) {
                if (!(value instanceof String selected) || (!allowedValues.isEmpty() && !allowedValues.contains(selected))) {
                    throw bad(question.getLabel() + " must be one of the listed options");
                }
                continue;
            }

            if (value instanceof List<?> selected) {
                if (!allowedValues.isEmpty() && selected.stream().anyMatch(
                        item -> !(item instanceof String chosen) || !allowedValues.contains(chosen)
                )) {
                    throw bad(question.getLabel() + " contains an unrecognised option");
                }
            }
        }
    }

    private FormQuestion require(UUID id) {
        return questions.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such question"));
    }

    private ResponseStatusException bad(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }
}
