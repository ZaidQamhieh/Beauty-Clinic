package com.example.backend.services;

import org.springframework.stereotype.Component;

// Truth for the turn, not the model.
@Component
public class ChatOutcome {

    private final ThreadLocal<Boolean> wrote = new ThreadLocal<>();

    void reset() {
        wrote.set(false);
    }

    void markWritten() {
        wrote.set(true);
    }

    boolean wroteThisTurn() {
        return Boolean.TRUE.equals(wrote.get());
    }

    void clear() {
        wrote.remove();
    }
}
