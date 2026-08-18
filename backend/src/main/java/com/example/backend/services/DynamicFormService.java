package com.example.backend.services;

import com.example.backend.dtos.FormQuestionRequest;
import com.example.backend.dtos.FormQuestionResponse;
import com.example.backend.entities.FormQuestion;
import com.example.backend.entities.FormQuestionOption;
import com.example.backend.entities.PatientFormResponse;
import com.example.backend.repositories.FormQuestionRepository;
import com.example.backend.repositories.PatientFormResponseRepository;
import com.example.backend.services.ActivityLogService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

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
    // Spring Boot 4's web stack uses Jackson 3; Hibernate JSONB mapping still
    // uses Jackson 2, so we keep a local mapper like PatientProfileService.
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
        return FormQuestionResponse.of(questions.save(question), true);
    }

    @Transactional
    public FormQuestionResponse update(UUID id, FormQuestionRequest request) {
        FormQuestion question = require(id);

        if (!question.getFieldKey().equals(request.fieldKey())
                && questions.existsByFormKeyAndFieldKey(CLINICAL_INTAKE, request.fieldKey())) {
            throw bad("A question already uses that field key");
        }

        apply(question, request);
        return FormQuestionResponse.of(question, true);
    }

    @Transactional
    public void deactivate(UUID id) {
        require(id).setActive(false);
    }

    @Transactional
    public void activate(UUID id) {
        require(id).setActive(true);
    }

    @Transactional(readOnly = true)
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
            merged.put(question.getFieldKey(), submitted.get(question.getFieldKey()));
        }

        JsonNode oldValues = stored.getAnswers() == null
                ? objectMapper.createObjectNode()
                : stored.getAnswers().deepCopy();

        stored.setAnswers(objectMapper.valueToTree(merged));
        JsonNode newValues = stored.getAnswers();
        responses.save(stored);
        activityLogs.recordClinicalProfileUpdate(actorId, patientUserId, oldValues, newValues);
        return merged;
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
        Set<String> allowedKeys = activeQuestions.stream()
                .map(FormQuestion::getFieldKey)
                .collect(java.util.stream.Collectors.toSet());

        if (!allowedKeys.containsAll(submitted.keySet())) {
            throw bad("The submitted form contains an inactive or unknown question");
        }

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
                if (!(value instanceof String selected) || !allowedValues.contains(selected)) {
                    throw bad(question.getLabel() + " must be one of the listed options");
                }
                continue;
            }

            if (!(value instanceof List<?> selected) || selected.stream().anyMatch(
                    item -> !(item instanceof String chosen) || !allowedValues.contains(chosen)
            )) {
                throw bad(question.getLabel() + " must be one of the listed options");
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
