package com.example.backend.controllers;

import com.example.backend.dtos.AmendSessionRecordRequest;
import com.example.backend.dtos.CreateSessionRecordRequest;
import com.example.backend.dtos.SessionRecordResponse;
import com.example.backend.security.access.ClinicalReader;
import com.example.backend.security.access.ClinicalWriter;
import com.example.backend.services.SessionRecordService;
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
@RequestMapping("/api/patients/{id}/session-records")
@RequiredArgsConstructor
public class SessionRecordController {

    private final SessionRecordService records;

    @GetMapping
    @ClinicalReader
    public List<SessionRecordResponse> list(@PathVariable UUID id) {
        return records.list(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @ClinicalWriter
    public SessionRecordResponse create(
            @PathVariable UUID id,
            @Valid @RequestBody CreateSessionRecordRequest request
    ) {
        return records.create(id, request);
    }

    @PutMapping("/{recordId}/amend")
    @ClinicalWriter
    public SessionRecordResponse amend(
            @PathVariable UUID id,
            @PathVariable UUID recordId,
            @Valid @RequestBody AmendSessionRecordRequest request
    ) {
        return records.amend(id, recordId, request);
    }
}
