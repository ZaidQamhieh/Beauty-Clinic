package com.example.backend.doctor;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface DoctorRepository extends JpaRepository<Doctor, UUID> {

    @Query("select d from Doctor d join fetch d.user")
    List<Doctor> withUser();

    @Query("""
            select d from Doctor d
            join d.services s
            where s.id = :serviceId
            """)
    List<Doctor> offering(@Param("serviceId") UUID serviceId);
}
