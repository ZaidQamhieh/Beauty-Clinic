package com.example.backend.services;

import com.example.backend.entities.PatientProfile;

import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

// One shape for every clinical-intake activity payload.
final class ClinicalAnswers {

    static final String PREGNANT = "pregnantBreastfeeding";
    static final String SKIN_TYPE = "skinType";
    static final String SMOKING = "smokingStatus";
    static final String ALLERGIES = "allergies";
    static final String MEDICATIONS = "medications";
    static final String CONDITIONS = "chronicConditions";

    private ClinicalAnswers() {
    }

    // The fields patient_profile itself stores.
    static Map<String, Object> of(PatientProfile profile) {
        Map<String, Object> answers = new LinkedHashMap<>();
        answers.put(PREGNANT, profile.isPregnantBreastfeeding());
        answers.put(SKIN_TYPE, profile.getSkinType());
        answers.put(SMOKING, profile.getSmokingStatus());
        answers.put(ALLERGIES, profile.getAllergies());
        answers.put(MEDICATIONS, profile.getMedications());
        answers.put(CONDITIONS, profile.getChronicConditions());
        return canonical(answers);
    }

    // Sorted keys and values, so equal answers compare equal.
    static Map<String, Object> canonical(Map<String, Object> answers) {
        Map<String, Object> canonical = new TreeMap<>();

        if (answers == null) {
            return canonical;
        }

        answers.forEach((field, value) -> canonical.put(field, normalise(value)));
        return canonical;
    }

    // Enums become their name; lists sort so order is not a change.
    private static Object normalise(Object value) {
        if (value instanceof Enum<?> constant) {
            return constant.name();
        }

        if (value instanceof Collection<?> items) {
            List<String> names = new ArrayList<>();
            items.forEach(item -> names.add(text(item)));
            names.sort(String::compareTo);
            return names;
        }

        return value;
    }

    private static String text(Object item) {
        if (item instanceof Enum<?> constant) {
            return constant.name();
        }
        return item == null ? null : item.toString();
    }
}
