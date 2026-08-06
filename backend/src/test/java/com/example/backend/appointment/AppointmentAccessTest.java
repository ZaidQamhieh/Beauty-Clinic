package com.example.backend.appointment;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.DoctorAvailabilityRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
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

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneOffset;

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
    private DoctorProfileRepository doctors;

    @Autowired
    private PatientProfileRepository patients;

    @Autowired
    private DoctorAvailabilityRepository availabilities;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private DoctorProfile doctor;
    private PatientProfile patient;
    private String receptionToken;
    private String doctorToken;
    private String patientToken;
    private String otherPatientToken;
    private LocalDate day;
    private Instant slotStart;

    @BeforeEach
    void setUp() throws Exception {
        doctor = doctors.save(new DoctorProfile(account("doc@clinic.com", Role.DOCTOR)));

        patient = patients.save(new PatientProfile(account("patient@clinic.com", Role.PATIENT)));
        patients.save(new PatientProfile(account("other-patient@clinic.com", Role.PATIENT)));

        account("desk@clinic.com", Role.RECEPTIONIST);

        receptionToken = login("desk@clinic.com");
        doctorToken = login("doc@clinic.com");
        patientToken = login("patient@clinic.com");
        otherPatientToken = login("other-patient@clinic.com");

        // The test profile pins the clinic to UTC, so this is also the local slot.
        day = LocalDate.now(ZoneOffset.UTC).plusDays(1);
        slotStart = day.atTime(10, 0).atZone(ZoneOffset.UTC).toInstant();

        // Open every day so the tests never have to chase which weekday it is.
        for (DayOfWeek weekday : DayOfWeek.values()) {
            availabilities.save(new DoctorAvailability(
                    doctor, AvailabilityKind.RECURRING, weekday,
                    LocalTime.MIDNIGHT, LocalTime.of(23, 59), LocalDate.of(2020, 1, 1)
            ));
        }
    }

    @Test
    void aDoctorCanBookAnAppointment() throws Exception {
        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("BOOKED"));
    }

    @Test
    void receptionCannotBookAnAppointment() throws Exception {
        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + receptionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isForbidden());
    }

    @Test
    void aPatientBooksForThemselvesButNotForSomeoneElse() throws Exception {
        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + patientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + otherPatientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart.plusSeconds(3600))))
                .andExpect(status().isForbidden());
    }

    @Test
    void secondOverlappingBookingIsRejected() throws Exception {
        book(doctorToken, slotStart);

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isConflict());
    }

    // Every status but CANCELLED holds the slot, matching the exclusion constraint.
    @Test
    void bookingOverACompletedSessionIsRejected() throws Exception {
        String appointmentId = book(doctorToken, slotStart);
        String sessionId = firstSessionId(appointmentId);

        mockMvc.perform(put("/api/appointments/" + appointmentId + "/sessions/" + sessionId + "/attended")
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"));

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isConflict());
    }

    @Test
    void bookingOverACancelledAppointmentIsAllowed() throws Exception {
        String id = book(doctorToken, slotStart);

        mockMvc.perform(put("/api/appointments/" + id + "/cancel")
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isCreated());
    }

    @Test
    void bookingOutsideWorkingHoursIsRejected() throws Exception {
        availabilities.deleteAll(availabilities.findByDoctorUserId(doctor.getUserId()));

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isConflict());
    }

    @Test
    void workingHoursMatchTheBookedWeekday() throws Exception {
        availabilities.deleteAll(availabilities.findByDoctorUserId(doctor.getUserId()));
        DayOfWeek weekday = day.getDayOfWeek();

        availabilities.save(new DoctorAvailability(
                doctor, AvailabilityKind.RECURRING, weekday,
                LocalTime.of(9, 0), LocalTime.of(17, 0), LocalDate.of(2020, 1, 1)
        ));

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart)))
                .andExpect(status().isCreated());

        availabilities.deleteAll(availabilities.findByDoctorUserId(doctor.getUserId()));
        availabilities.save(new DoctorAvailability(
                doctor, AvailabilityKind.RECURRING, weekday.plus(1),
                LocalTime.of(9, 0), LocalTime.of(17, 0), LocalDate.of(2020, 1, 1)
        ));

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookRequest(slotStart.plusSeconds(3600))))
                .andExpect(status().isConflict());
    }

    @Test
    void patientReadsTheirOwnAppointmentButNotSomeoneElses() throws Exception {
        String id = book(doctorToken, slotStart);

        mockMvc.perform(get("/api/appointments/" + id)
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/appointments/" + id)
                        .header("Authorization", "Bearer " + otherPatientToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void onlyStaffCanCancelAnAppointment() throws Exception {
        String id = book(doctorToken, slotStart);

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
        String id = book(doctorToken, slotStart);

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

    // Works only because the cancel is flushed ahead of the replacement's insert.
    @Test
    void reschedulingIntoTheSlotItIsVacatingIsAllowed() throws Exception {
        String id = book(doctorToken, slotStart);

        String body = reschedule(id, slotStart.plusSeconds(900));
        String newId = JsonPath.read(body, "$.id");

        mockMvc.perform(get("/api/appointments/" + newId)
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("BOOKED"));
    }

    @Test
    void freeSlotsSkipTheBookedWindow() throws Exception {
        availabilities.deleteAll(availabilities.findByDoctorUserId(doctor.getUserId()));
        availabilities.save(new DoctorAvailability(
                doctor, AvailabilityKind.RECURRING, day.getDayOfWeek(),
                LocalTime.of(10, 0), LocalTime.of(11, 0), LocalDate.of(2020, 1, 1)
        ));

        book(doctorToken, slotStart);

        // 10:00-11:00 holds two 30-minute slots and the first is now taken.
        mockMvc.perform(get("/api/appointments/free-slots")
                        .header("Authorization", "Bearer " + receptionToken)
                        .param("doctorId", doctor.getUserId().toString())
                        .param("durationMinutes", "30")
                        .param("date", day.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].startTime").value(
                        slotStart.plusSeconds(1800).toString()
                ));
    }

    // Zero never advanced the slot cursor, so the scan looped until the thread died.
    @Test
    void freeSlotsRejectsANonPositiveDuration() throws Exception {
        mockMvc.perform(get("/api/appointments/free-slots")
                        .header("Authorization", "Bearer " + receptionToken)
                        .param("doctorId", doctor.getUserId().toString())
                        .param("durationMinutes", "0")
                        .param("date", day.toString()))
                .andExpect(status().isBadRequest());

        mockMvc.perform(get("/api/appointments/free-slots")
                        .header("Authorization", "Bearer " + receptionToken)
                        .param("doctorId", doctor.getUserId().toString())
                        .param("durationMinutes", "-30")
                        .param("date", day.toString()))
                .andExpect(status().isBadRequest());
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

    private String firstSessionId(String appointmentId) throws Exception {
        String body = mockMvc.perform(get("/api/appointments/" + appointmentId)
                        .header("Authorization", "Bearer " + receptionToken))
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(body, "$.sessions[0].id");
    }

    private String bookRequest(Instant startTime) {
        return """
                {
                  "patientUserId": "%s",
                  "session": {
                    "practitionerUserId": "%s",
                    "category": "FACIAL",
                    "treatmentName": "HYDRAFACIAL",
                    "priceCharged": 50.00,
                    "durationMinutes": 30,
                    "startTime": "%s"
                  }
                }
                """.formatted(patient.getUserId(), doctor.getUserId(), startTime);
    }

    private UserAccount account(String email, Role role) {
        return users.save(new UserAccount(email, passwordEncoder.encode("password"), "Test", "User", role));
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
