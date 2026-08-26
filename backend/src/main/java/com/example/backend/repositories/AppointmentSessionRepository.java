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

    // The response reads the practitioner's name, so fetch it with the row.
    @EntityGraph(attributePaths = {"practitioner", "practitioner.user"})
    List<AppointmentSession> findByAppointmentIdIn(Collection<UUID> appointmentIds);

    // Matched in SQL: the parent is a @SoftDelete to-one and would read as null.
    Optional<AppointmentSession> findByIdAndAppointmentId(UUID id, UUID appointmentId);

    // Held for the transaction, so two status changes queue instead of overwriting.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<AppointmentSession> findWithLockByIdAndAppointmentId(UUID id, UUID appointmentId);

    // Lets a doctor reach patients they treat. Cancelled does not count.
    @Query("""
            select count(s) > 0
            from AppointmentSession s
            where s.practitioner.userId = :doctorUserId
              and s.patientUserId = :patientUserId
              and s.status <> CANCELLED
            """)
    boolean existsByPractitionerAndPatient(
            @Param("doctorUserId") UUID doctorUserId,
            @Param("patientUserId") UUID patientUserId
    );

    // Overlap, not start time: a session running past midnight still holds the room next day.
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

    // Every candidate doctor's day in one read, so a slot search is not one query per doctor.
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

    // The patient is one body: what they already hold blocks every doctor, not just one.
    @EntityGraph(attributePaths = {"appointment", "practitioner"})
    @Query("""
            select s from AppointmentSession s
            where s.appointment.patient.userId = :patientUserId
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

    // Mirrors session_no_practitioner_overlap: every status but CANCELLED holds the slot.
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

    // The named error for what session_no_patient_overlap would otherwise reject as a raw violation.
    @Query("""
            select count(s) > 0
            from AppointmentSession s
            where s.appointment.patient.userId = :patientUserId
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

    @Query("""
            select s from AppointmentSession s
            where s.status = com.example.backend.entities.AppointmentSession.SessionStatus.COMPLETED
              and s.startTime >= :from and s.startTime < :to
            """)
    List<AppointmentSession> findCompletedBetween(
            @Param("from") Instant from,
            @Param("to") Instant to
    );

    @EntityGraph(attributePaths = {"appointment", "appointment.patient", "appointment.patient.user", "practitioner", "practitioner.user"})
    @Query("""
            select s from AppointmentSession s
            where s.practitioner.userId = :doctorUserId
              and s.startTime >= :from and s.startTime < :to
            order by s.startTime asc
            """)
    List<AppointmentSession> findForPractitionerBetweenWithDetails(
            @Param("doctorUserId") UUID doctorUserId,
            @Param("from") Instant from,
            @Param("to") Instant to
    );

    @Query("""
            select count(distinct s.patientUserId)
            from AppointmentSession s
            where s.practitioner.userId = :doctorUserId
              and s.status <> com.example.backend.entities.AppointmentSession.SessionStatus.CANCELLED
            """)
    int countActivePatients(@Param("doctorUserId") UUID doctorUserId);

    @Query("""
            select count(distinct s.patientUserId)
            from AppointmentSession s
            where s.practitioner.userId = :doctorUserId
              and s.startTime >= :from and s.startTime < :to
              and s.status <> com.example.backend.entities.AppointmentSession.SessionStatus.CANCELLED
            """)
    int countActivePatientsBetween(
            @Param("doctorUserId") UUID doctorUserId,
            @Param("from") Instant from,
            @Param("to") Instant to
    );
}
