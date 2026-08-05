package com.example.backend.controllers;

import com.example.backend.dtos.AmendTreatmentRecordRequest;
import com.example.backend.dtos.CreateTreatmentRecordRequest;
import com.example.backend.dtos.TreatmentRecordResponse;
import com.example.backend.security.access.ClinicalReader;
import com.example.backend.security.access.ClinicalWriter;
import com.example.backend.services.TreatmentRecordService;
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
@RequestMapping("/api/patients/{id}/treatment-records")
@RequiredArgsConstructor
public class TreatmentRecordController {

    private final TreatmentRecordService records;

    @GetMapping
    @ClinicalReader
    public List<TreatmentRecordResponse> list(@PathVariable UUID id) {
        return records.list(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @ClinicalWriter
    public TreatmentRecordResponse create(
            @PathVariable UUID id,
            @Valid @RequestBody CreateTreatmentRecordRequest request
    ) {
        return records.create(id, request);
    }

    @PutMapping("/{recordId}/amend")
    @ClinicalWriter
    public TreatmentRecordResponse amend(
            @PathVariable UUID id,
            @PathVariable UUID recordId,
            @Valid @RequestBody AmendTreatmentRecordRequest request
    ) {
        return records.amend(id, recordId, request);
    }
}
