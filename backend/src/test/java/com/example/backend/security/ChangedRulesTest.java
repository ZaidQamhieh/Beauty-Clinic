package com.example.backend.security;

import com.example.backend.config.ClinicProperties;
import com.example.backend.config.ClinicProperties.Tariff;
import com.example.backend.dtos.CreateDoctorAvailabilityRequest;
import com.example.backend.dtos.DayAvailabilityStatus;
import com.example.backend.dtos.DoctorAvailabilityDayStatus;
import com.example.backend.dtos.DoctorAvailabilityResponse;
import com.example.backend.dtos.EditClinicalProfileRequest;
import com.example.backend.dtos.FreeSlotQuery;
import com.example.backend.dtos.PatientDetailsRequest;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.PatientProfile.SkinType;
import com.example.backend.entities.PatientProfile.SmokingStatus;
import com.example.backend.entities.UserAccount;
import com.example.backend.entities.UserAccount.AccountStatus;
import com.example.backend.repositories.ActivityLogRepository;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorAvailabilityRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientFormResponseRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.services.ActivityCorrelation;
import com.example.backend.services.ActivityLogService;
import com.example.backend.services.AppointmentSessionService;
import com.example.backend.services.CancellationPolicy;
import com.example.backend.services.DoctorAvailabilityService;
import com.example.backend.services.LoginLockoutService;
import com.example.backend.services.PatientProfileService;
import jakarta.servlet.FilterChain;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.RETURNS_DEEP_STUBS;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

// Covers the rules changed in this branch that can be exercised without a database.
// The appointment-lock fix (F-06) is a concurrency property and needs real Postgres,
// so it is left to the Testcontainers suite.
class ChangedRulesTest {

    // ─── F-05: attendance cannot be recorded before the treatment starts ──────

    private AppointmentRepository appointments;

    private AppointmentSessionService sessionServiceWith(AppointmentSession session) {
        AppointmentSessionRepository sessions = mock(AppointmentSessionRepository.class);
        when(sessions.findWithLockByIdAndAppointmentId(any(), any()))
                .thenReturn(Optional.of(session));

        appointments = mock(AppointmentRepository.class);
        when(appointments.findWithLockById(any()))
                .thenReturn(Optional.of(mock(Appointment.class, RETURNS_DEEP_STUBS)));

        return new AppointmentSessionService(
                sessions,
                appointments,
                mock(DoctorProfileRepository.class),
                mock(PatientProfileRepository.class),
                mock(DoctorAvailabilityService.class),
                clinicProperties(),
                mock(ActivityLogService.class),
                mock(ActivityCorrelation.class),
                mock(CurrentUser.class),
                mock(CancellationPolicy.class),
                Clock.systemUTC()
        );
    }

    private AppointmentSession plannedSessionStartingAt(Instant startTime) {
        AppointmentSession session = mock(AppointmentSession.class, RETURNS_DEEP_STUBS);
        when(session.getStartTime()).thenReturn(startTime);
        when(session.getStatus()).thenReturn(SessionStatus.PLANNED);
        return session;
    }

    @Test
    void aFutureSessionCannotBeMarkedAttended() {
        AppointmentSession session = plannedSessionStartingAt(Instant.now().plus(Duration.ofDays(1)));

        assertThatThrownBy(() -> sessionServiceWith(session).markAttended(UUID.randomUUID(), UUID.randomUUID()))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("has not started yet");

        verify(session, never()).setStatus(any());
    }

    @Test
    void aFutureSessionCannotBeMarkedNoShow() {
        AppointmentSession session = plannedSessionStartingAt(Instant.now().plus(Duration.ofMinutes(1)));

        assertThatThrownBy(() -> sessionServiceWith(session).markNoShow(UUID.randomUUID(), UUID.randomUUID()))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("has not started yet");

        verify(session, never()).setStatus(any());
    }

    @Test
    void aStartedSessionStillTransitions() {
        AppointmentSession session = plannedSessionStartingAt(Instant.now().minus(Duration.ofMinutes(30)));

        assertThatCode(() -> sessionServiceWith(session).markAttended(UUID.randomUUID(), UUID.randomUUID()))
                .doesNotThrowAnyException();

        verify(session).setStatus(SessionStatus.COMPLETED);
    }

