package com.example.backend.repositories;

import com.example.backend.entities.PrescriptionProduct;
import com.example.backend.entities.PrescriptionProductId;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface PrescriptionProductRepository
        extends JpaRepository<PrescriptionProduct, PrescriptionProductId> {

    List<PrescriptionProduct> findBySessionRecordId(UUID sessionRecordId);
}
