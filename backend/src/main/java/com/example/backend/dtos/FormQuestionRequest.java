package com.example.backend.dtos;

import com.example.backend.entities.FormQuestion;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

public record FormQuestionRequest(
        @NotBlank @Pattern(regexp = "[A-Za-z][A-Za-z0-9_]*") String fieldKey,
        @NotBlank @Size(max = 255) String label,
        @Size(max = 2000) String helpText,
        @NotNull FormQuestion.FieldType fieldType,
        boolean required,
        @Min(0) int displayOrder,
        List<FormOptionRequest> options
) {
    public record FormOptionRequest(
            @NotBlank @Size(max = 100) String value,
            @NotBlank @Size(max = 255) String label,
            @Min(0) int displayOrder
    ) {
    }
}
