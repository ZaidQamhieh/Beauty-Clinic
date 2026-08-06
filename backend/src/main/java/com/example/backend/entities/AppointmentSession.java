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

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

// Price and duration copied at booking, so a tariff change never re-prices past work.
@Entity
@Table(name = "appointment_session")
@SoftDelete
@Getter
@Setter
@NoArgsConstructor
public class AppointmentSession {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "appointment_id", nullable = false)
    private Appointment appointment;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "practitioner_user_id", nullable = false)
    private DoctorProfile practitioner;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private TreatmentCategory category;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(name = "treatment_name", nullable = false, length = 60)
    private TreatmentName treatmentName;

    @NotNull
    @Column(name = "price_charged", nullable = false)
    private BigDecimal priceCharged;

    @NotNull
    @Column(name = "duration_minutes", nullable = false)
    private Integer durationMinutes;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private SessionStatus status = SessionStatus.PLANNED;

    @NotNull
    @Column(name = "start_time", nullable = false)
    private Instant startTime;

    @NotNull
    @Column(name = "end_time", nullable = false)
    private Instant endTime;

    @Column(name = "before_photo_key", length = 500)
    private String beforePhotoKey;

    @Column(name = "after_photo_key", length = 500)
    private String afterPhotoKey;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    public AppointmentSession(
            Appointment appointment,
            DoctorProfile practitioner,
            TreatmentCategory category,
            TreatmentName treatmentName,
            BigDecimal priceCharged,
            Integer durationMinutes,
            Instant startTime,
            Instant endTime
    ) {
        this.appointment = appointment;
        this.practitioner = practitioner;
        this.category = category;
        this.treatmentName = treatmentName;
        this.priceCharged = priceCharged;
        this.durationMinutes = durationMinutes;
        this.startTime = startTime;
        this.endTime = endTime;
    }

    public enum SessionStatus {
        PLANNED,
        COMPLETED,
        CANCELLED,
        NO_SHOW
    }

    public enum TreatmentCategory {
        FACIAL,
        LASER,
        INJECTABLE,
        BODY,
        CONSULTATION
    }

    public enum TreatmentName {
        HYDRAFACIAL,
        CHEMICAL_PEEL,
        MICRONEEDLING,
        DERMAPLANING,
        LASER_HAIR_REMOVAL,
        LASER_RESURFACING,
        IPL_PHOTOFACIAL,
        BOTOX,
        DERMAL_FILLER,
        MESOTHERAPY,
        BODY_CONTOURING,
        CONSULTATION
    }
}
