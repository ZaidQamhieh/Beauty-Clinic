package com.example.backend.repositories;

import com.example.backend.entities.TreatmentRecord;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface TreatmentRecordRepository extends JpaRepository<TreatmentRecord, UUID> {
}
