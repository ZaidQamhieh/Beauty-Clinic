package com.example.backend.repositories;

import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AppointmentSessionRepository extends JpaRepository<AppointmentSession, UUID> {

    List<AppointmentSession> findByAppointmentId(UUID appointmentId);

    List<AppointmentSession> findByAppointmentIdIn(Collection<UUID> appointmentIds);

    // Matched in SQL: the parent is a @SoftDelete to-one and would read as null.
    Optional<AppointmentSession> findByIdAndAppointmentId(UUID id, UUID appointmentId);

    // Backs the rule letting a doctor reach patients they have treated.
    @Query("""
            select case when count(s) > 0 then true else false end
            from AppointmentSession s
            where s.practitioner.userId = :doctorUserId
              and s.appointment.patient.userId = :patientUserId
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

    @Query("""
            select case when count(s) > 0 then true else false end
            from AppointmentSession s
            where s.practitioner.userId = :doctorUserId
              and s.status <> :cancelled
              and s.startTime < :endTime
              and s.endTime > :startTime
            """)
    boolean existsOverlappingSessionExcluding(
            @Param("doctorUserId") UUID doctorUserId,
            @Param("cancelled") SessionStatus cancelled,
            @Param("startTime") Instant startTime,
            @Param("endTime") Instant endTime
    );

    // Mirrors session_no_practitioner_overlap: every status but CANCELLED holds the slot.
    default boolean existsOverlappingActiveSession(UUID doctorUserId, Instant startTime, Instant endTime) {
        return existsOverlappingSessionExcluding(
                doctorUserId, SessionStatus.CANCELLED, startTime, endTime
        );
    }

    // Across every visit: session_no_patient_overlap is keyed on appointment_id, so it sees one.
    @Query("""
            select case when count(s) > 0 then true else false end
            from AppointmentSession s
            where s.appointment.patient.userId = :patientUserId
              and s.status <> :cancelled
              and s.startTime < :endTime
              and s.endTime > :startTime
            """)
    boolean existsOverlappingForPatientExcluding(
            @Param("patientUserId") UUID patientUserId,
            @Param("cancelled") SessionStatus cancelled,
            @Param("startTime") Instant startTime,
            @Param("endTime") Instant endTime
    );

    default boolean existsOverlappingActiveSessionForPatient(
            UUID patientUserId, Instant startTime, Instant endTime) {
        return existsOverlappingForPatientExcluding(
                patientUserId, SessionStatus.CANCELLED, startTime, endTime
        );
    }
}
