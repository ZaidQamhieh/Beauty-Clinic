package com.example.backend.repositories;

import com.example.backend.entities.PatientProfile;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.UUID;

public interface PatientProfileRepository extends JpaRepository<PatientProfile, UUID> {

    @Query("""
            select p from PatientProfile p
            where lower(p.user.firstName) like lower(concat('%', :term, '%'))
               or lower(p.user.lastName) like lower(concat('%', :term, '%'))
               or lower(p.user.email) like lower(concat('%', :term, '%'))
               or p.user.phone like concat('%', :term, '%')
            """)
    Page<PatientProfile> search(@Param("term") String term, Pageable pageable);
}
