package com.example.backend.controllers;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentCategory;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.Product;
import com.example.backend.entities.Product.Ingredient;
import com.example.backend.entities.Product.ProductBrand;
import com.example.backend.entities.Product.ProductType;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.ProductRepository;
import com.example.backend.repositories.SessionRecordRepository;
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

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SessionRecordControllerTest extends AbstractIntegrationTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private UserAccountRepository users;

	@Autowired
	private PatientProfileRepository patients;

	@Autowired
	private DoctorProfileRepository doctors;

	@Autowired
	private AppointmentRepository appointments;

	@Autowired
	private AppointmentSessionRepository sessions;

	@Autowired
	private ProductRepository products;

	@Autowired
	private SessionRecordRepository records;

	@Autowired
	private PasswordEncoder passwordEncoder;

	private static final AtomicInteger counter = new AtomicInteger(0);
	private UUID patientId;
	private String doctorToken;
	private UUID sessionId;
	private UUID productId;
	private DoctorProfile doctorProfile;
	private int testId;

	@BeforeEach
	void setUp() throws Exception {
		testId = counter.incrementAndGet();
		// Create patient
		UserAccount patientUser = new UserAccount(
			"srtest.patient" + testId + "@test.com",
			passwordEncoder.encode("password"),
			"John", "Doe",
			Role.PATIENT
		);
		patientUser = users.save(patientUser);
		patientId = patientUser.getId();

		PatientProfile patientProfile = new PatientProfile(patientUser);
		patients.save(patientProfile);

		// Create doctor and get token
		UserAccount doctorUser = new UserAccount(
			"srtest.doctor" + testId + "@test.com",
			passwordEncoder.encode("password"),
			"Dr. Jane", "Smith",
			Role.DOCTOR
		);
		doctorUser = users.save(doctorUser);

		doctorProfile = new DoctorProfile(doctorUser);
		doctors.save(doctorProfile);

		doctorToken = login("srtest.doctor" + testId + "@test.com");

		// Create appointment
		Instant appointmentTime = Instant.now().plusSeconds(3600);
		Appointment apt = new Appointment(patientProfile, appointmentTime);
		apt = appointments.save(apt);

		// Create session (COMPLETED status for record writing)
		AppointmentSession session = new AppointmentSession(
			apt, doctorProfile,
			TreatmentCategory.FACIAL,
			TreatmentName.CHEMICAL_PEEL,
			new BigDecimal("150.00"), 30,
			Instant.now().plusSeconds(3600),
			Instant.now().plusSeconds(5400)
		);
		session.setStatus(SessionStatus.COMPLETED);
		session = sessions.save(session);
		sessionId = session.getId();

		// Brand and type are unique together, so claim a free pair.
		Product product = new Product();
		product.setName("Test Product " + testId);
		boolean claimed = false;
		for (ProductBrand brand : ProductBrand.values()) {
			for (ProductType type : ProductType.values()) {
				if (!products.existsByBrandAndProductType(brand, type)) {
					product.setBrand(brand);
					product.setProductType(type);
					claimed = true;
					break;
				}
			}
			if (claimed) {
				break;
			}
		}
		product.setIngredients(List.of(Ingredient.RETINOL));
		product.setStockQuantity(10);
		product = products.save(product);
		productId = product.getId();
	}

	private String login(String email) throws Exception {
		String body = mockMvc.perform(post("/api/auth/login")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"email": "%s",
							"password": "password"
						}
						""".formatted(email)))
			.andExpect(status().isOk())
			.andReturn().getResponse().getContentAsString();
		return JsonPath.read(body, "$.accessToken");
	}

	@Test
	void doctorCanCreateSessionRecord() throws Exception {
		mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "Patient responded well",
							"skinReaction": "NONE",
							"followUpDate": "%s",
							"prescribedProductIds": ["%s"]
						}
						""".formatted(sessionId, LocalDate.now().plusDays(7), productId)))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.id").exists())
			.andExpect(jsonPath("$.note").value("Patient responded well"));
	}

	@Test
	void patientCannotCreateSessionRecord() throws Exception {
		mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "Test",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						""".formatted(sessionId)))
			.andExpect(status().isUnauthorized());
	}

	@Test
	void rejectCreateWithInvalidSessionId() throws Exception {
		mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "Test",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						""".formatted(UUID.randomUUID())))
			.andExpect(status().isNotFound());
	}

	@Test
	void rejectCreateWithMissingSessionId() throws Exception {
		mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"note": "Test",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						"""))
			.andExpect(status().isBadRequest());
	}

	@Test
	void rejectCreateWithOverlongNote() throws Exception {
		String longNote = "x".repeat(4001);
		mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "%s",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						""".formatted(sessionId, longNote)))
			.andExpect(status().isBadRequest());
	}

	@Test
	void rejectCreateWithNonexistentProduct() throws Exception {
		mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "Test",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": ["%s"]
						}
						""".formatted(sessionId, UUID.randomUUID())))
			.andExpect(status().isNotFound());
	}

	@Test
	void doctorCannotCreateRecordForAnothersDoctorSession() throws Exception {
		// Create another doctor
		int i = testId + 100;
		UserAccount otherDoctor = new UserAccount(
			"srtest.other" + i + "@test.com",
			passwordEncoder.encode("password"),
			"Dr. Other", "Person",
			Role.DOCTOR
		);
		otherDoctor = users.save(otherDoctor);
		DoctorProfile otherProfile = new DoctorProfile(otherDoctor);
		doctors.save(otherProfile);
		String otherToken = login("srtest.other" + i + "@test.com");

		// Other doctor cannot record for this session
		mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + otherToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "Test",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						""".formatted(sessionId)))
			.andExpect(status().isForbidden());
	}

	@Test
	void doctorCanAmendSessionRecord() throws Exception {
		// Create initial record
		String createResponse = mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "Initial note",
							"skinReaction": "NONE",
							"followUpDate": null,
							"prescribedProductIds": []
						}
						""".formatted(sessionId)))
			.andExpect(status().isCreated())
			.andReturn().getResponse().getContentAsString();

		String recordId = JsonPath.read(createResponse, "$.id");

		// Amend the record
		mockMvc.perform(put("/api/patients/{id}/session-records/{recordId}/amend", patientId, recordId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"note": "Amended note",
							"skinReaction": "MILD",
							"followUpDate": "%s",
							"prescribedProductIds": ["%s"]
						}
						""".formatted(LocalDate.now().plusDays(3), productId)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.note").value("Amended note"));
	}

	@Test
	void rejectAmendWithDoubleAmend() throws Exception {
		// Create initial record
		String createResponse = mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "Initial",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						""".formatted(sessionId)))
			.andExpect(status().isCreated())
			.andReturn().getResponse().getContentAsString();

		String recordId = JsonPath.read(createResponse, "$.id");

		// First amendment
		mockMvc.perform(put("/api/patients/{id}/session-records/{recordId}/amend", patientId, recordId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"note": "First amend",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						"""))
			.andExpect(status().isOk());

		// Second amendment should fail
		mockMvc.perform(put("/api/patients/{id}/session-records/{recordId}/amend", patientId, recordId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"note": "Second amend",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						"""))
			.andExpect(status().isConflict());
	}

	@Test
	void patientCannotAmendSessionRecord() throws Exception {
		mockMvc.perform(put("/api/patients/{id}/session-records/{recordId}/amend", patientId, UUID.randomUUID())
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"note": "Test",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						"""))
			.andExpect(status().isUnauthorized());
	}

	@Test
	void doctorCanListSessionRecords() throws Exception {
		// Create a record first
		mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "Test record",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						""".formatted(sessionId)))
			.andExpect(status().isCreated());

		// List records
		mockMvc.perform(get("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.param("page", "0")
				.param("size", "10"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.content").isArray());
	}

	@Test
	void patientCannotListSessionRecords() throws Exception {
		mockMvc.perform(get("/api/patients/{id}/session-records", patientId))
			.andExpect(status().isUnauthorized());
	}

	@Test
	void doctorCanViewPrescribedProducts() throws Exception {
		// Create record with prescribed product
		mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "Test",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": ["%s"]
						}
						""".formatted(sessionId, productId)))
			.andExpect(status().isCreated());

		// View prescribed products
		mockMvc.perform(get("/api/patients/{id}/session-records/prescribed-products", patientId)
				.header("Authorization", "Bearer " + doctorToken))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$").isArray());
	}

	@Test
	void patientCannotViewPrescribedProducts() throws Exception {
		mockMvc.perform(get("/api/patients/{id}/session-records/prescribed-products", patientId))
			.andExpect(status().isUnauthorized());
	}

	@Test
	void rejectCreateForNonCompletedSession() throws Exception {
		// Create a non-completed session
		Instant appointmentTime = Instant.now().plusSeconds(7200);
		PatientProfile patientProfile = patients.findById(patientId).get();
		Appointment apt = new Appointment(patientProfile, appointmentTime);
		apt = appointments.save(apt);

		AppointmentSession session = new AppointmentSession(
			apt, doctorProfile,
			TreatmentCategory.FACIAL,
			TreatmentName.CHEMICAL_PEEL,
			new BigDecimal("150.00"), 30,
			Instant.now().plusSeconds(7200),
			Instant.now().plusSeconds(9000)
		);
		session.setStatus(SessionStatus.PLANNED);
		session = sessions.save(session);

		mockMvc.perform(post("/api/patients/{id}/session-records", patientId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{
							"sessionId": "%s",
							"note": "Test",
							"skinReaction": null,
							"followUpDate": null,
							"prescribedProductIds": []
						}
						""".formatted(session.getId())))
			.andExpect(status().isConflict());
	}
}
