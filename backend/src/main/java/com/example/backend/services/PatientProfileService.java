package com.example.backend.services;

import com.example.backend.dtos.EditClinicalProfileRequest;
import com.example.backend.dtos.EditOwnProfileRequest;
import com.example.backend.dtos.PatientDetailsRequest;
import com.example.backend.dtos.PatientDetailResponse;
import com.example.backend.dtos.PatientRecordResponse;
import com.example.backend.entities.PatientFormResponse;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.PatientFormResponseRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.CurrentUser;
import com.example.backend.security.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import java.util.stream.Collectors;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import com.example.backend.dtos.ClinicalHistoryResponse;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@Service
@RequiredArgsConstructor
public class PatientProfileService {

    private final PatientProfileRepository patients;
    private final UserAccountRepository users;
    private final PasswordEncoder passwordEncoder;
    private final CurrentUser currentUser;
    private final ActivityLogService activityLogs;
    private final PatientFormResponseRepository formResponses;
    // Jackson 2 kept for Hibernate JsonNode.
    private final ObjectMapper objectMapper = new ObjectMapper()
            .registerModule(new JavaTimeModule());

    @CacheEvict(value = "patientData", allEntries = true)
    @Transactional
    public PatientDetailResponse register(PatientDetailsRequest request) {
        if (request.clinical() == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "The patient's health form is required");
        }

        if (users.findByEmailIgnoreCase(request.email()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered");
        }

        // Phone has its own unique index.
        if (request.phone() != null && users.existsByPhone(request.phone())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Phone number already registered");
        }

        UserAccount account = new UserAccount(
                request.email(), null, request.firstName(), request.lastName(), Role.PATIENT
        );
        account.setDateOfBirth(request.dateOfBirth());
        account.setPhone(request.phone());
        account.setGender(request.gender());

        account.activateWith(passwordEncoder.encode(request.password()));

        users.save(account);

        PatientProfile profile = new PatientProfile(account);
        applyClinical(profile, request.clinical());
        patients.save(profile);

        // Not self-registration; the desk did this.
        activityLogs.record(
                currentUser.id().orElse(null), account.getId(),
                ActivityAction.PATIENT_REGISTERED_BY_STAFF,
                "user_account", account.getId());

        return PatientDetailResponse.of(profile);
    }

    // Page doesn't round-trip through the Redis ObjectMapper.
    @Transactional(readOnly = true)
    public Page<PatientDetailResponse> search(String term, Pageable pageable) {
        String needle = term;
        if (needle == null) {
            needle = "";
        }

        return patients.search(needle, pageable)
                .map(PatientDetailResponse::of);
    }

    // Admins see everyone; doctors only their own.
    @Transactional(readOnly = true)
    public Page<PatientRecordResponse> searchClinical(String term, Pageable pageable) {
        String needle = term == null ? "" : term;

        if (currentUser.hasRole(Role.ADMIN)) {
            return patients.search(needle, pageable).map(PatientRecordResponse::of);
        }

        return patients.searchTreatedBy(needle, currentUser.requireId(), pageable)
                .map(PatientRecordResponse::of);
    }

    @Cacheable(value = "patientData", key = "'detail:' + #userId")
    @Transactional(readOnly = true)
    public PatientDetailResponse read(UUID userId) {
        return PatientDetailResponse.of(require(userId));
    }

    @Transactional(readOnly = true)
    public PatientRecordResponse readClinical(UUID userId) {
        PatientRecordResponse record = PatientRecordResponse.of(require(userId));

        activityLogs.recordView(
                currentUser.id().orElse(null), userId,
                ActivityAction.CLINICAL_PROFILE_VIEWED, "patient_profile", userId);

        return record;
    }

    @CacheEvict(value = "patientData", allEntries = true)
    @Transactional
    public PatientDetailResponse updateDemographics(UUID userId, PatientDetailsRequest request) {
        PatientProfile profile = require(userId);
        UserAccount account = profile.getUser();
        Map<String, Object> before = demographics(account);

        account.setFirstName(request.firstName());
        account.setLastName(request.lastName());
        account.setDateOfBirth(request.dateOfBirth());
        account.setPhone(request.phone());
        account.setEmail(request.email());
        account.setGender(request.gender());

        activityLogs.recordChange(
                currentUser.id().orElse(null), userId,
                ActivityAction.PATIENT_DEMOGRAPHICS_UPDATED,
                "user_account", userId, ActivityDiff.between(before, demographics(account)));

        return PatientDetailResponse.of(profile);
    }

    private Map<String, Object> demographics(UserAccount account) {
        Map<String, Object> fields = new LinkedHashMap<>();
        fields.put("email", account.getEmail());
        fields.put("phone", account.getPhone());
        fields.put("firstName", account.getFirstName());
        fields.put("lastName", account.getLastName());
        fields.put("dateOfBirth", account.getDateOfBirth());
        fields.put("gender", account.getGender());
        return fields;
    }

