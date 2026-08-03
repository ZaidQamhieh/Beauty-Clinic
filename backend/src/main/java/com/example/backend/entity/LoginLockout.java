package com.example.backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "login_lockouts")
@Getter
@Setter
@NoArgsConstructor
public class LoginLockout {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    // The attempted login identifier (email), not necessarily an existing account.
    @Column(nullable = false, unique = true)
    private String identifier;

    @Column(name = "failed_attempts", nullable = false)
    private int failedAttempts;

    // How many times this identifier has been locked out; drives the escalating duration.
    @Column(name = "lockout_strikes", nullable = false)
    private int lockoutStrikes;

    @Column(name = "locked_until")
    private Instant lockedUntil;

    public LoginLockout(String identifier) {
        this.identifier = identifier;
    }

    public boolean isLocked(Instant now) {
        return lockedUntil != null && lockedUntil.isAfter(now);
    }
}
