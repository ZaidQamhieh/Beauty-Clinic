package com.example.backend.repositories;

import com.example.backend.entities.PatientProfile;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
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

    // One row, held for the booking transaction, so two bookings cannot both read "no clash".
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from PatientProfile p where p.userId = :userId")
    Optional<PatientProfile> lockForBooking(@Param("userId") UUID userId);
}
