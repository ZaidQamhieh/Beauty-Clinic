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

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

// REGULAR carries the weekly pattern. VACATION/MODIFIED/EXTRA_DAY are dated
// exceptions resolved by priority in DoctorAvailabilityService.resolveDay -
// VACATION and MODIFIED replace the day outright; EXTRA_DAY only ever fills a day
// that would otherwise resolve to nothing.
@Entity
@Table(name = "doctor_availability")
@SoftDelete
@Getter
@Setter
@NoArgsConstructor
public class DoctorAvailability {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "doctor_user_id", nullable = false)
    private DoctorProfile doctor;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AvailabilityKind kind;

    @Enumerated(EnumType.STRING)
    @Column(name = "day_of_week", length = 10)
    private DayOfWeek dayOfWeek;

    @Column(name = "start_time")
    private LocalTime startTime;

    @Column(name = "end_time")
    private LocalTime endTime;

    @NotNull
    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    public DoctorAvailability(
            DoctorProfile doctor,
            AvailabilityKind kind,
            DayOfWeek dayOfWeek,
            LocalTime startTime,
            LocalTime endTime,
            LocalDate effectiveFrom
    ) {
        this.doctor = doctor;
        this.kind = kind;
        this.dayOfWeek = dayOfWeek;
        this.startTime = startTime;
        this.endTime = endTime;
        this.effectiveFrom = effectiveFrom;
    }

    public enum AvailabilityKind {
        REGULAR,
        VACATION,
        MODIFIED,
        EXTRA_DAY
    }
}
