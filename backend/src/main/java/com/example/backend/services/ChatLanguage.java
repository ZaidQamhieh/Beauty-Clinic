package com.example.backend.services;

// Reply language, decided by the script used.
public enum ChatLanguage {
    EN,
    AR;

    public static ChatLanguage of(String message) {
        if (message == null) {
            return EN;
        }

        return message.codePoints().anyMatch(ChatLanguage::isArabic) ? AR : EN;
    }

    private static boolean isArabic(int codePoint) {
        return (codePoint >= 0x0600 && codePoint <= 0x06FF)
                || (codePoint >= 0x0750 && codePoint <= 0x077F)
                || (codePoint >= 0xFB50 && codePoint <= 0xFEFF);
    }

    public boolean arabic() {
        return this == AR;
    }
}
