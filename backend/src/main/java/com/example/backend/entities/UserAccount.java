package com.example.backend.entities;

import com.example.backend.security.Role;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.SoftDelete;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Locale;
import java.util.UUID;

// One row per person. A role profile hangs off it.
@Entity
@Table(name = "user_account")
@SoftDelete
@Getter
@Setter
@NoArgsConstructor
public class UserAccount {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    // Not unique = true: uq_user_account_email is scoped to live rows, so a soft delete frees it.
    @Email
    @NotBlank
    @Column(nullable = false)
    private String email;

    @Column(length = 30)
    private String phone;

    // Null until claimed: reception registers walk-ins, who sit at INVITED.
    @Column(name = "password_hash")
    private String passwordHash;

    @NotBlank
    @Column(name = "first_name", nullable = false, length = 100)
    private String firstName;

    @NotBlank
    @Column(name = "last_name", nullable = false, length = 100)
    private String lastName;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private Gender gender;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private Role role;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AccountStatus status = AccountStatus.ACTIVE;

    @Column(name = "failed_login_count", nullable = false)
    private int failedLoginCount = 0;

    @Column(name = "lockout_strikes", nullable = false)
    private int lockoutStrikes = 0;

    @Column(name = "locked_until")
    private Instant lockedUntil;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    public UserAccount(String email, String passwordHash, String firstName, String lastName, Role role) {
        setEmail(email);
        this.passwordHash = passwordHash;
        this.firstName = firstName;
        this.lastName = lastName;
        this.role = role;
    }

    public void setEmail(String email) {
        if (email == null) {
            this.email = null;
            return;
        }
        this.email = email.trim().toLowerCase(Locale.ROOT);
    }

    public String fullName() {
        return firstName + " " + lastName;
    }

    public boolean isEnabled() {
        return status == AccountStatus.ACTIVE;
    }

    // Mirrors user_account_credentials: only this path may activate, so setStatus cannot break it.
    public void activateWith(String passwordHash) {
        if (passwordHash == null || passwordHash.isBlank()) {
            throw new IllegalArgumentException("An active account must have a password");
        }

        this.passwordHash = passwordHash;
        this.status = AccountStatus.ACTIVE;
    }

    public boolean isClaimed() {
        return passwordHash != null;
    }

    public boolean isLocked(Instant now) {
        return lockedUntil != null && lockedUntil.isAfter(now);
    }

    public enum Gender {
        MALE,
        FEMALE,
        OTHER
    }

    public enum AccountStatus {
        ACTIVE,
        INVITED,
        DEACTIVATED
    }
}
