package com.example.backend.entities;

import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.MapsId;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Immutable;

import java.util.Objects;

// One clinical fact with its parent SessionRecord, held by trg_prescription_product_immutable.
@Entity
@Table(name = "prescription_product")
@Immutable
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PrescriptionProduct {

    @EmbeddedId
    private PrescriptionProductId id;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @MapsId("sessionRecordId")
    @JoinColumn(name = "session_record_id", nullable = false)
    private SessionRecord sessionRecord;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @MapsId("productId")
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    public PrescriptionProduct(SessionRecord sessionRecord, Product product) {
        this.sessionRecord = Objects.requireNonNull(sessionRecord);
        this.product = Objects.requireNonNull(product);
        this.id = new PrescriptionProductId(sessionRecord.getId(), product.getId());
    }
}
