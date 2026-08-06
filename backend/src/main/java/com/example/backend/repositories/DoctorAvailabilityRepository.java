package com.example.backend.repositories;

import com.example.backend.entities.DoctorAvailability;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface DoctorAvailabilityRepository extends JpaRepository<DoctorAvailability, UUID> {

    List<DoctorAvailability> findByDoctorUserId(UUID doctorUserId);
}
