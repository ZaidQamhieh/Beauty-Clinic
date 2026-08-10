package com.example.backend.entities;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.SoftDelete;

import java.time.Instant;
import java.util.UUID;

// A visit; treatments and practitioners live on AppointmentSession, one visit carrying several.
@Entity
@Table(name = "appointment")
@SoftDelete
@Getter
@Setter
@NoArgsConstructor
public class Appointment {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    // Eager, not by choice: Hibernate rejects a lazy to-one into a @SoftDelete entity.
    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "patient_user_id", nullable = false)
    private PatientProfile patient;

    @NotNull
    @Column(name = "scheduled_at", nullable = false)
    private Instant scheduledAt;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AppointmentStatus status = AppointmentStatus.BOOKED;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "created_by_user_id")
    private UserAccount createdBy;

    // Rescheduling cancels the old row and books a new one pointing here.
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "replaces_appointment_id")
    private Appointment replaces;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    public Appointment(PatientProfile patient, Instant scheduledAt) {
        this.patient = patient;
        this.scheduledAt = scheduledAt;
    }

    public void cancel() {
        this.status = AppointmentStatus.CANCELLED;
        this.cancelledAt = Instant.now();
    }

    // Visit-level only. Whether work happened is a property of the sessions.
    public enum AppointmentStatus {
        BOOKED,
        CANCELLED
    }
}
