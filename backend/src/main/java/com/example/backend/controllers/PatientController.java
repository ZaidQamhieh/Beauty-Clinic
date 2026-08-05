package com.example.backend.controllers;

import com.example.backend.dtos.EditAllergiesRequest;
import com.example.backend.dtos.EditOwnProfileRequest;
import com.example.backend.dtos.EditPatientRequest;
import com.example.backend.dtos.PatientDetailResponse;
import com.example.backend.dtos.PatientRecordResponse;
import com.example.backend.dtos.PatientSummaryResponse;
import com.example.backend.dtos.RegisterPatientRequest;
import com.example.backend.services.PatientService;
import com.example.backend.security.access.ClinicStaffOnly;
import com.example.backend.security.access.ClinicalReader;
import com.example.backend.security.access.ClinicalWriter;
import com.example.backend.security.access.StaffOrOwnPatient;
import com.example.backend.security.access.PatientOnly;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/patients")
@RequiredArgsConstructor
public class PatientController {

    private final PatientService patients;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @ClinicStaffOnly
    public PatientDetailResponse register(@Valid @RequestBody RegisterPatientRequest request) {
        return patients.register(request);
    }

    @GetMapping
    @ClinicStaffOnly
    public Page<PatientSummaryResponse> search(
            @RequestParam(name = "q", required = false) String term,
            Pageable pageable
    ) {
        return patients.search(term, pageable);
    }

    @GetMapping("/{id}")
    @StaffOrOwnPatient
    public PatientDetailResponse read(@PathVariable UUID id) {
        return patients.read(id);
    }

    @PutMapping("/{id}")
    @ClinicStaffOnly
    public PatientDetailResponse updateDemographics(
            @PathVariable UUID id,
            @Valid @RequestBody EditPatientRequest request
    ) {
        return patients.updateDemographics(id, request);
    }

    @GetMapping("/me")
    @PatientOnly
    public PatientRecordResponse readOwnRecord() {
        return patients.readOwnRecord();
    }

    @PutMapping("/me")
    @PatientOnly
    public PatientDetailResponse updateOwnProfile(
            @Valid @RequestBody EditOwnProfileRequest request
    ) {
        return patients.updateOwnProfile(request);
    }

    @GetMapping("/{id}/clinical")
    @ClinicalReader
    public PatientRecordResponse readClinical(@PathVariable UUID id) {
        return patients.readClinical(id);
    }

    @PutMapping("/{id}/allergies")
    @ClinicalWriter
    public PatientRecordResponse updateAllergies(
            @PathVariable UUID id,
            @Valid @RequestBody EditAllergiesRequest request
    ) {
        return patients.updateAllergies(id, request);
    }
}
