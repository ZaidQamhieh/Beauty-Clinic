package com.example.backend.services;

import com.example.backend.dtos.AmendSessionRecordRequest;
import com.example.backend.dtos.CreateSessionRecordRequest;
import com.example.backend.dtos.SessionRecordResponse;
import com.example.backend.entities.AppointmentSession;
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
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SessionRecordService {

    private final SessionRecordRepository records;
    private final AppointmentSessionRepository sessions;
    private final DoctorProfileRepository doctors;
    private final ProductRepository products;
    private final PrescriptionProductRepository prescriptions;
    private final CurrentUser currentUser;

    @Transactional(readOnly = true)
    public List<SessionRecordResponse> list(UUID patientUserId) {
        return records.findBySessionAppointmentPatientUserIdOrderByCreatedAtDesc(patientUserId).stream()
                .map(record -> SessionRecordResponse.of(record, prescribedProductIds(record)))
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

        return SessionRecordResponse.of(record, prescribedIds);
    }

    @Transactional
    public SessionRecordResponse amend(UUID patientUserId, UUID recordId, AmendSessionRecordRequest request) {
        SessionRecord original = records.findById(recordId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such session record"));

        if (!original.getSession().getAppointment().getPatient().getUserId().equals(patientUserId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No such session record for this patient");
        }

        DoctorProfile author = requireAuthor();

        SessionRecord correction = records.save(original.amendedWith(
                author, request.note(), request.skinReaction(), request.followUpDate()
        ));

        List<UUID> prescribedIds = prescribe(correction, request.prescribedProductIds());

        return SessionRecordResponse.of(correction, prescribedIds);
    }

    private List<UUID> prescribe(SessionRecord record, List<UUID> productIds) {
        if (productIds == null || productIds.isEmpty()) {
            return List.of();
        }

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

        return session;
    }

    private DoctorProfile requireAuthor() {
        return doctors.findById(currentUser.requireId())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.CONFLICT, "Only a doctor can author a session record"
                ));
    }
}
