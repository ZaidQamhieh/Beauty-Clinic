package com.example.backend.controllers;

import com.example.backend.dtos.ChatReply;
import com.example.backend.dtos.ChatRequest;
import com.example.backend.security.access.Authenticated;
import com.example.backend.services.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

// The bot answers as the caller, never above them.
@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chat;

    @PostMapping
    @Authenticated
    public ChatReply send(@Valid @RequestBody ChatRequest request) {
        return chat.reply(request);
    }
}
