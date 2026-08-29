package com.example.backend.controllers;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.PatientProfile.Allergy;
import com.example.backend.entities.PatientProfile.SkinType;
import com.example.backend.entities.UserAccount;
import com.example.backend.entities.UserAccount.Gender;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
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
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

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
class PatientControllerTest extends AbstractIntegrationTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private UserAccountRepository users;

	@Autowired
	private PatientProfileRepository patients;

	@Autowired
	private PasswordEncoder passwordEncoder;

	@Autowired
	private DoctorProfileRepository doctorProfiles;

	@Autowired
	private AppointmentRepository appointments;

	@Autowired
	private AppointmentSessionRepository sessions;

	@Autowired
	private TransactionTemplate transactions;

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

	private UserAccount newAdmin() {
		int i = counter.incrementAndGet();
		UserAccount u = new UserAccount(
			"pctest.admin" + i + "@test.com",
			passwordEncoder.encode("password"),
			"Admin", "User", Role.ADMIN
		);
		return users.save(u);
	}

	private UserAccount newDoctor() {
		int i = counter.incrementAndGet();
		UserAccount u = new UserAccount(
			"pctest.doctor" + i + "@test.com",
			passwordEncoder.encode("password"),
			"Dr.", "Doctor", Role.DOCTOR
		);
		u = users.save(u);
		DoctorProfile profile = new DoctorProfile(u);
		profile.setSpecializations(new ArrayList<>(TreatmentName.CONSULTATION.category().qualifying()));
		doctorProfiles.save(profile);
		return u;
	}

	private UserAccount newPatient() {
		int i = counter.incrementAndGet();
		UserAccount u = new UserAccount(
			"pctest.patient" + i + "@test.com",
			passwordEncoder.encode("password"),
			"Patient", "User", Role.PATIENT
		);
		u.setPhone("555" + String.format("%07d", i));
		u.setDateOfBirth(LocalDate.of(1990, 5, 15));
		u = users.save(u);
		PatientProfile p = new PatientProfile(u);
		p.setSkinType(SkinType.OILY);
		p.setAllergies(List.of(Allergy.NUTS));
		patients.save(p);
		return u;
	}

	// View logging commits separately, so its fixtures must too.
	private Treated committedTreated() {
		TransactionTemplate committing = new TransactionTemplate(transactions.getTransactionManager());
		committing.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
		return committing.execute(status -> {
			UserAccount doctor = newDoctor();
			UserAccount patient = newPatient();
			treat(doctor, patient);
			return new Treated(doctor, patient);
		});
	}

	private record Treated(UserAccount doctor, UserAccount patient) {
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

	@Test
	void adminCanRegisterPatient() throws Exception {
		newAdmin();
		String adminToken = login("pctest.admin" + counter.get() + "@test.com");
		String res = mockMvc.perform(post("/api/patients")
				.header("Authorization", "Bearer " + adminToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"Jane","lastName":"Smith","dateOfBirth":"1995-03-20",
						"phone":"555%07d","email":"jane%d@test.com","gender":"FEMALE",
						"password":"SecurePass123",
						"clinical":{"pregnantBreastfeeding":false,"skinType":"DRY",
						"smokingStatus":"NEVER","allergies":[],"medications":[],"chronicConditions":[]}}
						""".formatted(counter.get() * 10000 + 1, counter.get())))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.firstName").value("Jane"))
			.andReturn().getResponse().getContentAsString();
		String id = JsonPath.read(res, "$.id");
		mockMvc.perform(get("/api/patients/{id}", id)
				.header("Authorization", "Bearer " + adminToken))
			.andExpect(status().isOk());
	}

	@Test
	void doctorCanRegisterPatient() throws Exception {
		newDoctor();
		String doctorToken = login("pctest.doctor" + counter.get() + "@test.com");
		mockMvc.perform(post("/api/patients")
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"Bob","lastName":"Brown","dateOfBirth":"1985-06-10",
						"phone":"555%07d","email":"bob%d@test.com","gender":"MALE",
						"password":"SecurePass123",
						"clinical":{"pregnantBreastfeeding":false,"skinType":"NORMAL",
						"smokingStatus":"FORMER","allergies":[],"medications":[],"chronicConditions":[]}}
						""".formatted(counter.get() * 10000 + 2, counter.get())))
			.andExpect(status().isCreated());
	}

	@Test
	void patientCannotRegisterPatient() throws Exception {
		newPatient();
		String patientToken = login("pctest.patient" + counter.get() + "@test.com");
		mockMvc.perform(post("/api/patients")
				.header("Authorization", "Bearer " + patientToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"Test","lastName":"User","dateOfBirth":"1990-01-01",
						"phone":"555%07d","email":"test%d@test.com","gender":"MALE",
						"password":"SecurePass123",
						"clinical":{"pregnantBreastfeeding":false,"skinType":"OILY",
						"smokingStatus":"NEVER","allergies":[],"medications":[],"chronicConditions":[]}}
						""".formatted(counter.get() * 10000 + 3, counter.get())))
			.andExpect(status().isForbidden());
	}

	@Test
	void rejectRegisterWithDuplicateEmail() throws Exception {
		newAdmin();
		String adminToken = login("pctest.admin" + counter.get() + "@test.com");
		UserAccount existing = newPatient();
		mockMvc.perform(post("/api/patients")
				.header("Authorization", "Bearer " + adminToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"Dup","lastName":"User","dateOfBirth":"1990-01-01",
						"phone":"555%07d","email":"%s","gender":"MALE",
						"password":"SecurePass123",
						"clinical":{"pregnantBreastfeeding":false,"skinType":"OILY",
						"smokingStatus":"NEVER","allergies":[],"medications":[],"chronicConditions":[]}}
						""".formatted(counter.get() * 10000 + 4, existing.getEmail())))
			.andExpect(status().isConflict());
	}

	@Test
	void rejectRegisterWithDuplicatePhone() throws Exception {
		newAdmin();
		String adminToken = login("pctest.admin" + counter.get() + "@test.com");
		UserAccount existing = newPatient();
		mockMvc.perform(post("/api/patients")
				.header("Authorization", "Bearer " + adminToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"Dup2","lastName":"User","dateOfBirth":"1990-01-01",
						"phone":"%s","email":"dup%d@test.com","gender":"MALE",
						"password":"SecurePass123",
						"clinical":{"pregnantBreastfeeding":false,"skinType":"OILY",
						"smokingStatus":"NEVER","allergies":[],"medications":[],"chronicConditions":[]}}
						""".formatted(existing.getPhone(), counter.get())))
			.andExpect(status().isConflict());
	}

	@Test
	void rejectRegisterWithMissingClinicalProfile() throws Exception {
		newAdmin();
		String adminToken = login("pctest.admin" + counter.get() + "@test.com");
		mockMvc.perform(post("/api/patients")
				.header("Authorization", "Bearer " + adminToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"No","lastName":"Clinical","dateOfBirth":"1990-01-01",
						"phone":"555%07d","email":"noclin%d@test.com","gender":"MALE",
						"password":"SecurePass123"}
						""".formatted(counter.get() * 10000 + 5, counter.get())))
			.andExpect(status().isBadRequest());
	}

	@Test
	void rejectRegisterWithInvalidEmail() throws Exception {
		newAdmin();
		String adminToken = login("pctest.admin" + counter.get() + "@test.com");
		mockMvc.perform(post("/api/patients")
				.header("Authorization", "Bearer " + adminToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"Bad","lastName":"Email","dateOfBirth":"1990-01-01",
						"phone":"555%07d","email":"invalid-email","gender":"MALE",
						"password":"SecurePass123",
						"clinical":{"pregnantBreastfeeding":false,"skinType":"OILY",
						"smokingStatus":"NEVER","allergies":[],"medications":[],"chronicConditions":[]}}
						""".formatted(counter.get() * 10000 + 6)))
			.andExpect(status().isBadRequest());
	}

	@Test
	void rejectRegisterWithShortPassword() throws Exception {
		newAdmin();
		String adminToken = login("pctest.admin" + counter.get() + "@test.com");
		mockMvc.perform(post("/api/patients")
				.header("Authorization", "Bearer " + adminToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"Short","lastName":"Pass","dateOfBirth":"1990-01-01",
						"phone":"555%07d","email":"short%d@test.com","gender":"MALE",
						"password":"short",
						"clinical":{"pregnantBreastfeeding":false,"skinType":"OILY",
						"smokingStatus":"NEVER","allergies":[],"medications":[],"chronicConditions":[]}}
						""".formatted(counter.get() * 10000 + 7, counter.get())))
			.andExpect(status().isBadRequest());
	}

	@Test
	void staffCanSearchPatients() throws Exception {
		newAdmin();
		String adminToken = login("pctest.admin" + counter.get() + "@test.com");
		newPatient();
		mockMvc.perform(get("/api/patients")
				.header("Authorization", "Bearer " + adminToken)
				.param("q", "Patient")
				.param("page", "0")
				.param("size", "10"))
			.andExpect(status().isOk());
	}

	@Test
	void patientCannotSearchPatients() throws Exception {
		newPatient();
		String patientToken = login("pctest.patient" + counter.get() + "@test.com");
		mockMvc.perform(get("/api/patients")
				.header("Authorization", "Bearer " + patientToken)
				.param("q", "John"))
			.andExpect(status().isForbidden());
	}

	@Test
	void staffCanReadPatient() throws Exception {
		newAdmin();
		String adminToken = login("pctest.admin" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		mockMvc.perform(get("/api/patients/{id}", patient.getId())
				.header("Authorization", "Bearer " + adminToken))
			.andExpect(status().isOk());
	}

	@Test
	void patientCanReadOwnProfile() throws Exception {
		UserAccount patient = newPatient();
		String patientToken = login("pctest.patient" + counter.get() + "@test.com");
		mockMvc.perform(get("/api/patients/{id}", patient.getId())
				.header("Authorization", "Bearer " + patientToken))
			.andExpect(status().isOk());
	}

	@Test
	void patientCannotReadOtherPatient() throws Exception {
		newPatient();
		String patient1Token = login("pctest.patient" + counter.get() + "@test.com");
		UserAccount patient2 = newPatient();
		mockMvc.perform(get("/api/patients/{id}", patient2.getId())
				.header("Authorization", "Bearer " + patient1Token))
			.andExpect(status().isForbidden());
	}

	@Test
	void rejectReadNonexistentPatient() throws Exception {
		newAdmin();
		String adminToken = login("pctest.admin" + counter.get() + "@test.com");
		mockMvc.perform(get("/api/patients/{id}", UUID.randomUUID())
				.header("Authorization", "Bearer " + adminToken))
			.andExpect(status().isNotFound());
	}

	@Test
	void staffCanUpdatePatientDemographics() throws Exception {
		newAdmin();
		String adminToken = login("pctest.admin" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		mockMvc.perform(put("/api/patients/{id}", patient.getId())
				.header("Authorization", "Bearer " + adminToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"Jonathan","lastName":"Doe","dateOfBirth":"1990-05-15",
						"phone":"%s","email":"%s","gender":"MALE",
						"password":"password",
						"clinical":{"pregnantBreastfeeding":false,"skinType":"OILY",
						"smokingStatus":"NEVER","allergies":[],"medications":[],"chronicConditions":[]}}
						""".formatted(patient.getPhone(), patient.getEmail())))
			.andExpect(status().isOk());
	}

	@Test
	void doctorCanUpdatePatientDemographics() throws Exception {
		newDoctor();
		String doctorToken = login("pctest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		mockMvc.perform(put("/api/patients/{id}", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"Jack","lastName":"Doe","dateOfBirth":"1990-05-15",
						"phone":"%s","email":"%s","gender":"MALE",
						"password":"password",
						"clinical":{"pregnantBreastfeeding":false,"skinType":"OILY",
						"smokingStatus":"NEVER","allergies":[],"medications":[],"chronicConditions":[]}}
						""".formatted(patient.getPhone(), patient.getEmail())))
			.andExpect(status().isOk());
	}

	@Test
	void patientCannotUpdateOtherDemographics() throws Exception {
		newPatient();
		String patient1Token = login("pctest.patient" + counter.get() + "@test.com");
		UserAccount patient2 = newPatient();
		mockMvc.perform(put("/api/patients/{id}", patient2.getId())
				.header("Authorization", "Bearer " + patient1Token)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"firstName":"Fake","lastName":"User","dateOfBirth":"1990-01-01",
						"phone":"555%07d","email":"fake%d@test.com","gender":"MALE",
						"password":"password",
						"clinical":{"pregnantBreastfeeding":false,"skinType":"OILY",
						"smokingStatus":"NEVER","allergies":[],"medications":[],"chronicConditions":[]}}
						""".formatted(counter.get() * 10000 + 8, counter.get())))
			.andExpect(status().isForbidden());
	}

	@Test
	void patientCanReadOwnClinicalProfile() throws Exception {
		newPatient();
		String patientToken = login("pctest.patient" + counter.get() + "@test.com");
		mockMvc.perform(get("/api/patients/me")
				.header("Authorization", "Bearer " + patientToken))
			.andExpect(status().isOk());
	}

	@Test
	void doctorCanReadPatientClinicalProfile() throws Exception {
		Treated treated = committedTreated();
		String doctorToken = login(treated.doctor().getEmail());
		mockMvc.perform(get("/api/patients/{id}/clinical", treated.patient().getId())
				.header("Authorization", "Bearer " + doctorToken))
			.andExpect(status().isOk());
	}

	@Test
	void doctorCannotReadClinicalProfileWithoutTreating() throws Exception {
		newDoctor();
		String doctorToken = login("pctest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		mockMvc.perform(get("/api/patients/{id}/clinical", patient.getId())
				.header("Authorization", "Bearer " + doctorToken))
			.andExpect(status().isForbidden());
	}

	@Test
	void patientCannotReadOtherClinicalProfile() throws Exception {
		newPatient();
		String patient1Token = login("pctest.patient" + counter.get() + "@test.com");
		UserAccount patient2 = newPatient();
		mockMvc.perform(get("/api/patients/{id}/clinical", patient2.getId())
				.header("Authorization", "Bearer " + patient1Token))
			.andExpect(status().isForbidden());
	}

	@Test
	void rejectReadNonexistentClinicalProfile() throws Exception {
		newAdmin();
		String doctorToken = login("pctest.admin" + counter.get() + "@test.com");
		mockMvc.perform(get("/api/patients/{id}/clinical", UUID.randomUUID())
				.header("Authorization", "Bearer " + doctorToken))
			.andExpect(status().isNotFound());
	}

	@Test
	void doctorCanSearchClinicalPatients() throws Exception {
		newDoctor();
		String doctorToken = login("pctest.doctor" + counter.get() + "@test.com");
		newPatient();
		mockMvc.perform(get("/api/patients/clinical")
				.header("Authorization", "Bearer " + doctorToken)
				.param("q", "Patient")
				.param("page", "0")
				.param("size", "10"))
			.andExpect(status().isOk());
	}

	@Test
	void patientCannotAccessClinicalSearch() throws Exception {
		newPatient();
		String patientToken = login("pctest.patient" + counter.get() + "@test.com");
		mockMvc.perform(get("/api/patients/clinical")
				.header("Authorization", "Bearer " + patientToken)
				.param("q", "John"))
			.andExpect(status().isForbidden());
	}

	@Test
	void patientCanUpdateOwnProfile() throws Exception {
		newPatient();
		String patientToken = login("pctest.patient" + counter.get() + "@test.com");
		mockMvc.perform(put("/api/patients/me")
				.header("Authorization", "Bearer " + patientToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"phone":"5559876543"}
						"""))
			.andExpect(status().isOk());
	}

	@Test
	void doctorCannotUpdatePatientViaMe() throws Exception {
		newDoctor();
		String doctorToken = login("pctest.doctor" + counter.get() + "@test.com");
		mockMvc.perform(put("/api/patients/me")
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"phone":"5559876543"}
						"""))
			.andExpect(status().isForbidden());
	}

	@Test
	void patientCanUpdateOwnClinicalProfile() throws Exception {
		newPatient();
		String patientToken = login("pctest.patient" + counter.get() + "@test.com");
		mockMvc.perform(put("/api/patients/me/clinical")
				.header("Authorization", "Bearer " + patientToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"pregnantBreastfeeding":true,"skinType":"DRY",
						"smokingStatus":"CURRENT","allergies":["LATEX"],
						"medications":["ISOTRETINOIN"],"chronicConditions":["DIABETES"]}
						"""))
			.andExpect(status().isOk());
	}

	@Test
	void patientCanReadOwnRecord() throws Exception {
		UserAccount patient = newPatient();
		String patientToken = login("pctest.patient" + counter.get() + "@test.com");
		mockMvc.perform(get("/api/patients/me")
				.header("Authorization", "Bearer " + patientToken))
			.andExpect(status().isOk());
	}

	@Test
	void doctorCanUpdatePatientClinicalProfile() throws Exception {
		UserAccount doctor = newDoctor();
		String doctorToken = login("pctest.doctor" + counter.get() + "@test.com");
		UserAccount patient = newPatient();
		treat(doctor, patient);
		mockMvc.perform(put("/api/patients/{id}/clinical", patient.getId())
				.header("Authorization", "Bearer " + doctorToken)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"pregnantBreastfeeding":false,"skinType":"COMBINATION",
						"smokingStatus":"NEVER","allergies":["NUTS"],
						"medications":[],"chronicConditions":[]}
						"""))
			.andExpect(status().isOk());
	}

	@Test
	void patientCannotUpdateOtherClinicalProfile() throws Exception {
		newPatient();
		String patient1Token = login("pctest.patient" + counter.get() + "@test.com");
		UserAccount patient2 = newPatient();
		mockMvc.perform(put("/api/patients/{id}/clinical", patient2.getId())
				.header("Authorization", "Bearer " + patient1Token)
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"pregnantBreastfeeding":false,"skinType":"OILY",
						"smokingStatus":"NEVER","allergies":[],"medications":[],"chronicConditions":[]}
						"""))
			.andExpect(status().isForbidden());
	}

	@Test
	void doctorCanReadClinicalHistory() throws Exception {
		Treated treated = committedTreated();
		String doctorToken = login(treated.doctor().getEmail());
		mockMvc.perform(get("/api/patients/{id}/clinical/history", treated.patient().getId())
				.header("Authorization", "Bearer " + doctorToken)
				.param("page", "0")
				.param("size", "10"))
			.andExpect(status().isOk());
	}

	@Test
	void patientCannotReadClinicalHistory() throws Exception {
		newPatient();
		String patientToken = login("pctest.patient" + counter.get() + "@test.com");
		mockMvc.perform(get("/api/patients/{id}/clinical/history", UUID.randomUUID())
				.header("Authorization", "Bearer " + patientToken))
			.andExpect(status().isForbidden());
	}

	@Test
	void rejectReadNonexistentClinicalHistory() throws Exception {
		newAdmin();
		String doctorToken = login("pctest.admin" + counter.get() + "@test.com");
		mockMvc.perform(get("/api/patients/{id}/clinical/history", UUID.randomUUID())
				.header("Authorization", "Bearer " + doctorToken))
			.andExpect(status().isNotFound());
	}
}
