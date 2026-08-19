package com.example.backend.dtos;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

//Login DTO - record for immutable data
public record LoginRequest(
    @NotBlank @Email @Size(max = 254) String email,
    @NotBlank @Size(max = 72) String password
) {

}
