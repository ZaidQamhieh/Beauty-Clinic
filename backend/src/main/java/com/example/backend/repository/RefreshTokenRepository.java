package com.example.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.example.backend.entity.RefreshToken;

import jakarta.persistence.LockModeType;

import java.util.Optional;
import java.util.UUID;

public interface RefreshTokenRepository
        extends JpaRepository<RefreshToken, UUID> {

    // Locked: used by rotation, which races concurrent rotations/logouts
    // of the same token.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<RefreshToken> findByTokenHash(String tokenHash);

    // Unlocked: used by logout, a simple find-then-delete that isn't
    // racing anything the way rotation is.
    @Query("select t from RefreshToken t where t.tokenHash = :tokenHash")
    Optional<RefreshToken> findUnlockedByTokenHash(@Param("tokenHash") String tokenHash);
}