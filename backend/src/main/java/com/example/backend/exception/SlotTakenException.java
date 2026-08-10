package com.example.backend.exception;

// A booking that lost its slot between being offered one and confirming it.
public class SlotTakenException extends RuntimeException {

    public SlotTakenException(String message) {
        super(message);
    }
}
