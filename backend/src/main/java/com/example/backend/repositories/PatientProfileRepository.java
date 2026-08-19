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

    // Doctors see only patients they treat.
    @Query("""
            select p from PatientProfile p
            where (lower(p.user.firstName) like lower(concat('%', :term, '%'))
               or lower(p.user.lastName) like lower(concat('%', :term, '%'))
               or lower(p.user.email) like lower(concat('%', :term, '%'))
               or p.user.phone like concat('%', :term, '%'))
              and exists (
                  select s from AppointmentSession s
                  where s.appointment.patient.userId = p.userId
                    and s.practitioner.userId = :doctorUserId
                    and s.status <> CANCELLED
                    and (s.appointment.createdBy is null
                         or s.appointment.createdBy.id <> :doctorUserId)
              )
            """)
    Page<PatientProfile> searchTreatedBy(
            @Param("term") String term,
            @Param("doctorUserId") UUID doctorUserId,
            Pageable pageable);

    // Row held so bookings cannot race.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from PatientProfile p where p.userId = :userId")
    Optional<PatientProfile> lockForBooking(@Param("userId") UUID userId);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"user"})
    @Query("select p from PatientProfile p")
    java.util.List<PatientProfile> findAllWithUser();
}
