package com.example.backend.repositories;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.example.backend.entities.RefreshToken;
import com.example.backend.entities.UserAccount;

import jakarta.persistence.LockModeType;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RefreshTokenRepository
        extends JpaRepository<RefreshToken, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<RefreshToken> findByTokenHash(String tokenHash);

    @Query("select t from RefreshToken t where t.tokenHash = :tokenHash")
    Optional<RefreshToken> peekByTokenHash(@Param("tokenHash") String tokenHash);

    // Live sessions only; deleted rows excluded.
    @Query("select t from RefreshToken t where t.user.id = :userId")
    List<RefreshToken> findLiveForUser(@Param("userId") UUID userId);

    // Native: JPQL delete would only soft-delete.
    @Modifying
    @Query(value = """
            delete from refresh_token
            where deleted = true or expires_at < :before
            """, nativeQuery = true)
    int deleteExpiredBefore(@Param("before") Instant before);

    // One read: session live, owned by account.
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