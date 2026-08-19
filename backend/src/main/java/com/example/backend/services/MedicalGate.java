package com.example.backend.services;

import org.springframework.stereotype.Component;

import java.util.List;
import java.util.regex.Pattern;

// Runs before the model, always.
@Component
public class MedicalGate {

    private static final List<String> WORDS = List.of(
            "side effect", "pregnan", "breastfeed", "nursing", "allerg",
            "medication", "medicine", "diabet", "blood thinner", "infection",
            "accutane", "isotretinoin", "keloid",
            "حامل", "حمل", "مرضع", "رضاعه", "حساسيه", "حساسية", "دواء",
            "ادويه", "ادوية", "سكري", "التهاب", "اعراض", "عوارض");

    // Stems run forward, so bound the start.
    private static final List<Pattern> STEMS = WORDS.stream()
            .map(word -> Pattern.compile("(?<!\\p{L})" + Pattern.quote(ChatText.normalize(word))))
            .toList();

    public boolean isMedical(String message) {
        if (message == null || message.isBlank()) {
            return false;
        }

        String normalized = ChatText.normalize(message);
        return STEMS.stream().anyMatch(stem -> stem.matcher(normalized).find());
    }
}
