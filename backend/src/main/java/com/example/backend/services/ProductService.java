package com.example.backend.services;

import com.example.backend.dtos.CreateProductRequest;
import com.example.backend.dtos.ProductResponse;
import com.example.backend.entities.Product;
import com.example.backend.repositories.ProductRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.stream.Collectors;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ProductService {

    private final ProductRepository products;

    @Transactional(readOnly = true)
    public List<ProductResponse> list() {
        return products.findAll().stream().map(ProductResponse::of).toList();
    }

    @Transactional
    public ProductResponse create(CreateProductRequest request) {
        // Named here rather than left to the unique index, which cannot say which pair clashed.
        if (products.existsByBrandAndProductType(request.brand(), request.productType())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "That brand and product type is already in the catalogue");
        }

        Product product = new Product(request.brand(), request.productType());
        if (request.ingredients() != null) {
            // The column CHECK tests containment, not distinctness, so duplicates store.
            product.setIngredients(
                    request.ingredients().stream().distinct()
                            .collect(Collectors.toCollection(ArrayList::new)));
        }
        return ProductResponse.of(products.save(product));
    }

    @Transactional(readOnly = true)
    public ProductResponse read(UUID id) {
        return ProductResponse.of(products.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such product")));
    }
}
