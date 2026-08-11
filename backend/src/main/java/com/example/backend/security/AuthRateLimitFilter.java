package com.example.backend.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

// Bounds one address against the endpoints that carry no token. The account lockout bounds
// guesses at one password; this bounds breadth, which that never sees. In memory, so it
// resets on restart and counts per instance.
class AuthRateLimitFilter extends OncePerRequestFilter {

    // Not logout: a 429 there strands a live session.
    private static final Set<String> GUARDED = Set.of(
            "/api/auth/register",
            "/api/auth/login",
            "/api/auth/refresh"
    );

    // Past this, expired windows are swept, so many sources cannot grow the map unbounded.
    private static final int PRUNE_ABOVE = 10_000;

    private final Map<String, Window> windows = new ConcurrentHashMap<>();
    private final int maxRequests;
    private final Duration window;

    AuthRateLimitFilter(RateLimitProperties properties) {
        this.maxRequests = properties.maxRequests();
        this.window = properties.window();
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !GUARDED.contains(request.getRequestURI());
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request, HttpServletResponse response, FilterChain chain
    ) throws ServletException, IOException {

        // Per endpoint too, so refresh cannot starve login.
        if (withinLimit(request.getRequestURI() + "|" + request.getRemoteAddr())) {
            chain.doFilter(request, response);
            return;
        }

        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        response.getWriter().write("""
                {"type":"about:blank","title":"Too Many Requests","status":429,\
                "detail":"Too many attempts from this address; try again shortly"}""");
    }

    private boolean withinLimit(String bucket) {
        Instant now = Instant.now();
        pruneIfLarge(now);

        Window current = windows.compute(bucket, (key, existing) -> {
            if (existing == null || hasExpired(existing, now)) {
                return Window.startedAt(now);
            }
            existing.count().incrementAndGet();
            return existing;
        });

        return current.count().get() <= maxRequests;
    }

    private void pruneIfLarge(Instant now) {
        if (windows.size() <= PRUNE_ABOVE) {
            return;
        }
        windows.values().removeIf(tracked -> hasExpired(tracked, now));
    }

    private boolean hasExpired(Window tracked, Instant now) {
        return tracked.startedAt().plus(window).isBefore(now);
    }

    private record Window(Instant startedAt, AtomicInteger count) {

        static Window startedAt(Instant now) {
            return new Window(now, new AtomicInteger(1));
        }
    }
}
