package com.example.backend.entities;

import jakarta.persistence.Embeddable;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

@Embeddable
public class PrescriptionProductId implements Serializable {

    private UUID sessionRecordId;
    private UUID productId;

    protected PrescriptionProductId() {
    }

    public PrescriptionProductId(UUID sessionRecordId, UUID productId) {
        this.sessionRecordId = sessionRecordId;
        this.productId = productId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof PrescriptionProductId that)) return false;
        return Objects.equals(sessionRecordId, that.sessionRecordId)
                && Objects.equals(productId, that.productId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(sessionRecordId, productId);
    }
}
