package com.example.backend.controllers;

import com.example.backend.dtos.CreateProductRequest;
import com.example.backend.dtos.ProductResponse;
import com.example.backend.security.access.AdminOnly;
import com.example.backend.security.access.Authenticated;
import com.example.backend.services.ProductService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/products")
@RequiredArgsConstructor
public class ProductController {

    private final ProductService products;

    @GetMapping
    @Authenticated
    public List<ProductResponse> list() {
        return products.list();
    }

    @GetMapping("/{id}")
    @Authenticated
    public ProductResponse read(@PathVariable UUID id) {
        return products.read(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @AdminOnly
    public ProductResponse create(@Valid @RequestBody CreateProductRequest request) {
        return products.create(request);
    }

    @PutMapping("/{id}")
    @AdminOnly
    public ProductResponse update(
            @PathVariable UUID id,
            @Valid @RequestBody CreateProductRequest request
    ) {
        return products.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @AdminOnly
    public void delete(@PathVariable UUID id) {
        products.delete(id);
    }
}
