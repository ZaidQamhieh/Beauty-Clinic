package com.example.backend.repositories;

import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public interface DoctorAvailabilityRepository extends JpaRepository<DoctorAvailability, UUID> {

    List<DoctorAvailability> findByDoctorUserId(UUID doctorUserId);

    // Only the rows that can speak for this date; overrides accumulate and never expire on read.
    @Query("""
            select a from DoctorAvailability a
            where a.doctor.userId = :doctorUserId
              and a.effectiveFrom <= :date
              and (a.effectiveTo is null or a.effectiveTo >= :date)
              and (a.kind = :overrideKind or a.dayOfWeek = :dayOfWeek)
            """)
    List<DoctorAvailability> findEffectiveOn(
            @Param("doctorUserId") UUID doctorUserId,
            @Param("date") LocalDate date,
            @Param("dayOfWeek") DayOfWeek dayOfWeek,
            @Param("overrideKind") AvailabilityKind overrideKind);
}
