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

import com.example.backend.entities.DoctorProfile.Specialization;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Collection;
import java.util.Set;
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

    // Which specialization qualifies someone to perform the category; empty means anyone may.
    public enum TreatmentCategory {
        FACIAL(Set.of(Specialization.COSMETIC_DERMATOLOGY, Specialization.DERMATOLOGY)),
        LASER(Set.of(Specialization.LASER_THERAPY)),
        INJECTABLE(Set.of(Specialization.INJECTABLES)),
        BODY(Set.of(Specialization.AESTHETIC_MEDICINE)),
        CONSULTATION(Set.of());

        private final Set<Specialization> qualifying;

        TreatmentCategory(Set<Specialization> qualifying) {
            this.qualifying = qualifying;
        }

        public Set<Specialization> qualifying() {
            return qualifying;
        }

        public boolean qualifies(Collection<Specialization> held) {
            return qualifying.isEmpty() || held.stream().anyMatch(qualifying::contains);
        }
    }

    // Category belongs to the treatment; the columns CHECK apart, so BOTOX could store as FACIAL.
    public enum TreatmentName {
        HYDRAFACIAL(TreatmentCategory.FACIAL),
        CHEMICAL_PEEL(TreatmentCategory.FACIAL),
        MICRONEEDLING(TreatmentCategory.FACIAL),
        DERMAPLANING(TreatmentCategory.FACIAL),
        LASER_HAIR_REMOVAL(TreatmentCategory.LASER),
        LASER_RESURFACING(TreatmentCategory.LASER),
        IPL_PHOTOFACIAL(TreatmentCategory.LASER),
        BOTOX(TreatmentCategory.INJECTABLE),
        DERMAL_FILLER(TreatmentCategory.INJECTABLE),
        MESOTHERAPY(TreatmentCategory.INJECTABLE),
        BODY_CONTOURING(TreatmentCategory.BODY),
        CONSULTATION(TreatmentCategory.CONSULTATION);

        private final TreatmentCategory category;

        TreatmentName(TreatmentCategory category) {
            this.category = category;
        }

        public TreatmentCategory category() {
            return category;
        }
    }
}
