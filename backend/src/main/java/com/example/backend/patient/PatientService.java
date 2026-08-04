package com.example.backend.patient;

import com.example.backend.patient.dto.EditAllergies;
import com.example.backend.patient.dto.EditOwnProfile;
import com.example.backend.patient.dto.EditPatient;
import com.example.backend.patient.dto.PatientDetail;
import com.example.backend.patient.dto.PatientRecord;
import com.example.backend.patient.dto.PatientSummary;
import com.example.backend.patient.dto.RegisterPatient;
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
    public PatientDetail register(RegisterPatient request) {
        Patient patient = new Patient(request.firstName(), request.lastName());
        patient.setDateOfBirth(request.dateOfBirth());
        patient.setPhone(request.phone());
        patient.setEmail(request.email());
        patient.setAddress(request.address());

        if (request.languagePref() != null) {
            patient.setLanguagePref(request.languagePref());
        }

        return PatientDetail.of(patients.save(patient));
    }

    @Transactional(readOnly = true)
    public List<PatientSummary> search(String term, Pageable pageable) {
        return patients.search(term == null ? "" : term, pageable)
                .map(PatientSummary::of)
                .getContent();
    }

    @Transactional(readOnly = true)
    public PatientDetail read(UUID id) {
        return PatientDetail.of(require(id));
    }

    @Transactional(readOnly = true)
    public PatientRecord readClinical(UUID id) {
        return PatientRecord.of(require(id));
    }

    @Transactional
    public PatientDetail updateDemographics(UUID id, EditPatient request) {
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

        return PatientDetail.of(patient);
    }

    @Transactional
    public PatientDetail updateOwnProfile(EditOwnProfile request) {
        Patient patient = requireOwn();
        patient.setPhone(request.phone());
        patient.setAddress(request.address());

        if (request.languagePref() != null) {
            patient.setLanguagePref(request.languagePref());
        }

        return PatientDetail.of(patient);
    }

    @Transactional(readOnly = true)
    public PatientRecord readOwnRecord() {
        return PatientRecord.of(requireOwn());
    }

    @Transactional
    public PatientRecord updateAllergies(UUID id, EditAllergies request) {
        Patient patient = require(id);
        patient.setAllergies(request.allergies());
        return PatientRecord.of(patient);
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
