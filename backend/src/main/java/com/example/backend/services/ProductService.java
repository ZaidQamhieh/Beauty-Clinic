package com.example.backend.services;

import com.example.backend.dtos.CreateProductRequest;
import com.example.backend.dtos.ProductResponse;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.Product;
import com.example.backend.repositories.ProductRepository;
import com.example.backend.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ProductService {

    private final ProductRepository products;
    private final ActivityLogService activityLogs;
    private final CurrentUser currentUser;

    @Transactional(readOnly = true)
    public List<ProductResponse> list() {
        return products.findAll().stream().map(ProductResponse::of).toList();
    }

    @Transactional(readOnly = true)
    public ProductResponse read(UUID id) {
        return ProductResponse.of(find(id));
    }

    @Transactional
    public ProductResponse create(CreateProductRequest request) {
        // Named here; the index cannot say which.
        if (products.existsByBrandAndProductType(request.brand(), request.productType())) {
            throw duplicateProduct();
        }

        Product product = new Product();
        apply(product, request);
        Product saved = products.save(product);

        activityLogs.record(
                actor(), null, ActivityAction.PRODUCT_CREATED, "product", saved.getId());

        return ProductResponse.of(saved);
    }

    @Transactional
    public ProductResponse update(UUID id, CreateProductRequest request) {
        Product product = find(id);
        boolean pairChanged = product.getBrand() != request.brand()
                || product.getProductType() != request.productType();
        if (pairChanged && products.existsByBrandAndProductType(request.brand(), request.productType())) {
            throw duplicateProduct();
        }

        apply(product, request);

        activityLogs.record(
                actor(), null, ActivityAction.PRODUCT_UPDATED, "product", id);

        return ProductResponse.of(products.save(product));
    }

    @Transactional
    public void delete(UUID id) {
        products.delete(find(id));
        products.flush();

        activityLogs.record(
                actor(), null, ActivityAction.PRODUCT_DELETED, "product", id);
    }

    private UUID actor() {
        return currentUser.id().orElse(null);
    }

    private Product find(UUID id) {
        return products.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such product"));
    }

    private void apply(Product product, CreateProductRequest request) {
        product.setBrand(request.brand());
        product.setProductType(request.productType());
        product.setCategory(request.category().trim());
        product.setStockQuantity(request.stockQuantity());
        // CHECK tests containment, so duplicates store.
        product.setIngredients(request.ingredients() == null
                ? new ArrayList<>()
                : request.ingredients().stream().distinct()
                        .collect(Collectors.toCollection(ArrayList::new)));
    }

    private ResponseStatusException duplicateProduct() {
        return new ResponseStatusException(
                HttpStatus.CONFLICT, "That brand and product type is already in the catalogue");
    }
}
