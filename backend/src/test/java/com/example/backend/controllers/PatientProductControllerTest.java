package com.example.backend.controllers;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.PatientProduct.ProductSource;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.AppointmentSession;
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
import com.example.backend.repositories.PatientProductRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.ProductRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.jayway.jsonpath.JsonPath;
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
import java.util.ArrayList;
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
@Transactional
class PatientProductControllerTest extends AbstractIntegrationTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private UserAccountRepository users;

	@Autowired
	private PatientProfileRepository patients;

	@Autowired
	private ProductRepository products;

	@Autowired
	private PatientProductRepository patientProducts;

	@Autowired
	private PasswordEncoder passwordEncoder;

	@Autowired
	private DoctorProfileRepository doctorProfiles;

	@Autowired
	private AppointmentRepository appointments;

	@Autowired
	private AppointmentSessionRepository sessions;

	private static final AtomicInteger counter = new AtomicInteger(0);

	private static final AtomicInteger sessionSlot = new AtomicInteger(0);

	private String login(String email) throws Exception {
		String body = mockMvc.perform(post("/api/auth/login")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"email": "%s", "password": "password"}
						""".formatted(email)))
			.andExpect(status().isOk())
			.andReturn().getResponse().getContentAsString();
		return JsonPath.read(body, "$.accessToken");
	}

	private UserAccount newDoctor() throws Exception {
		int i = counter.incrementAndGet();
		UserAccount u = new UserAccount(
			"pptest.doctor" + i + "@test.com",
			passwordEncoder.encode("password"),
			"Dr.", "Doctor", Role.DOCTOR
		);
		u = users.save(u);
		DoctorProfile profile = new DoctorProfile(u);
		profile.setSpecializations(new ArrayList<>(TreatmentName.CONSULTATION.category().qualifying()));
		doctorProfiles.save(profile);
		return u;
	}

	private UserAccount newPatient() throws Exception {
		int i = counter.incrementAndGet();
		UserAccount u = new UserAccount(
			"pptest.patient" + i + "@test.com",
			passwordEncoder.encode("password"),
			"Patient", "User", Role.PATIENT
		);
		u.setPhone("556" + String.format("%07d", i));
		u = users.save(u);
		PatientProfile p = new PatientProfile(u);
		patients.save(p);
		return u;
	}

	// A non-cancelled session makes the doctor a treater.
	private void treat(UserAccount doctor, UserAccount patient) {
		PatientProfile profile = patients.findById(patient.getId()).orElseThrow();
		DoctorProfile practitioner = doctorProfiles.findById(doctor.getId()).orElseThrow();
		// Practitioner sessions may not overlap, so stagger them.
		Instant start = Instant.now().minusSeconds(7200L + sessionSlot.incrementAndGet() * 3600L);
		Appointment appointment = appointments.save(new Appointment(profile, start));
		sessions.save(new AppointmentSession(
			appointment, practitioner, TreatmentName.CONSULTATION.category(),
			TreatmentName.CONSULTATION, new BigDecimal("100.00"), 20,
			start, start.plusSeconds(1200)));
	}

	// Brand and type are unique together, so claim a free pair.
	private UUID createProduct() {
		int i = counter.incrementAndGet();
		Product product = new Product();
		product.setName("Product " + i);
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
		return products.save(product).getId();
	}

	@Test
	void doctorCanListPatientProducts() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		mockMvc.perform(get("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken))
			.andExpect(status().isOk());
	}

	@Test
	void patientCannotListProductsForOthers() throws Exception {
		newPatient();
		String patient1Token = login("pptest.patient" + counter.get() + "@test.com");
		UserAccount patient2 = newPatient();
		mockMvc.perform(get("/api/patients/{id}/products", patient2.getId())
				.header("Authorization", "Bearer " + patient1Token))
			.andExpect(status().isForbidden());
	}

	@Test
	void adminCanAddProductForPatient() throws Exception {
		UserAccount admin = new UserAccount(
			"pptest.admin" + counter.incrementAndGet() + "@test.com",
			passwordEncoder.encode("password"),
			"Admin", "User", Role.ADMIN
		);
		admin = users.save(admin);
		String adminToken = login("pptest.admin" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		UUID productId = createProduct();
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + adminToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isCreated());
	}

	@Test
	void doctorCanAddProductForPatient() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		UUID productId = createProduct();
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isCreated());
	}

	@Test
	void patientCanAddOwnProduct() throws Exception {
		UserAccount patient = newPatient();
		String patientToken = login("pptest.patient" + counter.get() + "@test.com");
		UUID productId = createProduct();
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + patientToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PATIENT_OWN","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isCreated());
	}

	@Test
	void patientCannotAddPrescribedProduct() throws Exception {
		UserAccount patient = newPatient();
		String patientToken = login("pptest.patient" + counter.get() + "@test.com");
		UUID productId = createProduct();
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + patientToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isForbidden());
	}

	@Test
	void rejectAddWithNonexistentProduct() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(UUID.randomUUID(), LocalDate.now())))
			.andExpect(status().isNotFound());
	}

	@Test
	void rejectAddWithNonexistentPatient() throws Exception {
		users.save(new UserAccount(
			"pptest.admin" + counter.incrementAndGet() + "@test.com",
			passwordEncoder.encode("password"),
			"Admin", "User", Role.ADMIN
		));
		String doctorToken = login("pptest.admin" + counter.get() + "@test.com");
		UUID productId = createProduct();
		mockMvc.perform(post("/api/patients/{id}/products", UUID.randomUUID())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isNotFound());
	}

	@Test
	void rejectAddDuplicateActiveProduct() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		UUID productId = createProduct();
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isCreated());
		// Try to add same product again
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isConflict());
	}

	@Test
	void rejectAddWithFutureStartDate() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		UUID productId = createProduct();
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now().plusDays(1))))
			.andExpect(status().isBadRequest());
	}

	@Test
	void rejectAddWithMissingProductId() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(LocalDate.now())))
			.andExpect(status().isBadRequest());
	}

	@Test
	void rejectAddWithMissingSource() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		UUID productId = createProduct();
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isBadRequest());
	}

	@Test
	void doctorCanDiscontinueProduct() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		UUID productId = createProduct();
		String addRes = mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isCreated())
			.andReturn().getResponse().getContentAsString();
		String patientProductId = JsonPath.read(addRes, "$.id");
		mockMvc.perform(put("/api/patients/{id}/products/{ppId}/discontinue", patient.getId(), patientProductId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON))
			.andExpect(status().isOk());
	}

	@Test
	void patientCanDiscontinueOwnProduct() throws Exception {
		UserAccount patient = newPatient();
		String patientToken = login("pptest.patient" + counter.get() + "@test.com");
		UUID productId = createProduct();
		String addRes = mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + patientToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PATIENT_OWN","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isCreated())
			.andReturn().getResponse().getContentAsString();
		String patientProductId = JsonPath.read(addRes, "$.id");
		mockMvc.perform(put("/api/patients/{id}/products/{ppId}/discontinue", patient.getId(), patientProductId)
				.header("Authorization", "Bearer " + patientToken)
				.contentType(MediaType.APPLICATION_JSON))
			.andExpect(status().isOk());
	}

	@Test
	void patientCannotDiscontinueOtherPatientProduct() throws Exception {
		newPatient();
		String patient1Token = login("pptest.patient" + counter.get() + "@test.com");
		mockMvc.perform(put("/api/patients/{id}/products/{ppId}/discontinue", UUID.randomUUID(), UUID.randomUUID())
				.header("Authorization", "Bearer " + patient1Token)
				.contentType(MediaType.APPLICATION_JSON))
			.andExpect(status().isForbidden());
	}

	@Test
	void rejectDiscontinueNonexistentProduct() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		mockMvc.perform(put("/api/patients/{id}/products/{ppId}/discontinue", patient.getId(), UUID.randomUUID())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON))
			.andExpect(status().isNotFound());
	}

	@Test
	void rejectDiscontinueProductForWrongPatient() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient1 = newPatient();
		treat(doctor, patient1);
		UUID productId = createProduct();
		String addRes = mockMvc.perform(post("/api/patients/{id}/products", patient1.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isCreated())
			.andReturn().getResponse().getContentAsString();
		String patientProductId = JsonPath.read(addRes, "$.id");
		UserAccount patient2 = newPatient();
		treat(doctor, patient2);
		mockMvc.perform(put("/api/patients/{id}/products/{ppId}/discontinue", patient2.getId(), patientProductId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON))
			.andExpect(status().isNotFound());
	}

	@Test
	void doctorCanAddMultipleProductsToPatient() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		UUID productId1 = createProduct();
		UUID productId2 = createProduct();
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId1, LocalDate.now())))
			.andExpect(status().isCreated());
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId2, LocalDate.now())))
			.andExpect(status().isCreated());
		mockMvc.perform(get("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.length()").value(2));
	}

	@Test
	void discontinuedProductDoesNotAppearAsActive() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pptest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		UUID productId = createProduct();
		String addRes = mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isCreated())
			.andReturn().getResponse().getContentAsString();
		String patientProductId = JsonPath.read(addRes, "$.id");
		mockMvc.perform(put("/api/patients/{id}/products/{ppId}/discontinue", patient.getId(), patientProductId)
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON))
			.andExpect(status().isOk());
		// Re-add after soft delete works
		mockMvc.perform(post("/api/patients/{id}/products", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"productId":"%s","source":"PRESCRIBED","startedOn":"%s"}
						""".formatted(productId, LocalDate.now())))
			.andExpect(status().isCreated());
	}
}
