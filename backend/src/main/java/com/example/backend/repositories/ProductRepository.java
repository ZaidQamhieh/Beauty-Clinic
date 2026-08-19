package com.example.backend.repositories;

import com.example.backend.entities.Product;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface ProductRepository extends JpaRepository<Product, UUID> {

    // Mirrors UNIQUE (brand, product_type): a catalogue row is a brand plus a type.
    boolean existsByBrandAndProductType(Product.ProductBrand brand, Product.ProductType productType);
}
