package com.example.backend.controllers;

import com.example.backend.dtos.FormQuestionRequest;
import com.example.backend.dtos.FormQuestionResponse;
import com.example.backend.dtos.PatientFormResponseDto;
import com.example.backend.security.CurrentUser;
import com.example.backend.security.access.AdminOnly;
import com.example.backend.security.access.PatientOnly;
import com.example.backend.services.DynamicFormService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/forms/clinical-intake")
@RequiredArgsConstructor
public class DynamicFormController {

    private final DynamicFormService forms;
    private final CurrentUser currentUser;

    @GetMapping
    public List<FormQuestionResponse> publishedSchema() {
        return forms.visibleTo(forms.schema(false), currentUser.id().orElse(null));
    }

    @GetMapping("/answers/me")
    @PatientOnly
    public Map<String, Object> ownAnswers() {
        return forms.answers(currentUser.requireId());
    }

    @PutMapping("/answers/me")
    @PatientOnly
    public Map<String, Object> saveOwnAnswers(@Valid @RequestBody PatientFormResponseDto request) {
        UUID actorId = currentUser.requireId();
        return forms.saveAnswers(actorId, actorId, request.answers());
    }

    @GetMapping("/admin/questions")
    @AdminOnly
    public List<FormQuestionResponse> allQuestions() {
        return forms.schema(true);
    }

    @PostMapping("/admin/questions")
    @AdminOnly
    public FormQuestionResponse create(@Valid @RequestBody FormQuestionRequest request) {
        return forms.create(request);
    }

    @PutMapping("/admin/questions/{id}")
    @AdminOnly
    public FormQuestionResponse update(
            @PathVariable UUID id,
            @Valid @RequestBody FormQuestionRequest request
    ) {
        return forms.update(id, request);
    }

    @DeleteMapping("/admin/questions/{id}")
    @AdminOnly
    public void remove(@PathVariable UUID id) {
        forms.deactivate(id);
    }

    @PostMapping("/admin/questions/{id}/activate")
    @AdminOnly
    public void activate(@PathVariable UUID id) {
        forms.activate(id);
    }
}
