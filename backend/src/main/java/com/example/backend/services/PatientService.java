package com.example.backend.services;

import com.example.backend.dtos.EditAllergiesRequest;
import com.example.backend.dtos.EditOwnProfileRequest;
import com.example.backend.dtos.EditPatientRequest;
import com.example.backend.dtos.PatientDetailResponse;
import com.example.backend.dtos.PatientRecordResponse;
import com.example.backend.dtos.PatientSummaryResponse;
import com.example.backend.dtos.RegisterPatientRequest;
import com.example.backend.entities.Patient;
import com.example.backend.repositories.PatientRepository;
import com.example.backend.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PatientService {

    private final PatientRepository patients;
    private final CurrentUser currentUser;

    @Transactional
    public PatientDetailResponse register(RegisterPatientRequest request) {
        Patient patient = new Patient(request.firstName(), request.lastName());
        patient.setDateOfBirth(request.dateOfBirth());
        patient.setPhone(request.phone());
        patient.setEmail(request.email());
        patient.setAddress(request.address());

        if (request.languagePref() != null) {
            patient.setLanguagePref(request.languagePref());
        }

        return PatientDetailResponse.of(patients.save(patient));
    }

    @Transactional(readOnly = true)
    public Page<PatientSummaryResponse> search(String term, Pageable pageable) {
        return patients.search(term == null ? "" : term, pageable)
                .map(PatientSummaryResponse::of);
    }

    @Transactional(readOnly = true)
    public PatientDetailResponse read(UUID id) {
        return PatientDetailResponse.of(require(id));
    }

    @Transactional(readOnly = true)
    public PatientRecordResponse readClinical(UUID id) {
        return PatientRecordResponse.of(require(id));
    }

    @Transactional
    public PatientDetailResponse updateDemographics(UUID id, EditPatientRequest request) {
        Patient patient = require(id);
        patient.setFirstName(request.firstName());
        patient.setLastName(request.lastName());
        patient.setDateOfBirth(request.dateOfBirth());
        patient.setPhone(request.phone());
        patient.setEmail(request.email());
        patient.setAddress(request.address());

        if (request.languagePref() != null) {
            patient.setLanguagePref(request.languagePref());
        }

        return PatientDetailResponse.of(patient);
    }

    @Transactional
    // Target comes from the token, so a patient cannot aim this at someone else.
    public PatientDetailResponse updateOwnProfile(EditOwnProfileRequest request) {
        Patient patient = requireOwn();
        patient.setPhone(request.phone());
        patient.setAddress(request.address());

        if (request.languagePref() != null) {
            patient.setLanguagePref(request.languagePref());
        }

        return PatientDetailResponse.of(patient);
    }

    @Transactional(readOnly = true)
    public PatientRecordResponse readOwnRecord() {
        return PatientRecordResponse.of(requireOwn());
    }

    @Transactional
    public PatientRecordResponse updateAllergies(UUID id, EditAllergiesRequest request) {
        Patient patient = require(id);
        patient.setAllergies(request.allergies());
        return PatientRecordResponse.of(patient);
    }

    private Patient require(UUID id) {
        return patients.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));
    }

    private Patient requireOwn() {
        return patients.findByUserId(currentUser.requireId())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "No patient record for this account"
                ));
    }
}
