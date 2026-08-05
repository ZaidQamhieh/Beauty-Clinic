package com.example.backend.repositories;

import com.example.backend.entities.Appointment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface AppointmentRepository extends JpaRepository<Appointment, UUID> {

    // Backs the rule letting a doctor reach patients they have treated.
    boolean existsByDoctorUserIdAndPatientId(UUID doctorUserId, UUID patientId);
}
