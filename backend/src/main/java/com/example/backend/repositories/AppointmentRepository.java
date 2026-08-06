package com.example.backend.repositories;

import com.example.backend.entities.Appointment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface AppointmentRepository extends JpaRepository<Appointment, UUID> {

    // Backs the rule letting a patient reach their own appointment.
    boolean existsByIdAndPatientUserId(UUID appointmentId, UUID patientUserId);

    List<Appointment> findByPatientUserId(UUID patientUserId);

    // Half-open [from, to): a derived Between would hand midnight to two days.
    @Query("""
            select a from Appointment a
            where a.scheduledAt >= :from
              and a.scheduledAt < :to
            """)
    List<Appointment> findBetween(@Param("from") Instant from, @Param("to") Instant to);
}
