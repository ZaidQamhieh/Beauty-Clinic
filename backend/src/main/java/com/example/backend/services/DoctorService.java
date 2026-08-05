package com.example.backend.services;

import com.example.backend.doctor.WorkingHours;
import com.example.backend.dtos.DoctorResponse;
import com.example.backend.dtos.EditDoctorProfileRequest;
import com.example.backend.dtos.RegisterDoctorRequest;
import com.example.backend.entities.ClinicService;
import com.example.backend.entities.Doctor;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.ClinicServiceRepository;
import com.example.backend.repositories.DoctorRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DoctorService {

    private final DoctorRepository doctors;
    private final UserAccountRepository users;
    private final ClinicServiceRepository services;

    @Transactional
    public DoctorResponse register(RegisterDoctorRequest request) {
        UserAccount account = users.findById(request.userId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such account"));

        if (account.getRole() != Role.DOCTOR) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Account is not a doctor");
        }

        if (doctors.existsById(account.getId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Doctor profile already exists");
        }

        Doctor doctor = new Doctor(account);
        doctor.setSpecialty(request.specialty());
        doctor.setLicenseNumber(request.licenseNumber());
        doctor.setBio(request.bio());

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
    public DoctorResponse updateProfile(UUID userId, EditDoctorProfileRequest request) {
        Doctor doctor = require(userId);
        doctor.setSpecialty(request.specialty());
        doctor.setLicenseNumber(request.licenseNumber());
        doctor.setBio(request.bio());
        return DoctorResponse.of(doctor);
    }

    @Transactional
    public DoctorResponse setWorkingHours(UUID userId, List<WorkingHours> availability) {
        Doctor doctor = require(userId);
        doctor.setAvailability(availability);
        return DoctorResponse.of(doctor);
    }

    @Transactional
    public DoctorResponse setServices(UUID userId, Set<UUID> serviceIds) {
        Doctor doctor = require(userId);

        List<ClinicService> found = services.findAllById(serviceIds);
        if (found.size() != serviceIds.size()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "One or more services do not exist");
        }

        // Edited in place rather than replaced wholesale: handing Hibernate a new
        // collection makes it drop every row and reinsert the lot, and since these
        // rows are soft-deleted that would leave a tombstone per treatment on
        // every save. Mutating the managed set touches only what actually changed.
        Set<ClinicService> offered = doctor.getServices();
        offered.removeIf(offering -> !serviceIds.contains(offering.getId()));

        Set<UUID> alreadyOffered = offered.stream()
                .map(ClinicService::getId)
                .collect(Collectors.toSet());

        found.stream()
                .filter(service -> !alreadyOffered.contains(service.getId()))
                .forEach(offered::add);

        return DoctorResponse.of(doctor);
    }

    private Doctor require(UUID userId) {
        return doctors.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));
    }
}
