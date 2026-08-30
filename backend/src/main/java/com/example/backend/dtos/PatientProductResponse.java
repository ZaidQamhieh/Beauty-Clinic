package com.example.backend.dtos;

import com.example.backend.entities.PatientProduct;
import com.example.backend.entities.Product.ProductBrand;
import com.example.backend.entities.PatientProduct.ProductSource;
import com.example.backend.entities.Product.ProductType;

import java.time.LocalDate;
import java.util.UUID;

public record PatientProductResponse(
        UUID id,
        UUID productId,
        String name,
        ProductBrand brand,
        ProductType productType,
        ProductSource source,
        LocalDate startedOn,
        LocalDate discontinuedOn,
        UUID addedByUserId,
        UUID discontinuedByUserId
) {
    public static PatientProductResponse of(PatientProduct patientProduct) {
        var product = patientProduct.getProduct();
        return new PatientProductResponse(
                patientProduct.getId(),
                product.getId(),
                product.getName(),
                product.getBrand(),
                product.getProductType(),
                patientProduct.getSource(),
                patientProduct.getStartedOn(),
                patientProduct.getDiscontinuedOn(),
                patientProduct.getAddedByUserId(),
                patientProduct.getDiscontinuedByUserId()
        );
    }
}
