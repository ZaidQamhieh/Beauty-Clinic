package com.example.backend.repositories;

import com.example.backend.entities.AppointmentStatus;
import com.example.backend.entities.Appointment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface AppointmentRepository extends JpaRepository<Appointment, UUID> {

    // Backs the rule letting a doctor reach patients they have treated.
    boolean existsByDoctorUserIdAndPatientId(UUID doctorUserId, UUID patientId);

    // Backs the rule letting a patient reach their own appointment.
    boolean existsByIdAndPatientUserId(UUID appointmentId, UUID patientUserId);

    List<Appointment> findByPatientId(UUID patientId);

    // Half-open [from, to): a derived ...Between would be inclusive at both ends
    // and hand midnight's appointment to two consecutive days.
    @Query("""
            select a from Appointment a
            where a.doctor.userId = :doctorUserId
              and a.startTime >= :from
              and a.startTime < :to
            """)
    List<Appointment> findForDoctorBetween(
            @Param("doctorUserId") UUID doctorUserId,
            @Param("from") Instant from,
            @Param("to") Instant to
    );

    @Query("""
            select a from Appointment a
            where a.startTime >= :from
              and a.startTime < :to
            """)
    List<Appointment> findBetween(@Param("from") Instant from, @Param("to") Instant to);

    @Query("""
            select case when count(a) > 0 then true else false end
            from Appointment a
            where a.doctor.userId = :doctorUserId
              and a.status <> :cancelled
              and a.startTime < :endTime
              and a.endTime > :startTime
            """)
    boolean existsOverlappingAppointmentExcluding(
            @Param("doctorUserId") UUID doctorUserId,
            @Param("cancelled") AppointmentStatus cancelled,
            @Param("startTime") Instant startTime,
            @Param("endTime") Instant endTime
    );

    // Mirrors appointment_no_double_booking, which reserves the slot for every
    // status except CANCELLED. Checking only BOOKED would let a booking over a
    // COMPLETED or NO_SHOW slot pass here and then fail on the constraint.
    default boolean existsOverlappingActiveAppointment(UUID doctorUserId, Instant startTime, Instant endTime) {
        return existsOverlappingAppointmentExcluding(
                doctorUserId, AppointmentStatus.CANCELLED, startTime, endTime
        );
    }
}