    // Attendance decides the visit's state too, so it queues behind a cancellation of it.
    @Test
    void markingAttendedTakesTheVisitLockFirst() {
        AppointmentSession session = plannedSessionStartingAt(Instant.now().minus(Duration.ofMinutes(30)));
        UUID appointmentId = UUID.randomUUID();

        sessionServiceWith(session).markAttended(appointmentId, UUID.randomUUID());

        verify(appointments).findWithLockById(appointmentId);
    }

    @Test
    void markingNoShowTakesTheVisitLockFirst() {
        AppointmentSession session = plannedSessionStartingAt(Instant.now().minus(Duration.ofMinutes(30)));
        UUID appointmentId = UUID.randomUUID();

        sessionServiceWith(session).markNoShow(appointmentId, UUID.randomUUID());

        verify(appointments).findWithLockById(appointmentId);
    }

    // The boundary is deterministic: markable from the start instant onward, not before.
    @Test
    void aSessionStartingExactlyNowIsMarkable() {
        AppointmentSession session = plannedSessionStartingAt(Instant.now().minusMillis(1));

        assertThatCode(() -> sessionServiceWith(session).markNoShow(UUID.randomUUID(), UUID.randomUUID()))
                .doesNotThrowAnyException();

        verify(session).setStatus(SessionStatus.NO_SHOW);
    }

    @Test
    void aSessionThatIsNotPlannedIsStillRejected() {
        AppointmentSession session = plannedSessionStartingAt(Instant.now().minus(Duration.ofHours(1)));
        when(session.getStatus()).thenReturn(SessionStatus.COMPLETED);

        assertThatThrownBy(() -> sessionServiceWith(session).markAttended(UUID.randomUUID(), UUID.randomUUID()))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("not planned");
    }

    // ─── F-03: the lockout ladder is clamped and success clears the strikes ───

    private record Lockout(LoginLockoutService service, UserAccount account) {
    }

    private Lockout lockoutFor(int strikes, int failuresSoFar) {
        UserAccount account = new UserAccount(
                "victim@example.com", "hash", "Vic", "Tim", Role.PATIENT);
        account.setLockoutStrikes(strikes);
        account.setFailedLoginCount(failuresSoFar);

        UserAccountRepository users = mock(UserAccountRepository.class);
        when(users.lockByEmail(any())).thenReturn(Optional.of(account));
        when(users.findByEmailIgnoreCase(any())).thenReturn(Optional.of(account));

        return new Lockout(new LoginLockoutService(users, mock(ActivityLogService.class)), account);
    }

    @Test
    void theFifthFailureLocksTheAccount() {
        Lockout lockout = lockoutFor(0, 4);

        lockout.service().recordFailure("victim@example.com");

        assertThat(lockout.account().isLocked(Instant.now())).isTrue();
        assertThat(lockout.account().getLockoutStrikes()).isEqualTo(1);
    }

    @Test
    void theLadderClampsAtSevenDaysHoweverManyStrikesHaveAccrued() {
        Lockout lockout = lockoutFor(99, 4);

        lockout.service().recordFailure("victim@example.com");

        Duration applied = Duration.between(Instant.now(), lockout.account().getLockedUntil());
        assertThat(applied).isBetween(Duration.ofDays(7).minusMinutes(1), Duration.ofDays(7));
    }

    @Test
    void successfulAuthenticationClearsStrikesAsWellAsTheLock() {
        Lockout lockout = lockoutFor(2, 3);
        lockout.account().setLockedUntil(Instant.now().plus(Duration.ofHours(1)));

        lockout.service().recordSuccess("victim@example.com");

        assertThat(lockout.account().getLockoutStrikes()).isZero();
        assertThat(lockout.account().getFailedLoginCount()).isZero();
        assertThat(lockout.account().getLockedUntil()).isNull();
    }

    // ─── F-01: reception signs a patient up with a real, usable account ───────

    private record Registration(
            PatientProfileService service,
            UserAccountRepository users,
            PatientProfileRepository patients
    ) {
    }

