package com.example.backend.appointment;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.doctor.WorkingHours;
import com.example.backend.entities.ClinicService;
import com.example.backend.entities.Doctor;
import com.example.backend.entities.Patient;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.ClinicServiceRepository;
import com.example.backend.repositories.DoctorRepository;
import com.example.backend.repositories.PatientRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.stream.IntStream;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AppointmentAccessTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private DoctorRepository doctors;

    @Autowired
    private PatientRepository patients;

    @Autowired
    private ClinicServiceRepository services;

    @Autowired
    private AppointmentRepository appointments;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private Doctor doctor;
    private ClinicService service;
    private Patient patient;
    private String receptionToken;
    private String doctorToken;
    private String patientToken;
    private String otherPatientToken;
    private LocalDate day;
    private Instant slotStart;

    @BeforeEach
    void setUp() throws Exception {
        service = services.save(new ClinicService("Facial", 30, new BigDecimal("50.00")));

        doctor = doctors.save(new Doctor(account("doc@clinic.com", Role.DOCTOR)));
        // Open every day so the tests never have to chase which weekday it is.
        doctor.setAvailability(IntStream.range(0, 7)
                .mapToObj(d -> new WorkingHours((short) d, LocalTime.MIDNIGHT, LocalTime.of(23, 59)))
                .toList());
        doctor.setServices(new LinkedHashSet<>(List.of(service)));
        doctors.save(doctor);

        patient = new Patient("Amal", "Nasser");
        patient.setUser(account("patient@clinic.com", Role.PATIENT));
        patients.save(patient);

        Patient otherPatient = new Patient("Rana", "Haddad");
        otherPatient.setUser(account("other-patient@clinic.com", Role.PATIENT));
        patients.save(otherPatient);

        account("desk@clinic.com", Role.RECEPTIONIST);

        receptionToken = login("desk@clinic.com");
        doctorToken = login("doc@clinic.com");
        patientToken = login("patient@clinic.com");
        otherPatientToken = login("other-patient@clinic.com");

        // The test profile pins the clinic to UTC, so this is also the local slot.
        day = LocalDate.now(ZoneOffset.UTC).plusDays(1);
        slotStart = day.atTime(10, 0).atZone(ZoneOffset.UTC).toInstant();
    }

    @Test
    void staffCanBookAnAppointment() throws Exception {
        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + receptionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("BOOKED"));
    }

    @Test
    void patientCannotBookAnAppointment() throws Exception {
        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + patientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isForbidden());
    }

    @Test
    void secondOverlappingBookingIsRejected() throws Exception {
        book(receptionToken, slotStart);

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isConflict());
    }

    // The slot is held by every status except CANCELLED, matching the database's
    // exclusion constraint - checking only BOOKED would pass here and then fail
    // on the constraint as a 500.
    @Test
    void bookingOverACompletedAppointmentIsRejected() throws Exception {
        String id = book(receptionToken, slotStart);

        mockMvc.perform(put("/api/appointments/" + id + "/attended")
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"));

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + receptionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isConflict());
    }

    @Test
    void bookingOverACancelledAppointmentIsAllowed() throws Exception {
        String id = book(receptionToken, slotStart);

        mockMvc.perform(put("/api/appointments/" + id + "/cancel")
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + receptionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isCreated());
    }

    @Test
    void bookingOutsideWorkingHoursIsRejected() throws Exception {
        doctor.setAvailability(List.of());
        doctors.save(doctor);

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + receptionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isConflict());
    }

    // dayOfWeek is Sunday=0..Saturday=6, so the only window left open has to be
    // the one matching the booked date or the booking is refused.
    @Test
    void workingHoursMatchTheSundayZeroWeekdayConvention() throws Exception {
        short weekday = (short) (day.getDayOfWeek().getValue() % 7);

        doctor.setAvailability(List.of(
                new WorkingHours(weekday, LocalTime.of(9, 0), LocalTime.of(17, 0))
        ));
        doctors.save(doctor);

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + receptionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isCreated());

        doctor.setAvailability(List.of(
                new WorkingHours((short) ((weekday + 1) % 7), LocalTime.of(9, 0), LocalTime.of(17, 0))
        ));
        doctors.save(doctor);

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + receptionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart.plusSeconds(3600))))
                .andExpect(status().isConflict());
    }

    @Test
    void bookingAServiceTheDoctorDoesNotOfferIsRejected() throws Exception {
        ClinicService other = services.save(new ClinicService("Peel", 30, new BigDecimal("70.00")));

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + receptionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart, other.getId().toString())))
                .andExpect(status().isConflict());
    }

    @Test
    void bookingAnInactiveServiceIsRejected() throws Exception {
        service.setActive(false);
        services.save(service);

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + receptionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isConflict());
    }

    @Test
    void patientReadsTheirOwnAppointmentButNotSomeoneElses() throws Exception {
        String id = book(receptionToken, slotStart);

        mockMvc.perform(get("/api/appointments/" + id)
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/appointments/" + id)
                        .header("Authorization", "Bearer " + otherPatientToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void onlyStaffCanCancelAnAppointment() throws Exception {
        String id = book(receptionToken, slotStart);

        mockMvc.perform(put("/api/appointments/" + id + "/cancel")
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(put("/api/appointments/" + id + "/cancel")
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
    }

    @Test
    void reschedulingReplacesTheOriginalBooking() throws Exception {
        String id = book(receptionToken, slotStart);

        String body = reschedule(id, slotStart.plusSeconds(3600));
        String newId = JsonPath.read(body, "$.id");

        mockMvc.perform(get("/api/appointments/" + id)
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));

        mockMvc.perform(get("/api/appointments/" + newId)
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("BOOKED"));
    }

    // Moving a booking forward by a few minutes overlaps the slot it is vacating.
    // That only works because the cancel is flushed ahead of the replacement's
    // insert; without it the exclusion constraint rejects the new row.
    @Test
    void reschedulingIntoTheSlotItIsVacatingIsAllowed() throws Exception {
        String id = book(receptionToken, slotStart);

        String body = reschedule(id, slotStart.plusSeconds(900));
        String newId = JsonPath.read(body, "$.id");

        mockMvc.perform(get("/api/appointments/" + newId)
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("BOOKED"));
    }

    @Test
    void freeSlotsSkipTheBookedWindow() throws Exception {
        doctor.setAvailability(List.of(
                new WorkingHours((short) (day.getDayOfWeek().getValue() % 7),
                        LocalTime.of(10, 0), LocalTime.of(11, 0))
        ));
        doctors.save(doctor);

        book(receptionToken, slotStart);

        // 10:00-11:00 holds two 30-minute slots and the first is now taken.
        mockMvc.perform(get("/api/appointments/free-slots")
                        .header("Authorization", "Bearer " + receptionToken)
                        .param("doctorId", doctor.getUserId().toString())
                        .param("serviceId", service.getId().toString())
                        .param("date", day.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].startTime").value(
                        slotStart.plusSeconds(1800).toString()
                ));
    }

    private String reschedule(String id, Instant newStart) throws Exception {
        return mockMvc.perform(put("/api/appointments/" + id + "/reschedule")
                        .header("Authorization", "Bearer " + receptionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startTime\": \"" + newStart + "\"}"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
    }

    private String book(String asToken, Instant startTime) throws Exception {
        String body = mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + asToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(startTime)))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(body, "$.id");
    }

    private String bookRequest(Instant startTime) {
        return bookRequest(startTime, service.getId().toString());
    }

    private String bookRequest(Instant startTime, String serviceId) {
        return """
                {
                  "patientId": "%s",
                  "doctorId": "%s",
                  "serviceId": "%s",
                  "startTime": "%s",
                  "reason": "Checkup"
                }
                """.formatted(patient.getId(), doctor.getUserId(), serviceId, startTime);
    }

    private UserAccount account(String email, Role role) {
        return users.save(new UserAccount(email, passwordEncoder.encode("password"), "Test User", role));
    }

    private String login(String email) throws Exception {
        String body = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email": "%s", "password": "password"}
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(body, "$.accessToken");
    }
}
