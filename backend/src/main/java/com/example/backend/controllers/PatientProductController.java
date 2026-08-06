package com.example.backend.controllers;

import com.example.backend.dtos.AddPatientProductRequest;
import com.example.backend.dtos.PatientProductResponse;
import com.example.backend.security.access.ClinicalReader;
import com.example.backend.security.access.ClinicalWriter;
import com.example.backend.services.PatientProductService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients/{id}/products")
@RequiredArgsConstructor
public class PatientProductController {

    private final PatientProductService patientProducts;

    @GetMapping
    @ClinicalReader
    public List<PatientProductResponse> list(@PathVariable UUID id) {
        return patientProducts.list(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @ClinicalWriter
    public PatientProductResponse add(
            @PathVariable UUID id,
            @Valid @RequestBody AddPatientProductRequest request
    ) {
        return patientProducts.add(id, request);
    }

    @PutMapping("/{patientProductId}/discontinue")
    @ClinicalWriter
    public PatientProductResponse discontinue(
            @PathVariable UUID id,
            @PathVariable UUID patientProductId
    ) {
        return patientProducts.discontinue(id, patientProductId);
    }
}
