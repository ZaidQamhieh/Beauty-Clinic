package com.example.backend.repositories;

import com.example.backend.entities.DoctorProfile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface DoctorProfileRepository extends JpaRepository<DoctorProfile, UUID> {
}
