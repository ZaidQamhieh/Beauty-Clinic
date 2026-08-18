package com.example.backend.repositories;

import com.example.backend.entities.DoctorProfile;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface DoctorProfileRepository extends JpaRepository<DoctorProfile, UUID> {

    // Held for the booking transaction, so turnover holds.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select d from DoctorProfile d where d.userId = :userId")
    Optional<DoctorProfile> lockForBooking(@Param("userId") UUID userId);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"user"})
    @Query("select d from DoctorProfile d")
    java.util.List<DoctorProfile> findAllWithUser();
}
