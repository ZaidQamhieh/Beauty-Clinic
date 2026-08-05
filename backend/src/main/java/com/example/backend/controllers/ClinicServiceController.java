package com.example.backend.controllers;

import com.example.backend.dtos.ServiceForm;
import com.example.backend.dtos.ServiceView;
import com.example.backend.entities.ClinicService;
import com.example.backend.repositories.ClinicServiceRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import com.example.backend.security.access.AdminOnly;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/services")
@RequiredArgsConstructor
public class ClinicServiceController {

    private final ClinicServiceRepository services;

    @GetMapping
    public List<ServiceView> list(
            @RequestParam(name = "includeInactive", defaultValue = "false")
            boolean includeInactive
    ) {
        List<ClinicService> found = includeInactive
                ? services.findAll(ClinicServiceRepository.BY_NAME)
                : services.findByActiveTrue(ClinicServiceRepository.BY_NAME);

        return found.stream().map(ServiceView::of).toList();
    }

    @GetMapping("/{id}")
    public ServiceView read(@PathVariable UUID id) {
        return ServiceView.of(require(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @AdminOnly
    public ServiceView create(@Valid @RequestBody ServiceForm request) {
        ClinicService service = new ClinicService(
                request.name(), request.durationMinutes(), request.price()
        );
        service.setNameAr(request.nameAr());
        return ServiceView.of(services.save(service));
    }

    @PutMapping("/{id}")
    @AdminOnly
    @Transactional
    public ServiceView update(
            @PathVariable UUID id,
            @Valid @RequestBody ServiceForm request
    ) {
        ClinicService service = require(id);
        service.setName(request.name());
        service.setNameAr(request.nameAr());
        service.setDurationMinutes(request.durationMinutes());
        service.setPrice(request.price());
        return ServiceView.of(service);
    }

    @PutMapping("/{id}/active")
    @AdminOnly
    @Transactional
    public ServiceView setActive(
            @PathVariable UUID id,
            @RequestParam boolean value
    ) {
        ClinicService service = require(id);
        service.setActive(value);
        return ServiceView.of(service);
    }

    private ClinicService require(UUID id) {
        return services.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such service")
        );
    }
}
