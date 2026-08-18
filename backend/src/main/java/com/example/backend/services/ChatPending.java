package com.example.backend.services;

import com.example.backend.dtos.AddSessionRequest;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

// Confirms book what was shown, not what the model recalls.
@Component
public class ChatPending {

    private static final Duration TTL = Duration.ofMinutes(20);
    private static final int MAX_ENTRIES = 500;

    private final Map<UUID, Quote> quotes = new ConcurrentHashMap<>();
    private final Map<UUID, Cancellation> cancellations = new ConcurrentHashMap<>();
    private final Clock clock;

    public ChatPending(Clock clock) {
        this.clock = clock;
    }

    void quote(UUID patient, List<AddSessionRequest> sessions, BigDecimal total) {
        sweep(quotes);
        quotes.put(patient, new Quote(List.copyOf(sessions), total, clock.instant()));
    }

    Optional<Quote> quoteFor(UUID patient) {
        return Optional.ofNullable(quotes.get(patient)).filter(quote -> fresh(quote.at()));
    }

    void clearQuote(UUID patient) {
        quotes.remove(patient);
    }

    void cancellation(UUID patient, UUID appointmentId) {
        sweep(cancellations);
        cancellations.put(patient, new Cancellation(appointmentId, clock.instant()));
    }

    Optional<Cancellation> cancellationFor(UUID patient) {
        return Optional.ofNullable(cancellations.get(patient))
                .filter(pending -> fresh(pending.at()));
    }

    void clearCancellation(UUID patient) {
        cancellations.remove(patient);
    }

    private boolean fresh(Instant at) {
        return at.plus(TTL).isAfter(clock.instant());
    }

    // Bounded: an abandoned chat must not leak.
    private void sweep(Map<UUID, ? extends Held> held) {
        if (held.size() < MAX_ENTRIES) {
            return;
        }
        held.values().removeIf(entry -> !fresh(entry.at()));
    }

    interface Held {
        Instant at();
    }

    record Quote(List<AddSessionRequest> sessions, BigDecimal total, Instant at) implements Held {
    }

    record Cancellation(UUID appointmentId, Instant at) implements Held {
    }
}
