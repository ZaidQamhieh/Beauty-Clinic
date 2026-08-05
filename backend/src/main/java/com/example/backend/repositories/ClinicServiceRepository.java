package com.example.backend.repositories;

import com.example.backend.entities.ClinicService;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ClinicServiceRepository extends JpaRepository<ClinicService, UUID> {

    Sort BY_NAME = Sort.by("name");

    List<ClinicService> findByActiveTrue(Sort sort);
}
