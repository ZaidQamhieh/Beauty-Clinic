package com.example.backend.entities;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

// A catalogue row is a brand plus a type. No soft delete: history points here.
@Entity
@Table(name = "product")
@Getter
@Setter
@NoArgsConstructor
public class Product {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @NotNull
    @Column(nullable = false, length = 60)
    private String name;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 60)
    private ProductBrand brand;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(name = "product_type", nullable = false, length = 40)
    private ProductType productType;

    @Column(name = "image_url", length = 2048)
    private String imageUrl;

    @Column(name = "stock_quantity", nullable = false)
    private int stockQuantity;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(nullable = false, columnDefinition = "text[]")
    private List<Ingredient> ingredients = new ArrayList<>();

    public enum ProductBrand {
        CERAVE,
        LA_ROCHE_POSAY,
        SKINCEUTICALS,
        OBAGI,
        ZO_SKIN_HEALTH,
        BIODERMA,
        AVENE
    }

    public enum ProductType {
        CLEANSER,
        MOISTURIZER,
        SERUM,
        SUNSCREEN,
        TONER,
        EXFOLIANT,
        MASK,
        RETINOID
    }

    public enum Ingredient {
        RETINOL,
        NIACINAMIDE,
        SALICYLIC_ACID,
        HYALURONIC_ACID,
        VITAMIN_C,
        GLYCOLIC_ACID,
        BENZOYL_PEROXIDE,
        AZELAIC_ACID,
        CERAMIDES,
        ZINC_OXIDE
    }
}
