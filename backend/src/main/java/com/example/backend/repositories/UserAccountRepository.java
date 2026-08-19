package com.example.backend.repositories;

import com.example.backend.entities.UserAccount;
import com.example.backend.security.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UserAccountRepository extends JpaRepository<UserAccount, UUID> {

    Optional<UserAccount> findByEmailIgnoreCase(String email);

    // Mirrors uq_user_account_phone, scoped to live rows.
    boolean existsByPhone(String phone);

    List<UserAccount> findAllByRoleInOrderByLastNameAscFirstNameAsc(Collection<Role> roles);

    // Backs activity-log search by name or email.
    @Query("""
            select u.id from UserAccount u
            where lower(u.email) like :term
               or lower(u.firstName) like :term
               or lower(u.lastName) like :term
               or lower(concat(u.firstName, ' ', u.lastName)) like :term
            """)
    List<UUID> findIdsMatching(@Param("term") String term);

    // Locked: concurrent failures must not lose increments.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from UserAccount u where lower(u.email) = lower(:email)")
    Optional<UserAccount> lockByEmail(@Param("email") String email);
}
