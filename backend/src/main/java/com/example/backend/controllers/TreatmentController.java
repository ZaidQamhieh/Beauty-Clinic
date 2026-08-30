package com.example.backend.controllers;

import com.example.backend.dtos.BookingRulesResponse;
import com.example.backend.dtos.TreatmentResponse;
import com.example.backend.security.access.Authenticated;
import com.example.backend.services.TreatmentCatalogService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

// What can be booked, and the rules.
@RestController
@RequestMapping("/api/treatments")
@RequiredArgsConstructor
public class TreatmentController {

    private final TreatmentCatalogService treatments;

    // The landing page reads the treatment names before sign-in.
    @GetMapping
    public List<TreatmentResponse> list() {
        return treatments.list();
    }

    @GetMapping("/rules")
    @Authenticated
    public BookingRulesResponse rules() {
        return treatments.rules();
    }
}
