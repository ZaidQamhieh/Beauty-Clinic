package com.example.backend.controllers;

import com.example.backend.dtos.EditClinicalProfileRequest;
import com.example.backend.dtos.EditOwnProfileRequest;
import com.example.backend.dtos.PatientDetailsRequest;
import com.example.backend.dtos.PatientDetailResponse;
import com.example.backend.dtos.PatientRecordResponse;
import com.example.backend.services.PatientProfileService;
import com.example.backend.security.access.ClinicStaffOnly;
import org.springframework.security.access.prepost.PreAuthorize;
import com.example.backend.security.access.ClinicalReader;
import com.example.backend.security.access.ClinicalWriter;
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

    private final PatientProfileService patients;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @ClinicStaffOnly
    public PatientDetailResponse register(@Valid @RequestBody PatientDetailsRequest request) {
        return patients.register(request);
    }

    @GetMapping
    @ClinicStaffOnly
    public Page<PatientDetailResponse> search(
            @RequestParam(name = "q", required = false) String term,
            Pageable pageable
    ) {
        return patients.search(term, pageable);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('DOCTOR', 'RECEPTIONIST', 'ADMIN') or @access.isSelf(#id)")
    public PatientDetailResponse read(@PathVariable UUID id) {
        return patients.read(id);
    }

    @PutMapping("/{id}")
    @ClinicStaffOnly
    public PatientDetailResponse updateDemographics(
            @PathVariable UUID id,
            @Valid @RequestBody PatientDetailsRequest request
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

    // The health form is the patient's own to fill; without this only an admin could.
    @PutMapping("/me/clinical")
    @PatientOnly
    public PatientRecordResponse updateOwnClinicalProfile(
            @Valid @RequestBody EditClinicalProfileRequest request
    ) {
        return patients.updateOwnClinicalProfile(request);
    }

    @GetMapping("/{id}/clinical")
    @ClinicalReader
    public PatientRecordResponse readClinical(@PathVariable UUID id) {
        return patients.readClinical(id);
    }

    @PutMapping("/{id}/clinical")
    @ClinicalWriter
    public PatientRecordResponse updateClinicalProfile(
            @PathVariable UUID id,
            @Valid @RequestBody EditClinicalProfileRequest request
    ) {
        return patients.updateClinicalProfile(id, request);
    }
}