    private Registration registrationService() {
        UserAccountRepository users = mock(UserAccountRepository.class);
        when(users.findByEmailIgnoreCase(any())).thenReturn(Optional.empty());
        when(users.existsByPhone(any())).thenReturn(false);

        PatientProfileRepository patients = mock(PatientProfileRepository.class);
        when(patients.save(any())).thenAnswer(saved -> saved.getArgument(0));

        return new Registration(
                new PatientProfileService(patients, users, new BCryptPasswordEncoder(), mock(CurrentUser.class),
                        mock(ActivityLogService.class), mock(PatientFormResponseRepository.class)),
                users,
                patients);
    }

    private PatientDetailsRequest deskSignup(String password) {
        return deskSignup(password, intakeForm());
    }

    private PatientDetailsRequest deskSignup(String password, EditClinicalProfileRequest clinical) {
        return new PatientDetailsRequest(
                "Lina", "Nasser", LocalDate.of(1995, 3, 4), "0599000111",
                "lina@example.com", UserAccount.Gender.FEMALE, password, clinical);
    }

    private EditClinicalProfileRequest intakeForm() {
        return new EditClinicalProfileRequest(
                false, SkinType.COMBINATION, SmokingStatus.NEVER,
                List.of(), List.of(), List.of());
    }

    @Test
    void aPasswordAtTheDeskProducesAnAccountThePatientCanUse() {
        Registration registration = registrationService();

        registration.service().register(deskSignup("a-real-password"));

        UserAccount saved = savedAccount(registration.users());
        assertThat(saved.getStatus()).isEqualTo(AccountStatus.ACTIVE);
        assertThat(saved.isEnabled()).isTrue();
        assertThat(saved.isClaimed()).isTrue();
        assertThat(new BCryptPasswordEncoder().matches("a-real-password", saved.getPasswordHash())).isTrue();
    }

    @Test
    void aWalkInWithNoPasswordStillLandsAtInvited() {
        Registration registration = registrationService();

        registration.service().register(deskSignup(null));

        UserAccount saved = savedAccount(registration.users());
        assertThat(saved.getStatus()).isEqualTo(AccountStatus.INVITED);
        assertThat(saved.isEnabled()).isFalse();
        assertThat(saved.isClaimed()).isFalse();
    }

    // The whole point: a patient registered at the desk is bookable straight away.
    @Test
    void theIntakeFormIsTakenAtRegistrationSoThePatientIsBookable() {
        Registration registration = registrationService();

        registration.service().register(deskSignup("a-real-password"));

        var captor = org.mockito.ArgumentCaptor.forClass(PatientProfile.class);
        verify(registration.patients()).save(captor.capture());
        assertThat(captor.getValue().hasCompletedHealthForm()).isTrue();
        assertThat(captor.getValue().getSkinType()).isEqualTo(SkinType.COMBINATION);
    }

    @Test
    void registrationWithoutTheIntakeFormIsRejected() {
        Registration registration = registrationService();

        assertThatThrownBy(() -> registration.service().register(deskSignup("a-real-password", null)))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("health form is required");

        verify(registration.users(), never()).save(any());
    }

    @Test
    void theRawPasswordIsNeverStored() {
        Registration registration = registrationService();

        registration.service().register(deskSignup("a-real-password"));

        assertThat(savedAccount(registration.users()).getPasswordHash())
                .isNotNull()
                .doesNotContain("a-real-password")
                .startsWith("$2");
    }

    private UserAccount savedAccount(UserAccountRepository users) {
        var captor = org.mockito.ArgumentCaptor.forClass(UserAccount.class);
        verify(users).save(captor.capture());
        return captor.getValue();
    }

    // ─── F-16: a doctor's sick days are the desk's business, not the public's ─

    private DoctorAvailabilityService availabilityServiceFor(boolean staff) {
        DoctorAvailabilityRepository availabilities = mock(DoctorAvailabilityRepository.class);
        when(availabilities.findByDoctorUserId(any())).thenReturn(List.of(
                availability(AvailabilityKind.RECURRING, true),
                availability(AvailabilityKind.OVERRIDE, true),
                availability(AvailabilityKind.OVERRIDE, false)));

        CurrentUser caller = mock(CurrentUser.class);
        when(caller.isClinicStaff()).thenReturn(staff);

        return new DoctorAvailabilityService(availabilities, mock(DoctorProfileRepository.class), caller,
                mock(ActivityLogService.class));
    }

