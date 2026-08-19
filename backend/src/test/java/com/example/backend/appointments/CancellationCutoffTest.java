package com.example.backend.appointments;

import com.example.backend.config.ClinicProperties;
import com.example.backend.config.ClinicProperties.Tariff;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.security.CurrentUser;
import com.example.backend.security.Role;
import com.example.backend.services.AccessTokenService;
import com.example.backend.services.CancellationPolicy;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

// The single cutoff gate, on a pinned clock so the exact boundary is a fact rather than a race.
class CancellationCutoffTest {

    private static final Instant VISIT_START = Instant.parse("2026-08-11T10:00:00Z");
    private static final Duration CUTOFF = Duration.ofMinutes(60);

    @AfterEach
    void clearCaller() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void patientCanCancelBeforeCutoff() {
        callerIs(Role.PATIENT);

        assertThatCode(() -> policyAt(VISIT_START.minus(CUTOFF).minusSeconds(60))
                .assertCancellable(VISIT_START))
                .doesNotThrowAnyException();
    }

    // The documented boundary: at exactly 60 minutes out the patient is still in time.
    @Test
    void patientCanCancelAtCutoff() {
        callerIs(Role.PATIENT);

        assertThatCode(() -> policyAt(VISIT_START.minus(CUTOFF)).assertCancellable(VISIT_START))
                .doesNotThrowAnyException();
    }

    @Test
    void patientCannotCancelInsideCutoff() {
        callerIs(Role.PATIENT);

        assertThatThrownBy(() -> policyAt(VISIT_START.minus(CUTOFF).plusSeconds(1))
                .assertCancellable(VISIT_START))
                .hasMessageContaining("60 minutes before");
    }

    @Test
    void patientCannotCancelStartedVisit() {
        callerIs(Role.PATIENT);

        assertThatThrownBy(() -> policyAt(VISIT_START).assertCancellable(VISIT_START))
                .hasMessageContaining("60 minutes before");
    }

    @Test
    void staffCanCancelInsidePatientCutoff() {
        callerIs(Role.RECEPTIONIST);

        assertThatCode(() -> policyAt(VISIT_START.minusSeconds(60)).assertCancellable(VISIT_START))
                .doesNotThrowAnyException();
    }

    @Test
    void staffCannotCancelAtVisitStart() {
        callerIs(Role.RECEPTIONIST);

        assertThatThrownBy(() -> policyAt(VISIT_START).assertCancellable(VISIT_START))
                .hasMessageContaining("already started");
    }

    @Test
    void staffCannotCancelAfterVisitStart() {
        callerIs(Role.DOCTOR);

        assertThatThrownBy(() -> policyAt(VISIT_START.plusSeconds(1)).assertCancellable(VISIT_START))
                .hasMessageContaining("already started");
    }

    // ─── R1: a patient may not book what they could not then cancel ─────────

    @Test
    void patientCannotBookInsideWindow() {
        callerIs(Role.PATIENT);

        assertThatThrownBy(() -> policyAt(VISIT_START.minus(CUTOFF).plusSeconds(1))
                .assertLeavesRoomToCancel(VISIT_START))
                .hasMessageContaining("at least 60 minutes ahead");
    }

    @Test
    void patientCanBookAtCutoff() {
        callerIs(Role.PATIENT);

        assertThatCode(() -> policyAt(VISIT_START.minus(CUTOFF)).assertLeavesRoomToCancel(VISIT_START))
                .doesNotThrowAnyException();
    }

    @Test
    void staffCanBookAtShortNotice() {
        callerIs(Role.RECEPTIONIST);

        assertThatCode(() -> policyAt(VISIT_START.minusSeconds(60)).assertLeavesRoomToCancel(VISIT_START))
                .doesNotThrowAnyException();
    }

    // ─── R2: the window read on the patient's behalf, whoever is asking ─────

    @Test
    void windowIsOpenAtCutoff() {
        callerIs(Role.RECEPTIONIST);

        assertThat(policyAt(VISIT_START.minus(CUTOFF)).patientWindowOpen(VISIT_START)).isTrue();
        assertThat(policyAt(VISIT_START.minus(CUTOFF).plusSeconds(1)).patientWindowOpen(VISIT_START))
                .isFalse();
    }

    private CancellationPolicy policyAt(Instant now) {
        return new CancellationPolicy(clinic(), new CurrentUser(), Clock.fixed(now, ZoneOffset.UTC));
    }

    private void callerIs(Role role) {
        Jwt token = Jwt.withTokenValue("test")
                .header("alg", "none")
                .claim(AccessTokenService.USER_ID_CLAIM, UUID.randomUUID().toString())
                .build();

        SecurityContextHolder.getContext().setAuthentication(
                new JwtAuthenticationToken(token, List.of(role.authority())));
    }

    private ClinicProperties clinic() {
        Map<TreatmentName, Tariff> tariff = Arrays.stream(TreatmentName.values())
                .collect(Collectors.toMap(
                        Function.identity(),
                        name -> new Tariff(new BigDecimal("100.00"), 30)));

        return new ClinicProperties("UTC", "ILS", tariff, 180, 15, 10, (int) CUTOFF.toMinutes());
    }
}
