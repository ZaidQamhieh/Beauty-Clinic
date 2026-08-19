package com.example.backend.repositories;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.example.backend.entities.RefreshToken;
import com.example.backend.entities.UserAccount;

import jakarta.persistence.LockModeType;

import java.util.Optional;
import java.util.UUID;

public interface RefreshTokenRepository
        extends JpaRepository<RefreshToken, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<RefreshToken> findByTokenHash(String tokenHash);

    @Query("select t from RefreshToken t where t.tokenHash = :tokenHash")
    Optional<RefreshToken> peekByTokenHash(@Param("tokenHash") String tokenHash);

    // One read per request: the session is live and belongs to the account the token names.
    @Query("""
            select u from RefreshToken t
            join t.user u
            where t.id = :sessionId
              and u.id = :userId
            """)
    Optional<UserAccount> findSessionOwner(
            @Param("sessionId") UUID sessionId,
            @Param("userId") UUID userId
    );
}