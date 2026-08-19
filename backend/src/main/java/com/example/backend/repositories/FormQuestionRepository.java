package com.example.backend.repositories;

import com.example.backend.entities.FormQuestion;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface FormQuestionRepository extends JpaRepository<FormQuestion, UUID> {

    List<FormQuestion> findByFormKeyOrderByDisplayOrderAsc(String formKey);

    List<FormQuestion> findByFormKeyAndActiveTrueOrderByDisplayOrderAsc(String formKey);

    boolean existsByFormKeyAndFieldKey(String formKey, String fieldKey);
}
