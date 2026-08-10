package com.example.backend.entities;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.MapsId;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.SoftDelete;
import org.hibernate.type.SqlTypes;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

// Keyed on the account it belongs to: one person, one identifier.
@Entity
@Table(name = "doctor_profile")
@SoftDelete
@Getter
@Setter
@NoArgsConstructor
public class DoctorProfile {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @MapsId
    @OneToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "user_id")
    private UserAccount user;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(nullable = false, columnDefinition = "text[]")
    private List<Specialization> specializations = new ArrayList<>();

    @Column(name = "years_of_experience")
    private Integer yearsOfExperience;

    public DoctorProfile(UserAccount user) {
        this.user = user;
    }

    public enum Specialization {
        DERMATOLOGY,
        COSMETIC_DERMATOLOGY,
        LASER_THERAPY,
        INJECTABLES,
        AESTHETIC_MEDICINE
    }
}
