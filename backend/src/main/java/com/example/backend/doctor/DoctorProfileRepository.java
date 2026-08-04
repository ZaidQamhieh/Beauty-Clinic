package com.example.backend.doctor;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface DoctorProfileRepository extends JpaRepository<DoctorProfile, UUID> {

    @Query("select d from DoctorProfile d join fetch d.user")
    List<DoctorProfile> withUser();

    @Query("""
            select d from DoctorProfile d
            join d.services s
            where s.id = :serviceId
            """)
    List<DoctorProfile> offering(@Param("serviceId") UUID serviceId);
}