    private DoctorAvailability availability(AvailabilityKind kind, boolean available) {
        DoctorAvailability window = new DoctorAvailability(
                mock(DoctorProfile.class),
                kind,
                kind == AvailabilityKind.RECURRING ? java.time.DayOfWeek.MONDAY : null,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                LocalDate.now());
        window.setAvailable(available);
        return window;
    }

    @Test
    void aPatientNeverSeesADatedClosure() {
        List<DoctorAvailabilityResponse> visible =
                availabilityServiceFor(false).list(UUID.randomUUID());

        assertThat(visible).noneMatch(window ->
                window.kind() == AvailabilityKind.OVERRIDE && !window.available());
        assertThat(visible).hasSize(2);
    }

    @Test
    void aPatientStillSeesOpenHoursAndExtraShifts() {
        List<DoctorAvailabilityResponse> visible =
                availabilityServiceFor(false).list(UUID.randomUUID());

        assertThat(visible).allMatch(DoctorAvailabilityResponse::available);
        assertThat(visible).extracting(DoctorAvailabilityResponse::kind)
                .containsExactly(AvailabilityKind.RECURRING, AvailabilityKind.OVERRIDE);
    }

    @Test
    void staffSeeTheClosuresToo() {
        List<DoctorAvailabilityResponse> visible =
                availabilityServiceFor(true).list(UUID.randomUUID());

        assertThat(visible).hasSize(3);
        assertThat(visible).anyMatch(window ->
                window.kind() == AvailabilityKind.OVERRIDE && !window.available());
    }

    // ─── Overlap policy no longer keys off the available flag; new calendar status ───

    @Test
    void overlappingWindowsAreRejectedEvenWithDifferentAvailableFlags() {
        UUID doctorId = UUID.randomUUID();
        DoctorAvailability existing = availability(AvailabilityKind.RECURRING, true); // Monday 09:00-17:00, available
        existing.setId(UUID.randomUUID());
        DoctorAvailabilityRepository availabilities = mock(DoctorAvailabilityRepository.class);
        when(availabilities.findByDoctorUserId(doctorId)).thenReturn(List.of(existing));

        DoctorProfileRepository doctors = mock(DoctorProfileRepository.class);
        when(doctors.findById(doctorId)).thenReturn(Optional.of(mock(DoctorProfile.class)));

        DoctorAvailabilityService service =
                new DoctorAvailabilityService(availabilities, doctors, mock(CurrentUser.class));

        CreateDoctorAvailabilityRequest conflicting = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.RECURRING, java.time.DayOfWeek.MONDAY,
                LocalTime.of(12, 0), LocalTime.of(13, 0),
                false, // different available flag than the existing row - must still conflict now
                LocalDate.now(), null);

