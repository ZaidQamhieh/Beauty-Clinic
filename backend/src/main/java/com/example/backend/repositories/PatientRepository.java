package com.example.backend.repositories;

import com.example.backend.entities.Patient;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface PatientRepository extends JpaRepository<Patient, UUID> {

    Optional<Patient> findByUserId(UUID userId);

    boolean existsByIdAndUserId(UUID id, UUID userId);

    @Query("""
            select p from Patient p
            where lower(p.firstName) like lower(concat('%', :term, '%'))
               or lower(p.lastName) like lower(concat('%', :term, '%'))
               or lower(p.email) like lower(concat('%', :term, '%'))
               or p.phone like concat('%', :term, '%')
            """)
    Page<Patient> search(@Param("term") String term, Pageable pageable);
}
