package com.example.backend.dtos;

// AVAILABLE: the resolved merge (recurring settles first, overrides win) leaves open time.
// UNAVAILABLE: at least one rule is effective that day, but the resolved merge is empty.
// NONE: no rule at all - recurring or override - is effective that day.
public enum DayAvailabilityStatus {
    AVAILABLE,
    UNAVAILABLE,
    NONE
}
