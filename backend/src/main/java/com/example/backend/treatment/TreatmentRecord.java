package com.example.backend.treatment;

import com.example.backend.appointment.Appointment;
import com.example.backend.user.UserAccount;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "treatment_record")
@Getter
@Setter
@NoArgsConstructor
public class TreatmentRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "appointment_id", nullable = false)
    private Appointment appointment;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recorded_by_user_id", nullable = false)
    private UserAccount recordedBy;

    @Column
    private String diagnosis;

    @Column
    private String treatment;

    @Column
    private String notes;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "amends_record_id", unique = true)
    private TreatmentRecord amends;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public TreatmentRecord(Appointment appointment, UserAccount recordedBy) {
        this.appointment = appointment;
        this.recordedBy = recordedBy;
    }
}
