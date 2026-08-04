package com.example.backend.appointment;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface AppointmentRepository extends JpaRepository<Appointment, UUID> {

    Sort NEWEST_FIRST = Sort.by(Sort.Direction.DESC, "startTime");
    Sort CHRONOLOGICAL = Sort.by("startTime");

    List<Appointment> findByPatientId(UUID patientId, Sort sort);

    List<Appointment> findByPatientUserId(UUID userId, Sort sort);

    List<Appointment> findByDoctorUserIdAndStartTimeBetween(
            UUID doctorUserId, Instant from, Instant to, Sort sort
    );

    List<Appointment> findByStartTimeBetween(Instant from, Instant to, Sort sort);

    boolean existsByDoctorUserIdAndPatientId(UUID doctorUserId, UUID patientId);
}
