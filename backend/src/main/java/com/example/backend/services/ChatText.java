package com.example.backend.services;

import java.util.Locale;

// Normalizes a message before any keyword match.
public final class ChatText {

    private ChatText() {
    }

    public static String normalize(String message) {
        if (message == null) {
            return "";
        }

        String text = message.toLowerCase(Locale.ROOT);
        StringBuilder out = new StringBuilder(text.length());

        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);

            // Arabic-Indic digits, so dates and times parse.
            if (c >= '٠' && c <= '٩') {
                out.append((char) ('0' + (c - '٠')));
                continue;
            }
            if (c >= '۰' && c <= '۹') {
                out.append((char) ('0' + (c - '۰')));
                continue;
            }

            // Tashkeel carries no meaning for matching.
            if (c >= 'ً' && c <= 'ْ') {
                continue;
            }

            switch (c) {
                case 'أ', 'إ', 'آ', 'ٱ' -> out.append('ا');
                case 'ة' -> out.append('ه');
                case 'ى' -> out.append('ي');
                default -> out.append(c);
            }
        }

        return out.toString().replaceAll("\\s+", " ").strip();
    }
}
