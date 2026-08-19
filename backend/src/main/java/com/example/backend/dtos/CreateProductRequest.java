package com.example.backend.dtos;

import com.example.backend.entities.Product.Ingredient;
import com.example.backend.entities.Product.ProductBrand;
import com.example.backend.entities.Product.ProductType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.List;

public record CreateProductRequest(
        @NotNull ProductBrand brand,
        @NotNull ProductType productType,
        @NotBlank @Size(max = 60) String category,
        @NotNull @PositiveOrZero Integer stockQuantity,
        @Size(max = 20) List<Ingredient> ingredients
) {
}
