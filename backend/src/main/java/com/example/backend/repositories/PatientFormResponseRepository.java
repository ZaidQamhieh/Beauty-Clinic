package com.example.backend.repositories;

import com.example.backend.entities.PatientFormResponse;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientFormResponseRepository extends JpaRepository<PatientFormResponse, PatientFormResponse.Id> {
}
