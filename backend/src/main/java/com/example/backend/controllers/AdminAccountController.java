package com.example.backend.controllers;

import com.example.backend.dtos.AccountResponse;
import com.example.backend.dtos.CreateAccountRequest;
import com.example.backend.security.access.AdminOnly;
import com.example.backend.services.AccountService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.security.Role;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/accounts")
@RequiredArgsConstructor
public class AdminAccountController {

    private final AccountService accounts;

    @GetMapping
    @AdminOnly
    public List<AccountResponse> list(
            @RequestParam(required = false) Role role
    ) {
        return accounts.list(role);
    }

    @GetMapping("/{id}")
    @AdminOnly
    public AccountResponse get(@PathVariable UUID id) {
        return accounts.get(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @AdminOnly
    public AccountResponse create(@Valid @RequestBody CreateAccountRequest request) {
        return accounts.create(request);
    }

    @PutMapping("/{id}")
    @AdminOnly
    public AccountResponse update(
            @PathVariable UUID id,
            @Valid @RequestBody CreateAccountRequest request
    ) {
        return accounts.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @AdminOnly
    public void delete(@PathVariable UUID id) {
        accounts.delete(id);
    }
}
