package com.example.backend.repository;

import com.example.backend.entity.LoginLockout;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;

import jakarta.persistence.LockModeType;

import java.util.Optional;
import java.util.UUID;

public interface LoginLockoutRepository extends JpaRepository<LoginLockout, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<LoginLockout> findByIdentifier(String identifier);
}
