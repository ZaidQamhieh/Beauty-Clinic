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

import java.time.LocalDate;
import java.util.UUID;

// What the patient uses now, not what was prescribed. discontinuedOn keeps it current.
@Entity
@Table(name = "patient_product")
@SoftDelete
@Getter
@Setter
@NoArgsConstructor
public class PatientProduct {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "patient_user_id", nullable = false)
    private PatientProfile patient;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ProductSource source;

    @Column(name = "started_on")
    private LocalDate startedOn;

    @Column(name = "discontinued_on")
    private LocalDate discontinuedOn;

    public PatientProduct(PatientProfile patient, Product product, ProductSource source) {
        this.patient = patient;
        this.product = product;
        this.source = source;
    }

    public enum ProductSource {
        PRESCRIBED,
        PATIENT_OWN
    }
}
