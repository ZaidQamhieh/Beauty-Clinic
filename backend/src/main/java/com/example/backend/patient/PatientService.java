package com.example.backend.patient;

import com.example.backend.patient.dto.PatientRequests;
import com.example.backend.patient.dto.PatientViews;
import com.example.backend.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PatientService {

    private final PatientRepository patients;
    private final CurrentUser currentUser;

    @Transactional
    public PatientViews.Detail register(PatientRequests.Register request) {
        Patient patient = new Patient(request.firstName(), request.lastName());
        patient.setDateOfBirth(request.dateOfBirth());
        patient.setPhone(request.phone());
        patient.setEmail(request.email());
        patient.setAddress(request.address());

        if (request.languagePref() != null) {
            patient.setLanguagePref(request.languagePref());
        }

        return PatientViews.Detail.of(patients.save(patient));
    }

    @Transactional(readOnly = true)
    public List<PatientViews.Summary> search(String term, Pageable pageable) {
        return patients.search(term == null ? "" : term, pageable)
                .map(PatientViews.Summary::of)
                .getContent();
    }

    @Transactional(readOnly = true)
    public PatientViews.Detail read(UUID id) {
        return PatientViews.Detail.of(require(id));
    }

    @Transactional(readOnly = true)
    public PatientViews.Clinical readClinical(UUID id) {
        return PatientViews.Clinical.of(require(id));
    }

    @Transactional
    public PatientViews.Detail updateDemographics(UUID id, PatientRequests.Demographics request) {
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

        return PatientViews.Detail.of(patient);
    }

    @Transactional
    public PatientViews.Detail updateOwnProfile(PatientRequests.SelfUpdate request) {
        Patient patient = requireOwn();
        patient.setPhone(request.phone());
        patient.setAddress(request.address());

        if (request.languagePref() != null) {
            patient.setLanguagePref(request.languagePref());
        }

        return PatientViews.Detail.of(patient);
    }

    @Transactional(readOnly = true)
    public PatientViews.Clinical readOwnRecord() {
        return PatientViews.Clinical.of(requireOwn());
    }

    @Transactional
    public PatientViews.Clinical updateAllergies(UUID id, PatientRequests.Allergies request) {
        Patient patient = require(id);
        patient.setAllergies(request.allergies());
        return PatientViews.Clinical.of(patient);
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
