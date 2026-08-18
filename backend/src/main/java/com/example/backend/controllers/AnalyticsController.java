package com.example.backend.controllers;

import com.example.backend.dtos.AdminAnalyticsResponse;
import com.example.backend.dtos.DoctorAnalyticsResponse;
import com.example.backend.security.CurrentUser;
import com.example.backend.security.access.AdminOnly;
import com.example.backend.security.access.DoctorOnly;
import com.example.backend.services.AnalyticsService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;

@RestController
@RequiredArgsConstructor
public class AnalyticsController {

    private final AnalyticsService analyticsService;
    private final CurrentUser currentUser;

    @GetMapping("/api/admin/analytics")
    @AdminOnly
    public AdminAnalyticsResponse getAnalytics(
            @RequestParam(name = "from", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(name = "to", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to
    ) {
        return analyticsService.calculateAnalytics(from, to);
    }

    @GetMapping("/api/doctor/analytics")
    @DoctorOnly
    public DoctorAnalyticsResponse getDoctorAnalytics(
            @RequestParam(name = "from", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(name = "to", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to
    ) {
        return analyticsService.calculateDoctorAnalytics(currentUser.requireId(), from, to);
    }
}
