package com.example.backend.appointments;

import com.example.backend.config.ClinicProperties;
import com.example.backend.config.ClinicProperties.Tariff;
import com.example.backend.dtos.BookingRulesResponse;
import com.example.backend.dtos.TreatmentResponse;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.services.TreatmentCatalogService;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

// The catalogue is the tariff, read straight through.
class TreatmentCatalogServiceTest {

    @Test
    void listsEveryTreatment() {
        TreatmentCatalogService catalog = new TreatmentCatalogService(clinic());

        List<TreatmentResponse> treatments = catalog.list();

        // One entry per enum value, no more.
        assertThat(treatments).hasSize(TreatmentName.values().length);
        assertThat(treatments).extracting(TreatmentResponse::treatmentName)
                .containsExactlyInAnyOrder(TreatmentName.values());

        TreatmentResponse botox = treatments.stream()
                .filter(t -> t.treatmentName() == TreatmentName.BOTOX)
                .findFirst().orElseThrow();

        // Category from the enum, price from the tariff.
        assertThat(botox.category()).isEqualTo(TreatmentName.BOTOX.category());
        assertThat(botox.durationMinutes()).isEqualTo(45);
        assertThat(botox.price()).isEqualByComparingTo("777.00");
    }

    @Test
    void rulesMirrorConfiguration() {
        TreatmentCatalogService catalog = new TreatmentCatalogService(clinic());

        BookingRulesResponse rules = catalog.rules();

        assertThat(rules.timezone()).isEqualTo("UTC");
        assertThat(rules.maxHorizonDays()).isEqualTo(180);
        assertThat(rules.slotGranularityMinutes()).isEqualTo(15);
        assertThat(rules.turnoverMinutes()).isEqualTo(10);
        assertThat(rules.cancellationCutoffMinutes()).isEqualTo(60);
    }

    // Distinct values so the mapping cannot pass coincidentally.
    private ClinicProperties clinic() {
        Map<TreatmentName, Tariff> tariff = new EnumMap<>(TreatmentName.class);
        Arrays.stream(TreatmentName.values())
                .forEach(name -> tariff.put(name, new Tariff(new BigDecimal("777.00"), 45)));

        return new ClinicProperties("UTC", "ILS", tariff, 180, 15, 10, 60);
    }
}
