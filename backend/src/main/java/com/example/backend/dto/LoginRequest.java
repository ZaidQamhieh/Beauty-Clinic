package com.example.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

//Login DTO - record for immutable data
public record LoginRequest(
    @NotBlank @Email String email,
    @NotBlank String password
) {
    
}
