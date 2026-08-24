package com.example.backend.services;

import com.example.backend.dtos.AmendSessionRecordRequest;
import com.example.backend.dtos.CreateSessionRecordRequest;
import com.example.backend.dtos.SessionRecordResponse;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PrescriptionProduct;
import com.example.backend.entities.Product;
import com.example.backend.entities.SessionRecord;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PrescriptionProductRepository;
import com.example.backend.repositories.ProductRepository;
import com.example.backend.repositories.SessionRecordRepository;
import com.example.backend.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
@RequiredArgsConstructor
public class SessionRecordService {

    private final SessionRecordRepository records;
    private final AppointmentSessionRepository sessions;
    private final DoctorProfileRepository doctors;
    private final ProductRepository products;
    private final PrescriptionProductRepository prescriptions;
    private final CurrentUser currentUser;
    private final ActivityLogService activityLogs;
    // Jackson 2 kept for Hibernate JsonNode.
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Transactional(readOnly = true)
    public Page<SessionRecordResponse> list(UUID patientUserId, Pageable pageable) {
        activityLogs.recordIndependently(
                currentUser.id().orElse(null), patientUserId,
                ActivityAction.SESSION_RECORDS_VIEWED, "session_record", null);

        return records.findBySessionAppointmentPatientUserIdOrderByCreatedAtDesc(patientUserId, pageable)
                .map(record -> SessionRecordResponse.of(record, prescribedProductIds(record)));
    }

    @Transactional(readOnly = true)
    public List<Product> prescribedProducts(UUID patientUserId) {
        return prescriptions.findForPatient(patientUserId).stream()
                .map(PrescriptionProduct::getProduct)
                .distinct()
                .toList();
    }

    @Transactional
    public SessionRecordResponse create(UUID patientUserId, CreateSessionRecordRequest request) {
        AppointmentSession session = requireSessionOf(patientUserId, request.sessionId());
        DoctorProfile author = requireAuthor();

        SessionRecord record = records.save(SessionRecord.initial(
                session, author, request.note(), request.skinReaction(), request.followUpDate()
        ));

        List<UUID> prescribedIds = prescribe(record, request.prescribedProductIds());

        activityLogs.record(
                author.getUserId(), patientUserId, ActivityAction.SESSION_RECORD_CREATED,
                "session_record", record.getId(), null, prescribed(prescribedIds));

        return SessionRecordResponse.of(record, prescribedIds);
    }

    @Transactional
    public SessionRecordResponse amend(UUID patientUserId, UUID recordId, AmendSessionRecordRequest request) {
        SessionRecord original = records.findById(recordId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such session record"));

        if (!original.getSession().getAppointment().getPatient().getUserId().equals(patientUserId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No such session record for this patient");
        }

        // Amended once, so the chain stays linear.
        if (records.existsByAmendsId(original.getId())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "That record has already been amended; amend the correction instead");
        }

        DoctorProfile author = requireAuthor();

        SessionRecord correction = records.save(original.amendedWith(
                author, request.note(), request.skinReaction(), request.followUpDate()
        ));

        List<UUID> prescribedIds = prescribe(correction, request.prescribedProductIds());

        activityLogs.record(
                author.getUserId(), patientUserId, ActivityAction.SESSION_RECORD_AMENDED,
                "session_record", correction.getId(),
                objectMapper.valueToTree(Map.of("amendsRecordId", original.getId().toString())),
                prescribed(prescribedIds));

        return SessionRecordResponse.of(correction, prescribedIds);
    }

    // Ids only; the note stays out.
    private JsonNode prescribed(List<UUID> prescribedIds) {
        if (prescribedIds.isEmpty()) {
            return null;
        }

        return objectMapper.valueToTree(Map.of(
                "prescribedProductIds", prescribedIds.stream().map(UUID::toString).toList()));
    }

    private List<UUID> prescribe(SessionRecord record, List<UUID> requestedIds) {
        if (requestedIds == null || requestedIds.isEmpty()) {
            return List.of();
        }

        // Deduped: a repeat would read as missing.
        List<UUID> productIds = requestedIds.stream().distinct().toList();

        List<Product> found = products.findAllById(productIds);
        if (found.size() != productIds.size()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "One or more products do not exist");
        }

        found.forEach(product -> prescriptions.save(new PrescriptionProduct(record, product)));

        return found.stream().map(Product::getId).toList();
    }

    private List<UUID> prescribedProductIds(SessionRecord record) {
        return prescriptions.findBySessionRecordId(record.getId()).stream()
                .map(link -> link.getProduct().getId())
                .toList();
    }

    private AppointmentSession requireSessionOf(UUID patientUserId, UUID sessionId) {
        AppointmentSession session = sessions.findById(sessionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such session"));

        if (!session.getAppointment().getPatient().getUserId().equals(patientUserId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No such session for this patient");
        }

        if (currentUser.hasRole(com.example.backend.security.Role.DOCTOR)
                && !session.getPractitioner().getUserId().equals(currentUser.requireId())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Doctors may only record their assigned sessions");
        }

        // Permanent once written, so describe done work.
        if (session.getStatus() != SessionStatus.COMPLETED) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "A clinical record can only be written for a treatment marked as carried out");
        }

        return session;
    }

    private DoctorProfile requireAuthor() {
        return doctors.findById(currentUser.requireId())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.CONFLICT, "Only a doctor can author a session record"
                ));
    }
}
