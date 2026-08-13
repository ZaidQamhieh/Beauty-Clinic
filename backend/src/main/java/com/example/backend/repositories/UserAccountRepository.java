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

    // Mirrors uq_user_account_phone, which is scoped to live rows, so a soft delete
    // frees it.
    boolean existsByPhone(String phone);

    List<UserAccount> findAllByRoleInOrderByLastNameAscFirstNameAsc(Collection<Role> roles);

    // Locked: concurrent failed logins must not lose an increment.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from UserAccount u where lower(u.email) = lower(:email)")
    Optional<UserAccount> lockByEmail(@Param("email") String email);
}
