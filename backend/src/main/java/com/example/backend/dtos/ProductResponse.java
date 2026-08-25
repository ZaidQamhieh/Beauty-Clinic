package com.example.backend.dtos;

import com.example.backend.entities.Product;
import com.example.backend.entities.Product.Ingredient;
import com.example.backend.entities.Product.ProductBrand;
import com.example.backend.entities.Product.ProductType;

import java.util.List;
import java.util.UUID;

public record ProductResponse(
        UUID id,
        String name,
        ProductBrand brand,
        ProductType productType,
        String imageUrl,
        int stockQuantity,
        List<Ingredient> ingredients
) {
    public static ProductResponse of(Product product) {
        return new ProductResponse(
                product.getId(),
                product.getName(),
                product.getBrand(),
                product.getProductType(),
                product.getImageUrl(),
                product.getStockQuantity(),
                product.getIngredients()
        );
    }
}
