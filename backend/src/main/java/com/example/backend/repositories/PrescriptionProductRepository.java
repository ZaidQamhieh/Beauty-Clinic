package com.example.backend.repositories;

import com.example.backend.entities.PrescriptionProduct;
import com.example.backend.entities.PrescriptionProductId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface PrescriptionProductRepository
        extends JpaRepository<PrescriptionProduct, PrescriptionProductId> {

    List<PrescriptionProduct> findBySessionRecordId(UUID sessionRecordId);

    @Query("""
            select distinct pp from PrescriptionProduct pp
            where pp.sessionRecord.session.appointment.patient.userId = :patientUserId
            """)
    List<PrescriptionProduct> findForPatient(@Param("patientUserId") UUID patientUserId);
}
