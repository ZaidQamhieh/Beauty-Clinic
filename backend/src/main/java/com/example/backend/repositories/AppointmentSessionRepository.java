package com.example.backend.repositories;

import com.example.backend.entities.AppointmentSession;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AppointmentSessionRepository extends JpaRepository<AppointmentSession, UUID> {

    List<AppointmentSession> findByAppointmentId(UUID appointmentId);

    // Response reads the name; fetch it.
    @EntityGraph(attributePaths = {"practitioner", "practitioner.user"})
    List<AppointmentSession> findByAppointmentIdIn(Collection<UUID> appointmentIds);

    // Matched in SQL; parent is soft-deleted.
    Optional<AppointmentSession> findByIdAndAppointmentId(UUID id, UUID appointmentId);

    // Held so status changes queue.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<AppointmentSession> findWithLockByIdAndAppointmentId(UUID id, UUID appointmentId);

    // Doctors reach patients they treat.
    @Query("""
            select count(s) > 0
            from AppointmentSession s
            where s.practitioner.userId = :doctorUserId
              and s.appointment.patient.userId = :patientUserId
              and s.status <> CANCELLED
              and (s.appointment.createdBy is null
                   or s.appointment.createdBy.id <> :doctorUserId)
            """)
    boolean existsByPractitionerAndPatient(
            @Param("doctorUserId") UUID doctorUserId,
            @Param("patientUserId") UUID patientUserId
    );

    // Overlap, not start; midnight spans count.
    @Query("""
            select s from AppointmentSession s
            where s.practitioner.userId = :doctorUserId
              and s.startTime < :to
              and s.endTime > :from
            """)
    List<AppointmentSession> findForPractitionerBetween(
            @Param("doctorUserId") UUID doctorUserId,
            @Param("from") Instant from,
            @Param("to") Instant to
    );

    // Whole roster in one read.
    @EntityGraph(attributePaths = {"appointment", "practitioner"})
    @Query("""
            select s from AppointmentSession s
            where s.practitioner.userId in :doctorUserIds
              and s.startTime < :to
              and s.endTime > :from
            """)
    List<AppointmentSession> findForPractitionersBetween(
            @Param("doctorUserIds") Collection<UUID> doctorUserIds,
            @Param("from") Instant from,
            @Param("to") Instant to
    );

    // Own patient column; blocks every doctor.
    @EntityGraph(attributePaths = {"appointment", "practitioner"})
    @Query("""
            select s from AppointmentSession s
            where s.patientUserId = :patientUserId
              and s.startTime < :to
              and s.endTime > :from
            """)
    List<AppointmentSession> findForPatientBetween(
            @Param("patientUserId") UUID patientUserId,
            @Param("from") Instant from,
            @Param("to") Instant to
    );

    @Query("""
            select count(s) > 0
            from AppointmentSession s
            where s.practitioner.userId = :doctorUserId
            """)
    boolean existsByPractitioner(@Param("doctorUserId") UUID doctorUserId);

    // Mirrors the practitioner overlap constraint.
    @Query("""
            select count(s) > 0
            from AppointmentSession s
            where s.practitioner.userId = :doctorUserId
              and s.status <> CANCELLED
              and s.startTime < :endTime
              and s.endTime > :startTime
            """)
    boolean existsOverlappingActiveSession(
            @Param("doctorUserId") UUID doctorUserId,
            @Param("startTime") Instant startTime,
            @Param("endTime") Instant endTime
    );

    // Names what the constraint would reject.
    @Query("""
            select count(s) > 0
            from AppointmentSession s
            where s.patientUserId = :patientUserId
              and s.status <> CANCELLED
              and s.startTime < :endTime
              and s.endTime > :startTime
            """)
    boolean existsOverlappingActiveSessionForPatient(
            @Param("patientUserId") UUID patientUserId,
            @Param("startTime") Instant startTime,
            @Param("endTime") Instant endTime
    );

    // Cheap stand-in for the day's slot picture.
    @Query("""
            select count(s), max(s.updatedAt)
            from AppointmentSession s
            where s.startTime >= :from
              and s.startTime < :to
            """)
    Object[] dayFingerprint(@Param("from") Instant from, @Param("to") Instant to);

    @EntityGraph(attributePaths = {"appointment", "appointment.patient", "appointment.patient.user", "practitioner", "practitioner.user"})
    @Query("""
            select s from AppointmentSession s
            where s.startTime >= :from and s.startTime < :to
            order by s.startTime asc
            """)
    List<AppointmentSession> findBetweenWithDetails(@Param("from") Instant from, @Param("to") Instant to);
}
