package com.example.backend.repositories;

import com.example.backend.entities.Appointment;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AppointmentRepository extends JpaRepository<Appointment, UUID> {

    // Backs the rule letting a patient reach their own appointment.
    boolean existsByIdAndPatientUserId(UUID appointmentId, UUID patientUserId);

    // Two sessions of one visit must not both decide its state.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select a from Appointment a where a.id = :id")
    Optional<Appointment> findWithLockById(@Param("id") UUID id);

    List<Appointment> findByPatientUserId(UUID patientUserId);

    // Ordered in SQL, so a page is a slice of the run, not sorted alone.
    Page<Appointment> findByPatientUserIdOrderByScheduledAtAsc(UUID patientUserId, Pageable pageable);

    // A rescheduled visit is superseded, so the replacement shows and the original does not.
    @EntityGraph(attributePaths = {"patient", "patient.user"})
    @Query("""
            select a from Appointment a
            where a.patient.userId = :patientUserId
              and not exists (select 1 from Appointment r where r.replaces = a)
            order by a.scheduledAt asc, a.id asc
            """)
    Page<Appointment> findNotSupersededForPatient(
            @Param("patientUserId") UUID patientUserId, Pageable pageable);

    // Half-open [from, to): a derived Between would hand midnight to two days.
    @Query("""
            select a from Appointment a
            where a.scheduledAt >= :from
              and a.scheduledAt < :to
            """)
    List<Appointment> findBetween(@Param("from") Instant from, @Param("to") Instant to);

    // Booked, not yet started, soonest first.
    @EntityGraph(attributePaths = {"patient", "patient.user"})
    @Query("""
            select a from Appointment a
            where a.patient.userId = :patientUserId
              and a.status = BOOKED
              and a.scheduledAt >= :now
              and not exists (select 1 from Appointment r where r.replaces = a)
            order by a.scheduledAt asc, a.id asc
            """)
    Page<Appointment> findUpcomingForPatient(
            @Param("patientUserId") UUID patientUserId,
            @Param("now") Instant now,
            Pageable pageable);

    // Begun or cancelled, most recent first.
    @EntityGraph(attributePaths = {"patient", "patient.user"})
    @Query("""
            select a from Appointment a
            where a.patient.userId = :patientUserId
              and (a.status = CANCELLED or a.scheduledAt < :now)
              and not exists (select 1 from Appointment r where r.replaces = a)
            order by a.scheduledAt desc, a.id desc
            """)
    Page<Appointment> findHistoryForPatient(
            @Param("patientUserId") UUID patientUserId,
            @Param("now") Instant now,
            Pageable pageable);
}
