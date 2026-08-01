package com.example.backend.security;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.security.authorization.event.AuthorizationDeniedEvent;
import org.springframework.stereotype.Component;

@Component
@Slf4j
class AccessDeniedListener {

    @EventListener
    void onDenied(AuthorizationDeniedEvent<?> event) {
        log.warn("Access denied: principal={}", event.getAuthentication().get().getName());
    }
}
