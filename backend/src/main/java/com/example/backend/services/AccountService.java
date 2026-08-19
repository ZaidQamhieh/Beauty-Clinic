package com.example.backend.services;

import com.example.backend.dtos.AccountResponse;
import com.example.backend.dtos.CreateAccountRequest;
import com.example.backend.dtos.DoctorProfileResponse;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.entities.UserAccount.AccountStatus;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.entities.ActivityAction;
import com.example.backend.security.CurrentUser;
import com.example.backend.security.Role;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.RequiredArgsConstructor;
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
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AccountService {

    private static final Set<Role> STAFF_ROLES = Set.of(Role.DOCTOR, Role.RECEPTIONIST);

    private final UserAccountRepository users;
    private final DoctorProfileRepository doctors;
    private final PasswordEncoder passwordEncoder;
    private final ActivityLogService activityLogs;
    private final CurrentUser currentUser;
    // Jackson 2 kept for Hibernate JsonNode.
    private final ObjectMapper objectMapper = new ObjectMapper()
            .registerModule(new JavaTimeModule());

    @Transactional
    public AccountResponse create(CreateAccountRequest request) {
        validateCreatePassword(request.password());

        if (users.findByEmailIgnoreCase(request.email()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered");
        }

        UserAccount account = new UserAccount(
                request.email(),
                passwordEncoder.encode(request.password()),
                request.firstName(),
                request.lastName(),
                request.role());
        account.setPhone(request.phone());
        account.setDateOfBirth(request.dateOfBirth());
        account.setGender(request.gender());
        account.setStatus(request.status() == null ? AccountStatus.ACTIVE : request.status());
        account = users.save(account);

        DoctorProfileResponse doctorProfile = createDoctorProfile(account, request);

        activityLogs.record(
                actor(), null, ActivityAction.ACCOUNT_CREATED,
                "user_account", account.getId(), null, snapshot(account));

        return AccountResponse.of(account, doctorProfile);
    }

    @Transactional
    public AccountResponse update(UUID id, CreateAccountRequest request) {
        UserAccount account = users.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Account not found"));

        users.findByEmailIgnoreCase(request.email())
                .filter(existing -> !existing.getId().equals(id))
                .ifPresent(existing -> {
                    throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered");
                });

        if (account.getRole() != request.role()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Account role cannot be changed");
        }

        JsonNode before = snapshot(account);
        AccountStatus previousStatus = account.getStatus();

        account.setEmail(request.email());
        account.setPhone(request.phone());
        account.setFirstName(request.firstName());
        account.setLastName(request.lastName());
        account.setDateOfBirth(request.dateOfBirth());
        account.setGender(request.gender());
        account.setStatus(request.status() == null ? account.getStatus() : request.status());
        if (hasText(request.password())) {
            if (request.password().length() < 8) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Password must be at least 8 characters");
            }
            account.setPasswordHash(passwordEncoder.encode(request.password()));
        }
        account.setUpdatedAt(Instant.now());
        account = users.save(account);

        DoctorProfileResponse doctorProfile = updateDoctorProfile(account, request);

        UUID actor = actor();
        activityLogs.record(
                actor, null, ActivityAction.ACCOUNT_UPDATED,
                "user_account", account.getId(), before, snapshot(account));

        // A reset is not a field edit.
        if (hasText(request.password())) {
            activityLogs.record(actor, null, ActivityAction.PASSWORD_RESET, "user_account", account.getId());
        }

        if (previousStatus != account.getStatus()) {
            activityLogs.record(
                    actor, null, ActivityAction.ACCOUNT_STATUS_CHANGED,
                    "user_account", account.getId(),
                    text(previousStatus), text(account.getStatus()));
        }

        return AccountResponse.of(account, doctorProfile);
    }

    @Transactional
    public void delete(UUID id) {
        UserAccount account = users.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Account not found"));

        JsonNode before = snapshot(account);

        if (account.getRole() == Role.DOCTOR) {
            doctors.deleteById(id);
        }

        users.deleteById(id);

        activityLogs.record(
                actor(), null, ActivityAction.ACCOUNT_DELETED,
                "user_account", id, before, null);
    }

    private UUID actor() {
        return currentUser.id().orElse(null);
    }

    // Never the password hash.
    private JsonNode snapshot(UserAccount account) {
        Map<String, Object> fields = new LinkedHashMap<>();
        fields.put("email", account.getEmail());
        fields.put("phone", account.getPhone());
        fields.put("firstName", account.getFirstName());
        fields.put("lastName", account.getLastName());
        fields.put("dateOfBirth", account.getDateOfBirth());
        fields.put("gender", account.getGender());
        fields.put("role", account.getRole());
        fields.put("status", account.getStatus());
        return objectMapper.valueToTree(fields);
    }

    private JsonNode text(AccountStatus status) {
        return objectMapper.valueToTree(Map.of("status", status));
    }

    private DoctorProfileResponse createDoctorProfile(
            UserAccount account,
            CreateAccountRequest request) {
        if (account.getRole() == Role.DOCTOR) {
            if (request.doctorProfile() == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Doctor profile is required");
            }

            DoctorProfile profile = new DoctorProfile(account);
            if (request.doctorProfile().specializations() != null) {
                profile.setSpecializations(
                        new ArrayList<>(request.doctorProfile().specializations()));
            }
            profile.setYearsOfExperience(request.doctorProfile().yearsOfExperience());
            return DoctorProfileResponse.of(doctors.save(profile));
        }

        if (account.getRole() == Role.RECEPTIONIST) {
            if (request.doctorProfile() != null) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Only doctor accounts may include a doctor profile");
            }
            return null;
        }

        throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST,
                "Only DOCTOR and RECEPTIONIST accounts may be created here");
    }

    private DoctorProfileResponse updateDoctorProfile(
            UserAccount account,
            CreateAccountRequest request) {
        if (account.getRole() == Role.DOCTOR) {
            if (request.doctorProfile() == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Doctor profile is required");
            }

            DoctorProfile profile = doctors.findById(account.getId())
                    .orElseGet(() -> new DoctorProfile(account));
            if (request.doctorProfile().specializations() != null) {
                profile.setSpecializations(new ArrayList<>(request.doctorProfile().specializations()));
            }
            profile.setYearsOfExperience(request.doctorProfile().yearsOfExperience());
            return DoctorProfileResponse.of(doctors.save(profile));
        }

        if (account.getRole() == Role.RECEPTIONIST) {
            if (request.doctorProfile() != null) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Only doctor accounts may include a doctor profile");
            }
            doctors.findById(account.getId()).ifPresent(doctors::delete);
            return null;
        }

        throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST,
                "Only DOCTOR and RECEPTIONIST accounts may be updated here");
    }

    @Transactional(readOnly = true)
    public List<AccountResponse> list(Role role) {
        if (role != null && !STAFF_ROLES.contains(role)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Only DOCTOR and RECEPTIONIST accounts may be listed here");
        }

        Set<Role> roles = role == null ? STAFF_ROLES : Set.of(role);
        List<UserAccount> accounts = users.findAllByRoleInOrderByLastNameAscFirstNameAsc(roles);
        Map<UUID, DoctorProfileResponse> doctorProfiles = doctors.findAllById(
                accounts.stream()
                        .filter(account -> account.getRole() == Role.DOCTOR)
                        .map(UserAccount::getId)
                        .toList())
                .stream()
                .collect(Collectors.toMap(
                        DoctorProfile::getUserId,
                        DoctorProfileResponse::of));

        return accounts.stream()
                .map(account -> AccountResponse.of(
                        account,
                        doctorProfiles.get(account.getId())))
                .toList();
    }

    private void validateCreatePassword(String password) {
        if (!hasText(password)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Password is required");
        }

        if (password.length() < 8) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Password must be at least 8 characters");
        }
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
