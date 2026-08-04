package com.example.backend.treatment;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface TreatmentRecordRepository extends JpaRepository<TreatmentRecord, UUID> {
}
