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

    //Identifies which user owns this session. Eager, and not by choice:
    //Hibernate rejects a lazy to-one pointing at a @SoftDelete entity, because
    //the proxy would have to be resolved before anyone could tell whether the
    //row behind it still counts as present.
    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name= "user_id", nullable = false)
    private UserAccount user;

    //Only the hash is stored, the client receives the raw token
    @Column(name = "token_hash", nullable = false, unique = true, length = 64)
    private String tokenHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

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

    // Narrow, rotation-only setters: the row's identity (id, user) never
    // changes after creation, only what a rotation refreshes.
    public void rotateTo(String tokenHash, Instant expiresAt) {
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
    }

}
