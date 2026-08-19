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

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

// Kept off UserAccount so reception reads names, not medications. Keyed on the account.
@Entity
@Table(name = "patient_profile")
@SoftDelete
@Getter
@Setter
@NoArgsConstructor
public class PatientProfile {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    // Eager, not by choice: Hibernate rejects a lazy to-one into a @SoftDelete entity.
    @MapsId
    @OneToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "user_id")
    private UserAccount user;

    @Column(name = "pregnant_breastfeeding", nullable = false)
    private boolean pregnantBreastfeeding = false;

    @Enumerated(EnumType.STRING)
    @Column(name = "skin_type", length = 20)
    private SkinType skinType;

    @Enumerated(EnumType.STRING)
    @Column(name = "smoking_status", length = 20)
    private SmokingStatus smokingStatus;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(nullable = false, columnDefinition = "text[]")
    private List<Allergy> allergies = new ArrayList<>();

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(nullable = false, columnDefinition = "text[]")
    private List<Medication> medications = new ArrayList<>();

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "chronic_conditions", nullable = false, columnDefinition = "text[]")
    private List<ChronicCondition> chronicConditions = new ArrayList<>();

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    public PatientProfile(UserAccount user) {
        this.user = user;
    }

    // Skin type marks the form as filled: every other answer may truthfully be empty.
    public boolean hasCompletedHealthForm() {
        return skinType != null;
    }

    public enum SkinType {
        NORMAL,
        DRY,
        OILY,
        COMBINATION,
        SENSITIVE
    }

    public enum SmokingStatus {
        NEVER,
        FORMER,
        CURRENT
    }

    public enum Allergy {
        NUTS,
        LATEX,
        PENICILLIN,
        SULFA,
        LIDOCAINE,
        FRAGRANCE,
        NICKEL,
        IODINE
    }

    public enum Medication {
        ISOTRETINOIN,
        ANTICOAGULANTS,
        IMMUNOSUPPRESSANTS,
        ORAL_STEROIDS,
        HORMONAL_CONTRACEPTIVES,
        ANTIBIOTICS
    }

    public enum ChronicCondition {
        DIABETES,
        HYPERTENSION,
        ECZEMA,
        PSORIASIS,
        ROSACEA,
        THYROID_DISORDER,
        AUTOIMMUNE
    }
}
