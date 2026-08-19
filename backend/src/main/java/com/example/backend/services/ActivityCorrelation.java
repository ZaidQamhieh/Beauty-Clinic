package com.example.backend.services;

import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.UUID;

// Ties the rows one operation writes together.
@Component
public class ActivityCorrelation {

    private static final ThreadLocal<Scope> CURRENT = new ThreadLocal<>();

    // Nested calls share the outermost id.
    public void begin() {
        Scope scope = CURRENT.get();

        if (scope == null) {
            CURRENT.set(new Scope(UUID.randomUUID()));
            return;
        }

        scope.depth++;
    }

    // Always paired with begin in a finally.
    public void end() {
        Scope scope = CURRENT.get();

        if (scope == null) {
            return;
        }

        if (scope.depth == 0) {
            CURRENT.remove();
            return;
        }

        scope.depth--;
    }

    public Optional<UUID> current() {
        Scope scope = CURRENT.get();
        return scope == null ? Optional.empty() : Optional.of(scope.id);
    }

    private static final class Scope {

        private final UUID id;
        private int depth;

        private Scope(UUID id) {
            this.id = id;
        }
    }
}