        assertThatThrownBy(() -> service.add(doctorId, conflicting))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("overlaps an existing window");
    }

    @Test
    void calendarStatusReflectsTheResolvedMergeNotJustRuleExistence() {
        UUID doctorId = UUID.randomUUID();
        LocalDate monday = nextMonday();

        DoctorAvailability recurring = availability(AvailabilityKind.RECURRING, true); // Monday 09:00-17:00, open
        DoctorAvailability fullClosure = new DoctorAvailability(
                mock(DoctorProfile.class),
                AvailabilityKind.OVERRIDE,
                null,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                monday);
        fullClosure.setEffectiveTo(monday);
        fullClosure.setAvailable(false);

        DoctorAvailabilityRepository availabilities = mock(DoctorAvailabilityRepository.class);
        when(availabilities.findByDoctorUserId(doctorId)).thenReturn(List.of(recurring, fullClosure));

        DoctorAvailabilityService service = new DoctorAvailabilityService(
                availabilities, mock(DoctorProfileRepository.class), mock(CurrentUser.class));

        List<DoctorAvailabilityDayStatus> days = service.calendarStatus(doctorId, monday, monday.plusDays(1));

        assertThat(days.get(0).status()).isEqualTo(DayAvailabilityStatus.UNAVAILABLE); // Monday: rule exists, no open time
        assertThat(days.get(1).status()).isEqualTo(DayAvailabilityStatus.NONE); // Tuesday: no rule at all
    }

    private LocalDate nextMonday() {
        LocalDate date = LocalDate.now();
        while (date.getDayOfWeek() != java.time.DayOfWeek.MONDAY) {
            date = date.plusDays(1);
        }
        return date;
    }

    // ─── Scheduling: no lead time left to configure or apply ─────────────────

    @Test
    void clinicPropertiesNoLongerCarryALeadTime() {
        ClinicProperties clinic = clinicProperties();

        assertThat(clinic.horizon()).isEqualTo(Duration.ofDays(180));
        assertThat(clinic.turnover()).isEqualTo(Duration.ofMinutes(10));
        assertThat(ClinicProperties.class.getRecordComponents())
                .extracting(java.lang.reflect.RecordComponent::getName)
                .doesNotContain("minLeadTimeMinutes");
    }

    // ─── Bounded input: held picks are capped like the sessions list ──────────

    @Test
    void aFreeSlotQueryCannotCarryUnboundedHeldPicks() {
        try (ValidatorFactory factory = Validation.buildDefaultValidatorFactory()) {
            Validator validator = factory.getValidator();

            assertThat(validator.validate(freeSlotQueryHolding(10))).isEmpty();
            assertThat(validator.validate(freeSlotQueryHolding(11)))
                    .extracting(violation -> violation.getPropertyPath().toString())
                    .contains("held");
        }
    }

    private FreeSlotQuery freeSlotQueryHolding(int picks) {
        Instant start = Instant.now().plus(Duration.ofDays(1));

        List<FreeSlotQuery.HeldSlot> held = java.util.stream.IntStream.range(0, picks)
                .mapToObj(i -> new FreeSlotQuery.HeldSlot(
                        UUID.randomUUID(),
                        start.plus(Duration.ofHours(i)),
                        start.plus(Duration.ofHours(i)).plus(Duration.ofMinutes(30))))
                .toList();

        return new FreeSlotQuery(
                TreatmentName.CONSULTATION, LocalDate.now().plusDays(1),
                null, null, held, null);
    }

    // ─── Rate limiting: one endpoint's traffic cannot starve another's ────────

    @Test
    void eachGuardedEndpointGetsItsOwnBudgetPerAddress() throws Exception {
        AuthRateLimitFilter filter = new AuthRateLimitFilter(new RateLimitProperties(2, 60), mock(ActivityLogService.class));

        assertThat(statusOf(filter, "/api/auth/refresh")).isEqualTo(HttpStatus.OK.value());
        assertThat(statusOf(filter, "/api/auth/refresh")).isEqualTo(HttpStatus.OK.value());
        assertThat(statusOf(filter, "/api/auth/refresh")).isEqualTo(HttpStatus.TOO_MANY_REQUESTS.value());

        // Refresh is exhausted; login must still be reachable from the same address.
        assertThat(statusOf(filter, "/api/auth/login")).isEqualTo(HttpStatus.OK.value());
    }

    @Test
    void logoutIsNotThrottled() throws Exception {
        AuthRateLimitFilter filter = new AuthRateLimitFilter(new RateLimitProperties(1, 60), mock(ActivityLogService.class));

        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/auth/logout");
        assertThat(filter.shouldNotFilter(request)).isTrue();
    }

    private int statusOf(AuthRateLimitFilter filter, String uri) throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", uri);
        request.setRemoteAddr("203.0.113.7");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, mock(FilterChain.class));
        return response.getStatus();
    }

    private ClinicProperties clinicProperties() {
        Map<TreatmentName, Tariff> tariff = new EnumMap<>(TreatmentName.class);
        for (TreatmentName treatment : TreatmentName.values()) {
            tariff.put(treatment, new Tariff(new BigDecimal("100.00"), 30));
        }

        return new ClinicProperties("UTC", "ILS", tariff, 180, 15, 10, 60);
    }

    // Keeps the unused-import check honest: PatientProfile is referenced by the service under test.
    @SuppressWarnings("unused")
    private PatientProfile unusedProfileReference;
}
