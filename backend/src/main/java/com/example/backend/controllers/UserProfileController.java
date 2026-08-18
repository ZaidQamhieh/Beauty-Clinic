package com.example.backend.controllers;

import com.example.backend.dtos.ChangeOwnPasswordRequest;
import com.example.backend.dtos.UpdateOwnUserProfileRequest;
import com.example.backend.dtos.UserProfileResponse;
import com.example.backend.security.access.Authenticated;
import com.example.backend.services.UserProfileService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserProfileController {

    private final UserProfileService users;

    @GetMapping("/me")
    @Authenticated
    public UserProfileResponse readOwn() {
        return users.readOwn();
    }

    @PutMapping("/me")
    @Authenticated
    public UserProfileResponse updateOwn(
            @Valid @RequestBody UpdateOwnUserProfileRequest request
    ) {
        return users.updateOwn(request);
    }

    @PutMapping("/me/password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Authenticated
    public void changeOwnPassword(
            @Valid @RequestBody ChangeOwnPasswordRequest request
    ) {
        users.changeOwnPassword(request);
    }
}
