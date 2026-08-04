package com.example.backend.catalogue;

import com.example.backend.catalogue.dto.ServiceDtos;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.security.access.prepost.PreAuthorize;
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
    public List<ServiceDtos.View> list(
            @RequestParam(name = "includeInactive", defaultValue = "false")
            boolean includeInactive
    ) {
        List<ClinicService> found = includeInactive
                ? services.findAll(ClinicServiceRepository.BY_NAME)
                : services.findByActiveTrue(ClinicServiceRepository.BY_NAME);

        return found.stream().map(ServiceDtos.View::of).toList();
    }

    @GetMapping("/{id}")
    public ServiceDtos.View read(@PathVariable UUID id) {
        return ServiceDtos.View.of(require(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    public ServiceDtos.View create(@Valid @RequestBody ServiceDtos.Upsert request) {
        ClinicService service = new ClinicService(
                request.name(), request.durationMinutes(), request.price()
        );
        service.setNameAr(request.nameAr());
        return ServiceDtos.View.of(services.save(service));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public ServiceDtos.View update(
            @PathVariable UUID id,
            @Valid @RequestBody ServiceDtos.Upsert request
    ) {
        ClinicService service = require(id);
        service.setName(request.name());
        service.setNameAr(request.nameAr());
        service.setDurationMinutes(request.durationMinutes());
        service.setPrice(request.price());
        return ServiceDtos.View.of(service);
    }

    @PutMapping("/{id}/active")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public ServiceDtos.View setActive(
            @PathVariable UUID id,
            @RequestParam boolean value
    ) {
        ClinicService service = require(id);
        service.setActive(value);
        return ServiceDtos.View.of(service);
    }

    private ClinicService require(UUID id) {
        return services.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such service")
        );
    }
}
