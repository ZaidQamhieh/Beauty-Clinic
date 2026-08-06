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
        Product product = new Product(request.brand(), request.productType());
        if (request.ingredients() != null) {
            product.setIngredients(new ArrayList<>(request.ingredients()));
        }
        return ProductResponse.of(products.save(product));
    }

    @Transactional(readOnly = true)
    public ProductResponse read(UUID id) {
        return ProductResponse.of(products.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such product")));
    }
}
