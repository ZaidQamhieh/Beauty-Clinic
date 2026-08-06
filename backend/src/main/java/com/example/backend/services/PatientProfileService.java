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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PatientProfileService {

    private final PatientProfileRepository patients;
    private final UserAccountRepository users;
    private final CurrentUser currentUser;

    @Transactional
    public PatientDetailResponse register(PatientDetailsRequest request) {
        if (users.findByEmailIgnoreCase(request.email()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered");
        }

        // No password: the account is INVITED until the patient claims it.
        UserAccount account = new UserAccount(
                request.email(), null, request.firstName(), request.lastName(), Role.PATIENT
        );
        account.setDateOfBirth(request.dateOfBirth());
        account.setPhone(request.phone());
        account.setGender(request.gender());
        account.setStatus(AccountStatus.INVITED);
        users.save(account);

        PatientProfile profile = patients.save(new PatientProfile(account));

        return PatientDetailResponse.of(profile);
    }

    @Transactional(readOnly = true)
    public Page<PatientDetailResponse> search(String term, Pageable pageable) {
        return patients.search(term == null ? "" : term, pageable)
                .map(PatientDetailResponse::of);
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
        profile.getUser().setPhone(request.phone());
        return PatientDetailResponse.of(profile);
    }

    @Transactional(readOnly = true)
    public PatientRecordResponse readOwnRecord() {
        return PatientRecordResponse.of(requireOwn());
    }

    @Transactional
    public PatientRecordResponse updateClinicalProfile(UUID userId, EditClinicalProfileRequest request) {
        PatientProfile profile = require(userId);
        profile.setPregnantBreastfeeding(request.pregnantBreastfeeding());
        profile.setSkinType(request.skinType());
        profile.setSmokingStatus(request.smokingStatus());
        profile.setAllergies(request.allergies());
        profile.setMedications(request.medications());
        profile.setChronicConditions(request.chronicConditions());
        return PatientRecordResponse.of(profile);
    }

    private PatientProfile require(UUID userId) {
        return patients.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));
    }

    private PatientProfile requireOwn() {
        return require(currentUser.requireId());
    }
}
