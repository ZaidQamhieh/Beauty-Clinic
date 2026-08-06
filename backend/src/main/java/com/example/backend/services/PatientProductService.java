package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.dtos.AddPatientProductRequest;
import com.example.backend.dtos.PatientProductResponse;
import com.example.backend.entities.PatientProduct;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.Product;
import com.example.backend.repositories.PatientProductRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.ProductRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PatientProductService {

    private final PatientProductRepository patientProducts;
    private final PatientProfileRepository patients;
    private final ProductRepository products;
    private final ClinicProperties clinic;

    @Transactional(readOnly = true)
    public List<PatientProductResponse> list(UUID patientUserId) {
        return patientProducts.findByPatientUserId(patientUserId).stream()
                .map(PatientProductResponse::of)
                .toList();
    }

    @Transactional
    public PatientProductResponse add(UUID patientUserId, AddPatientProductRequest request) {
        PatientProfile patient = patients.findById(patientUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));
        Product product = products.findById(request.productId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such product"));

        PatientProduct patientProduct = new PatientProduct(patient, product, request.source());
        patientProduct.setStartedOn(request.startedOn());

        return PatientProductResponse.of(patientProducts.save(patientProduct));
    }

    @Transactional
    public PatientProductResponse discontinue(UUID patientUserId, UUID patientProductId) {
        PatientProduct patientProduct = patientProducts.findById(patientProductId)
                .filter(p -> p.getPatient().getUserId().equals(patientUserId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such product in this patient's routine"));

        patientProduct.setDiscontinuedOn(LocalDate.now(clinic.zone()));
        return PatientProductResponse.of(patientProduct);
    }
}
