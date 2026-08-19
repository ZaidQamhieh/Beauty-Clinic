package com.example.backend.entities;

import java.time.Instant;
import java.util.UUID;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.SoftDelete;

@Entity
@Table(name = "refresh_token")
@SoftDelete
@Getter
@NoArgsConstructor
public class RefreshToken {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    // Eager, not by choice: Hibernate rejects a lazy to-one into a @SoftDelete entity.
    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name= "user_id", nullable = false)
    private UserAccount user;

    // Only the hash is stored; length and uniqueness describe the column, not the SHA-256 value.
    @Column(name = "token_hash", nullable = false, length = 255)
    private String tokenHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    // Filled by the column default, so the application reads it and never writes it.
    @Column(name = "issued_at", nullable = false, insertable = false, updatable = false)
    private Instant issuedAt;

    // Revocation is explicit; unwritten, logging out was indistinguishable from a deleted row.
    @Column(name = "revoked_at")
    private Instant revokedAt;

    public RefreshToken(
        UserAccount user,
        String tokenHash,
        Instant expiresAt
    ) {
        this.user = user;
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
    }

    public boolean isExpired(Instant now) {
        return !expiresAt.isAfter(now);
    }

    public boolean isRevoked() {
        return revokedAt != null;
    }

    public void revoke(Instant at) {
        this.revokedAt = at;
    }

    // Rotation-only: id and user never change after creation.
    public void rotateTo(String tokenHash, Instant expiresAt) {
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
    }

}
