package com.example.backend.services;

import com.example.backend.dtos.ChangeOwnPasswordRequest;
import com.example.backend.dtos.DoctorProfileResponse;
import com.example.backend.dtos.UpdateOwnUserProfileRequest;
import com.example.backend.dtos.UserProfileResponse;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.CurrentUser;
import com.example.backend.entities.ActivityAction;
import com.example.backend.security.Role;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class UserProfileService {

    private final UserAccountRepository users;
    private final DoctorProfileRepository doctors;
    private final PasswordEncoder passwordEncoder;
    private final CurrentUser currentUser;
    private final ActivityLogService activityLogs;
    // Jackson 2 kept for Hibernate JsonNode.
    private final ObjectMapper objectMapper = new ObjectMapper()
            .registerModule(new JavaTimeModule());

    @Cacheable(value = "patientData", key = "'myProfile:' + @currentUser.requireId()")
    @Transactional(readOnly = true)
    public UserProfileResponse readOwn() {
        UserAccount account = requireOwnAccount();
        return UserProfileResponse.of(account, doctorProfileOf(account));
    }

    @CacheEvict(value = "patientData", allEntries = true)
    @Transactional
    public UserProfileResponse updateOwn(UpdateOwnUserProfileRequest request) {
        UserAccount account = requireOwnAccount();

        if (request.phone() != null
                && !request.phone().equals(account.getPhone())
                && users.existsByPhone(request.phone())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Phone number already registered");
        }

        JsonNode before = snapshot(account);

        account.setFirstName(request.firstName());
        account.setLastName(request.lastName());
        account.setPhone(request.phone());
        if (account.getRole() == Role.PATIENT || account.getRole() == Role.DOCTOR) {
            account.setImageUrl(request.imageUrl() == null || request.imageUrl().isBlank()
                    ? null : request.imageUrl().trim());
        }
        account.setDateOfBirth(request.dateOfBirth());
        account.setGender(request.gender());
        account.setUpdatedAt(Instant.now());

        DoctorProfileResponse doctorProfile = updateDoctorProfile(account, request);
        users.save(account);

        activityLogs.record(
                account.getId(), null, ActivityAction.PROFILE_UPDATED,
                "user_account", account.getId(), before, snapshot(account));

        return UserProfileResponse.of(account, doctorProfile);
    }

    @CacheEvict(value = "patientData", allEntries = true)
    @Transactional
    public void changeOwnPassword(ChangeOwnPasswordRequest request) {
        UserAccount account = requireOwnAccount();

        if (account.getPasswordHash() == null
                || !passwordEncoder.matches(request.currentPassword(), account.getPasswordHash())) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Current password is incorrect");
        }

        account.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        account.setUpdatedAt(Instant.now());
        users.save(account);

        activityLogs.record(
                account.getId(), null, ActivityAction.PASSWORD_CHANGED,
                "user_account", account.getId());
    }

    // Never the password hash.
    private JsonNode snapshot(UserAccount account) {
        Map<String, Object> fields = new LinkedHashMap<>();
        fields.put("email", account.getEmail());
        fields.put("phone", account.getPhone());
        fields.put("firstName", account.getFirstName());
        fields.put("lastName", account.getLastName());
        fields.put("dateOfBirth", account.getDateOfBirth());
        fields.put("imageUrl", account.getImageUrl());
        fields.put("gender", account.getGender());
        return objectMapper.valueToTree(fields);
    }

    private DoctorProfileResponse updateDoctorProfile(
            UserAccount account,
            UpdateOwnUserProfileRequest request) {
        boolean doctorFieldsRequested = request.specializations() != null || request.yearsOfExperience() != null;

        if (account.getRole() != Role.DOCTOR) {
            if (doctorFieldsRequested) {
                throw new ResponseStatusException(
                        HttpStatus.FORBIDDEN, "Only doctors may update doctor profile fields");
            }
            return null;
        }

        if (request.specializations() == null || request.specializations().isEmpty()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "At least one specialization is required");
        }
        if (request.yearsOfExperience() == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Years of experience is required");
        }

        DoctorProfile profile = doctors.findById(account.getId())
                .orElseGet(() -> new DoctorProfile(account));

        if (request.specializations() != null) {
            profile.setSpecializations(distinct(request.specializations()));
        }

        if (request.yearsOfExperience() != null) {
            profile.setYearsOfExperience(request.yearsOfExperience());
        }

        return DoctorProfileResponse.of(doctors.save(profile));
    }

    private DoctorProfileResponse doctorProfileOf(UserAccount account) {
        if (account.getRole() != Role.DOCTOR) {
            return null;
        }

        DoctorProfile profile = doctors.findById(account.getId())
                .orElseGet(() -> new DoctorProfile(account));
        return DoctorProfileResponse.of(profile);
    }

    private UserAccount requireOwnAccount() {
        return users.findById(currentUser.requireId())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Authenticated user not found"));
    }

    private static <T> List<T> distinct(List<T> values) {
        return values.stream()
                .distinct()
                .collect(java.util.stream.Collectors.toCollection(ArrayList::new));
    }
}