    @CacheEvict(value = "patientData", allEntries = true)
    @Transactional
    // Target from token, never from body.
    public PatientDetailResponse updateOwnProfile(EditOwnProfileRequest request) {
        PatientProfile profile = requireOwn();
        UserAccount account = profile.getUser();

        // Vague, or the index answers queries.
        if (request.phone() != null
                && !request.phone().equals(account.getPhone())
                && users.existsByPhone(request.phone())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Could not save those details");
        }

        account.setPhone(request.phone());
        return PatientDetailResponse.of(profile);
    }

    @Cacheable(value = "patientData", key = "'own:' + @currentUser.requireId()")
    @Transactional(readOnly = true)
    public PatientRecordResponse readOwnRecord() {
        return PatientRecordResponse.of(requireOwn());
    }

    // Self-invocation skips the proxy; evict here too.
    @CacheEvict(value = "patientData", allEntries = true)
    @Transactional
    public PatientRecordResponse updateOwnClinicalProfile(EditClinicalProfileRequest request) {
        return updateClinicalProfile(currentUser.requireId(), request);
    }

    @CacheEvict(value = "patientData", allEntries = true)
    @Transactional
    public PatientRecordResponse updateClinicalProfile(UUID userId, EditClinicalProfileRequest request) {
        PatientProfile profile = require(userId);

        Map<String, Object> before = ClinicalAnswers.of(profile);
        applyClinical(profile, request);
        Map<String, Object> after = ClinicalAnswers.of(profile);

        // Form copy must not go stale.
        syncFormAnswers(userId, after);

        // Nothing changed, so nothing happened.
        if (!before.equals(after)) {
            activityLogs.recordClinicalProfileUpdate(
                    currentUser.requireId(), userId,
                    objectMapper.valueToTree(before),
                    objectMapper.valueToTree(after));
        }

        return PatientRecordResponse.of(profile);
    }

    // Staff edits reach the form too.
    @SuppressWarnings("unchecked")
    private void syncFormAnswers(UUID patientUserId, Map<String, Object> answers) {
        PatientFormResponse.Id key =
                new PatientFormResponse.Id(patientUserId, DynamicFormService.CLINICAL_INTAKE);

        PatientFormResponse stored = formResponses.findById(key).orElseGet(() -> {
            PatientFormResponse created = new PatientFormResponse();
            created.setId(key);
            created.setAnswers(objectMapper.createObjectNode());
            return created;
        });

        Map<String, Object> merged = new LinkedHashMap<>();

        if (stored.getAnswers() != null) {
            merged.putAll(objectMapper.convertValue(stored.getAnswers(), Map.class));
        }

        merged.putAll(answers);

        stored.setAnswers(objectMapper.valueToTree(merged));
        formResponses.save(stored);
    }

    @Transactional(readOnly = true)
    public Page<ClinicalHistoryResponse> clinicalHistory(UUID userId, Pageable pageable) {
        require(userId);

        activityLogs.recordView(
                currentUser.id().orElse(null), userId,
                ActivityAction.CLINICAL_HISTORY_VIEWED, "patient_profile", userId);

        var page = activityLogs.clinicalHistory(userId, pageable);

        List<ActivityLog> logs = page.getContent();
        var actorIds = logs.stream()
                .map(ActivityLog::getUserId)
                .filter(Objects::nonNull)
                .distinct()
                .toList();

        var actorsById = users.findAllById(actorIds).stream()
                .collect(Collectors.toMap(UserAccount::getId, UserAccount::fullName));

        var dto = logs.stream()
                .map(log -> ClinicalHistoryResponse.of(
                        log,
                        actorsById.getOrDefault(log.getUserId(), "Unknown")
                ))
                .toList();

        return new org.springframework.data.domain.PageImpl<>(dto, pageable, page.getTotalElements());
    }

    // Shared with register, one write path.
    private static void applyClinical(PatientProfile profile, EditClinicalProfileRequest request) {
        profile.setPregnantBreastfeeding(request.pregnantBreastfeeding());
        profile.setSkinType(request.skinType());
        profile.setSmokingStatus(request.smokingStatus());
        profile.setAllergies(distinct(request.allergies()));
        profile.setMedications(distinct(request.medications()));
        profile.setChronicConditions(distinct(request.chronicConditions()));
    }

    // CHECK tests containment, so dedupe here.
    private static <T> List<T> distinct(List<T> values) {
        if (values == null) {
            return new ArrayList<>();
        }

        return values.stream()
                .distinct()
                .collect(Collectors.toCollection(ArrayList::new));
    }

    private PatientProfile require(UUID userId) {
        return patients.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));
    }

    private PatientProfile requireOwn() {
        return require(currentUser.requireId());
    }
}
