package com.example.backend.doctor;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface DoctorAvailabilityRepository extends JpaRepository<DoctorAvailability, UUID> {

    Sort BY_SLOT = Sort.by("dayOfWeek", "startTime");

    List<DoctorAvailability> findByDoctorUserId(UUID doctorUserId, Sort sort);
}
