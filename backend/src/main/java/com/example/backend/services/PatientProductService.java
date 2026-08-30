package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.dtos.AddPatientProductRequest;
import com.example.backend.dtos.PatientProductResponse;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.PatientProduct;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.Product;
import com.example.backend.entities.PatientProduct.ProductSource;
import com.example.backend.repositories.PatientProductRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.ProductRepository;
import com.example.backend.security.CurrentUser;
import com.example.backend.security.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PatientProductService {

    private final PatientProductRepository patientProducts;
    private final PatientProfileRepository patients;
    private final ProductRepository products;
    private final ClinicProperties clinic;
    private final ActivityLogService activityLogs;
    private final CurrentUser currentUser;

    @Cacheable(value = "patientData", key = "'products:' + #patientUserId")
    @Transactional(readOnly = true)
    public List<PatientProductResponse> list(UUID patientUserId) {
        return patientProducts.findByPatientUserId(patientUserId).stream()
                .map(PatientProductResponse::of)
                .collect(Collectors.toCollection(ArrayList::new));
    }

    @CacheEvict(value = "patientData", allEntries = true)
    @Transactional
    public PatientProductResponse add(UUID patientUserId, AddPatientProductRequest request) {
        if (currentUser.hasRole(Role.PATIENT)
                && request.source() != ProductSource.PATIENT_OWN) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Patients may only add products they own");
        }
        PatientProfile patient = patients.findById(patientUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));
        Product product = products.findById(request.productId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such product"));

        if (patientProducts.existsByPatientUserIdAndProductIdAndDiscontinuedOnIsNull(
                patientUserId, request.productId())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "This product is already in this patient's current routine");
        }

        UUID actorId = currentUser.requireId();
        PatientProduct patientProduct = new PatientProduct(patient, product, request.source(), actorId);
        patientProduct.setStartedOn(request.startedOn());

        PatientProduct saved = patientProducts.save(patientProduct);

        activityLogs.record(
                actorId, patientUserId, ActivityAction.PATIENT_PRODUCT_ADDED,
                "patient_product", saved.getId());

        return PatientProductResponse.of(saved);
    }

    @CacheEvict(value = "patientData", allEntries = true)
    @Transactional
    public PatientProductResponse discontinue(UUID patientUserId, UUID patientProductId) {
        PatientProduct patientProduct = patientProducts.findById(patientProductId)
                .filter(p -> p.getPatient().getUserId().equals(patientUserId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such product in this patient's routine"));

        UUID actorId = currentUser.id().orElse(null);
        patientProduct.setDiscontinuedOn(LocalDate.now(clinic.zone()));
        patientProduct.setDiscontinuedByUserId(actorId);

        activityLogs.record(
                actorId, patientUserId,
                ActivityAction.PATIENT_PRODUCT_DISCONTINUED,
                "patient_product", patientProductId);

        return PatientProductResponse.of(patientProduct);
    }
}
