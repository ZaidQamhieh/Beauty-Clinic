package com.example.backend.services;

import com.example.backend.dtos.DoctorResponse;
import com.example.backend.dtos.DoctorProfileRequest;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.stream.Collectors;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

import com.example.backend.repositories.AppointmentSessionRepository;

@Service
@RequiredArgsConstructor
public class DoctorService {

    private final DoctorProfileRepository doctors;
    private final UserAccountRepository users;
    private final AppointmentSessionRepository sessions;

    @Transactional
    public DoctorResponse register(UUID userId, DoctorProfileRequest request) {
        UserAccount account = users.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such account"));

        if (account.getRole() != Role.DOCTOR) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Account is not a doctor");
        }

        if (doctors.existsById(account.getId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Doctor profile already exists");
        }

        DoctorProfile doctor = new DoctorProfile(account);
        if (request.specializations() != null) {
            // The column CHECK tests containment, not distinctness, so duplicates store.
            doctor.setSpecializations(
                    request.specializations().stream().distinct()
                            .collect(Collectors.toCollection(ArrayList::new)));
        }
        doctor.setYearsOfExperience(request.yearsOfExperience());

        return DoctorResponse.of(doctors.save(doctor));
    }

    @Transactional(readOnly = true)
    public List<DoctorResponse> list() {
        return doctors.findAll().stream()
                .map(DoctorResponse::of)
                .sorted(Comparator.comparing(DoctorResponse::fullName))
                .toList();
    }

    @Transactional(readOnly = true)
    public DoctorResponse read(UUID userId) {
        return DoctorResponse.of(require(userId));
    }

    @Transactional
    public DoctorResponse updateProfile(UUID userId, DoctorProfileRequest request) {
        DoctorProfile doctor = require(userId);
        if (request.specializations() != null) {
            // The column CHECK tests containment, not distinctness, so duplicates store.
            doctor.setSpecializations(
                    request.specializations().stream().distinct()
                            .collect(Collectors.toCollection(ArrayList::new)));
        }
        doctor.setYearsOfExperience(request.yearsOfExperience());
        return DoctorResponse.of(doctor);
    }

    @Transactional
    public void delete(UUID userId) {
        DoctorProfile doctor = require(userId);

        // Prevent removing a doctor who has any session records.
        if (sessions.existsByPractitioner(userId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Doctor has appointment sessions and cannot be removed");
        }

        doctors.delete(doctor);
    }

    private DoctorProfile require(UUID userId) {
        return doctors.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));
    }
}
