package com.example.backend.repositories;

import com.example.backend.entities.PatientProduct;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface PatientProductRepository extends JpaRepository<PatientProduct, UUID> {

    List<PatientProduct> findByPatientUserId(UUID patientUserId);

    boolean existsByPatientUserIdAndProductId(UUID patientUserId, UUID productId);
}
