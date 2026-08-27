package com.example.backend.dtos;

import com.example.backend.entities.FormQuestion;
import com.example.backend.entities.FormQuestionOption;

import java.util.List;
import java.util.UUID;

public record FormQuestionResponse(
        UUID id,
        String fieldKey,
        String label,
        String helpText,
        String fieldType,
        boolean required,
        int displayOrder,
        String visibleForGender,
        boolean active,
        List<Option> options
) {
    public record Option(
            UUID id,
            String value,
            String label,
            int displayOrder,
            boolean active
    ) {
    }

    public static FormQuestionResponse of(FormQuestion question, boolean includeInactiveOptions) {
        return new FormQuestionResponse(
                question.getId(),
                question.getFieldKey(),
                question.getLabel(),
                question.getHelpText(),
                question.getFieldType().name(),
                question.isRequired(),
                question.getDisplayOrder(),
                question.getVisibleForGender().name(),
                question.isActive(),
                question.getOptions().stream()
                        .filter(option -> includeInactiveOptions || option.isActive())
                        .map(option -> new Option(
                                option.getId(),
                                option.getValue(),
                                option.getLabel(),
                                option.getDisplayOrder(),
                                option.isActive()
                        ))
                        .toList()
        );
    }
}
