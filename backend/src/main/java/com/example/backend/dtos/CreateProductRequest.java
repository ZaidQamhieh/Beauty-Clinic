package com.example.backend.dtos;

import com.example.backend.entities.Product.Ingredient;
import com.example.backend.entities.Product.ProductBrand;
import com.example.backend.entities.Product.ProductType;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public record CreateProductRequest(
        @NotNull ProductBrand brand,
        @NotNull ProductType productType,
        List<Ingredient> ingredients
) {
}
