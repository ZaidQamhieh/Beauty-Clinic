package com.example.backend.dtos;

// What the bot says, and whether it acted.
public record ChatReply(
        String text,
        // True when this turn really wrote.
        boolean wrote
) {

    public static ChatReply of(String text) {
        return new ChatReply(text, false);
    }

    public ChatReply wrote(boolean didWrite) {
        return new ChatReply(text, didWrite);
    }
}
