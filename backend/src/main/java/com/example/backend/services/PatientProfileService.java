package com.example.backend.services;

import com.example.backend.dtos.EditClinicalProfileRequest;
import com.example.backend.dtos.EditOwnProfileRequest;
import com.example.backend.dtos.PatientDetailsRequest;
import com.example.backend.dtos.PatientDetailResponse;
import com.example.backend.dtos.PatientRecordResponse;
import com.example.backend.entities.UserAccount.AccountStatus;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.CurrentUser;
import com.example.backend.security.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import java.util.stream.Collectors;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import com.example.backend.dtos.ClinicalHistoryResponse;
import com.example.backend.repositories.ActivityLogRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
@RequiredArgsConstructor
public class PatientProfileService {

    private final PatientProfileRepository patients;
    private final UserAccountRepository users;
    private final PasswordEncoder passwordEncoder;
    private final CurrentUser currentUser;
    private final ActivityLogRepository activityLogs;
    // Spring Boot 4's web stack uses Jackson 3, while the JSONB mapping below
    // deliberately uses Jackson 2 for Hibernate's stable JsonNode support.
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Transactional
    public PatientDetailResponse register(PatientDetailsRequest request) {
        // Taken at the desk, like the paper form. Without it, not bookable.
        if (request.clinical() == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "The patient's health form is required");
        }

        if (users.findByEmailIgnoreCase(request.email()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered");
        }

        // Phone carries its own unique index, so it needs its own answer, not a bare conflict.
        if (request.phone() != null && users.existsByPhone(request.phone())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Phone number already registered");
        }

        UserAccount account = new UserAccount(
                request.email(), null, request.firstName(), request.lastName(), Role.PATIENT
        );
        account.setDateOfBirth(request.dateOfBirth());
        account.setPhone(request.phone());
        account.setGender(request.gender());

        // A password means a live account; without one it is a walk-in record.
        if (request.password() == null) {
            account.setStatus(AccountStatus.INVITED);
        } else {
            account.activateWith(passwordEncoder.encode(request.password()));
        }

        users.save(account);

        PatientProfile profile = new PatientProfile(account);
        applyClinical(profile, request.clinical());
        patients.save(profile);

        return PatientDetailResponse.of(profile);
    }

    @Transactional(readOnly = true)
    public Page<PatientDetailResponse> search(String term, Pageable pageable) {
        String needle = term;
        if (needle == null) {
            needle = "";
        }

        return patients.search(needle, pageable)
                .map(PatientDetailResponse::of);
    }

    @Transactional(readOnly = true)
    public Page<PatientRecordResponse> searchClinical(String term, Pageable pageable) {
        String needle = term == null ? "" : term;
        return patients.search(needle, pageable).map(PatientRecordResponse::of);
    }

    @Transactional(readOnly = true)
    public PatientDetailResponse read(UUID userId) {
        return PatientDetailResponse.of(require(userId));
    }

    @Transactional(readOnly = true)
    public PatientRecordResponse readClinical(UUID userId) {
        return PatientRecordResponse.of(require(userId));
    }

    @Transactional
    public PatientDetailResponse updateDemographics(UUID userId, PatientDetailsRequest request) {
        PatientProfile profile = require(userId);
        UserAccount account = profile.getUser();
        account.setFirstName(request.firstName());
        account.setLastName(request.lastName());
        account.setDateOfBirth(request.dateOfBirth());
        account.setPhone(request.phone());
        account.setEmail(request.email());
        account.setGender(request.gender());
        return PatientDetailResponse.of(profile);
    }

    @Transactional
    // Target from token, so patient cannot aim at someone else.
    public PatientDetailResponse updateOwnProfile(EditOwnProfileRequest request) {
        PatientProfile profile = requireOwn();
        UserAccount account = profile.getUser();

        // Vague on purpose: the unique index would otherwise answer "is this number registered".
        if (request.phone() != null
                && !request.phone().equals(account.getPhone())
                && users.existsByPhone(request.phone())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Could not save those details");
        }

        account.setPhone(request.phone());
        return PatientDetailResponse.of(profile);
    }

    @Transactional(readOnly = true)
    public PatientRecordResponse readOwnRecord() {
        return PatientRecordResponse.of(requireOwn());
    }

    // The patient filling their own form; no other route lets them write a clinical field.
    @Transactional
    public PatientRecordResponse updateOwnClinicalProfile(EditClinicalProfileRequest request) {
        return updateClinicalProfile(currentUser.requireId(), request);
    }

    @Transactional
    public PatientRecordResponse updateClinicalProfile(UUID userId, EditClinicalProfileRequest request) {
        PatientProfile profile = require(userId);
        JsonNode before = objectMapper.valueToTree(PatientRecordResponse.of(profile));
        applyClinical(profile, request);
        JsonNode after = objectMapper.valueToTree(PatientRecordResponse.of(profile));
        activityLogs.save(ActivityLog.clinicalProfileUpdated(currentUser.requireId(), userId, before, after));
        return PatientRecordResponse.of(profile);
    }

    @Transactional(readOnly = true)
    public Page<ClinicalHistoryResponse> clinicalHistory(UUID userId, Pageable pageable) {
        require(userId);
        var page = activityLogs.findByPatientUserIdAndActionOrderByCreatedAtDesc(
                userId, ActivityAction.CLINICAL_PROFILE_UPDATED, pageable
        );

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

    // Shared with register: one way to write the form.
    private static void applyClinical(PatientProfile profile, EditClinicalProfileRequest request) {
        profile.setPregnantBreastfeeding(request.pregnantBreastfeeding());
        profile.setSkinType(request.skinType());
        profile.setSmokingStatus(request.smokingStatus());
        profile.setAllergies(distinct(request.allergies()));
        profile.setMedications(distinct(request.medications()));
        profile.setChronicConditions(distinct(request.chronicConditions()));
    }

    // The column CHECK only tests containment, so ['NUTS','NUTS'] passes. Copies, and never null.
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
