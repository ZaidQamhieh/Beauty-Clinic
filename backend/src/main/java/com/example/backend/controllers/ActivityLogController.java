package com.example.backend.controllers;

import com.example.backend.dtos.ActivityLogResponse;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityCategory;
import com.example.backend.security.access.AdminOnly;
import com.example.backend.services.ActivityLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;

@RestController
@RequestMapping("/api/activity-logs")
@RequiredArgsConstructor
@AdminOnly
public class ActivityLogController {
    private final ActivityLogService activityLogs;

    @GetMapping
    public Page<ActivityLogResponse> list(
            @RequestParam(required = false) ActivityAction action,
            @RequestParam(required = false) ActivityCategory category,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(required = false) String search,
            Pageable pageable
    ) {
        return activityLogs.search(action, category, from, to, search, pageable);
    }
}
