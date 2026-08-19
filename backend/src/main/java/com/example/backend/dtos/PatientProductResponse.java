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
        ProductBrand brand,
        ProductType productType,
        ProductSource source,
        LocalDate startedOn,
        LocalDate discontinuedOn
) {
    public static PatientProductResponse of(PatientProduct patientProduct) {
        var product = patientProduct.getProduct();
        return new PatientProductResponse(
                patientProduct.getId(),
                product.getId(),
                product.getBrand(),
                product.getProductType(),
                patientProduct.getSource(),
                patientProduct.getStartedOn(),
                patientProduct.getDiscontinuedOn()
        );
    }
}
