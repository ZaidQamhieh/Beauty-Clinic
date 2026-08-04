package com.example.backend.patient;

import com.example.backend.patient.dto.PatientRequests;
import com.example.backend.patient.dto.PatientViews;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients")
@RequiredArgsConstructor
public class PatientController {

    private static final String CLINIC_STAFF =
            "hasAnyRole('DOCTOR', 'RECEPTIONIST', 'ADMIN')";

    private final PatientService patients;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize(CLINIC_STAFF)
    public PatientViews.Detail register(@Valid @RequestBody PatientRequests.Register request) {
        return patients.register(request);
    }

    @GetMapping
    @PreAuthorize(CLINIC_STAFF)
    public List<PatientViews.Summary> search(
            @RequestParam(name = "q", required = false) String term,
            Pageable pageable
    ) {
        return patients.search(term, pageable);
    }

    @GetMapping("/{id}")
    @PreAuthorize(CLINIC_STAFF + " or @access.ownsPatient(#id)")
    public PatientViews.Detail read(@PathVariable UUID id) {
        return patients.read(id);
    }

    @PutMapping("/{id}")
    @PreAuthorize(CLINIC_STAFF)
    public PatientViews.Detail updateDemographics(
            @PathVariable UUID id,
            @Valid @RequestBody PatientRequests.Demographics request
    ) {
        return patients.updateDemographics(id, request);
    }

    @GetMapping("/me")
    @PreAuthorize("hasRole('PATIENT')")
    public PatientViews.Clinical readOwnRecord() {
        return patients.readOwnRecord();
    }

    @PutMapping("/me")
    @PreAuthorize("hasRole('PATIENT')")
    public PatientViews.Detail updateOwnProfile(
            @Valid @RequestBody PatientRequests.SelfUpdate request
    ) {
        return patients.updateOwnProfile(request);
    }

    @GetMapping("/{id}/clinical")
    @PreAuthorize("hasRole('ADMIN') "
            + "or (hasRole('DOCTOR') and @access.treats(#id)) "
            + "or @access.ownsPatient(#id)")
    public PatientViews.Clinical readClinical(@PathVariable UUID id) {
        return patients.readClinical(id);
    }

    @PutMapping("/{id}/allergies")
    @PreAuthorize("hasRole('ADMIN') "
            + "or (hasRole('DOCTOR') and @access.treats(#id))")
    public PatientViews.Clinical updateAllergies(
            @PathVariable UUID id,
            @Valid @RequestBody PatientRequests.Allergies request
    ) {
        return patients.updateAllergies(id, request);
    }
}
