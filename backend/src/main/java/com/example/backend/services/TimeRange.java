package com.example.backend.services;

import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

// A half-open wall-clock span. A doctor's open hours are these added up and cut down.
public record TimeRange(LocalTime start, LocalTime end) {

    public TimeRange {
        if (!end.isAfter(start)) {
            throw new IllegalArgumentException("end must be after start");
        }
    }

    // Overlapping and touching spans collapse, so two windows over one hour offer it once.
    public static List<TimeRange> union(List<TimeRange> ranges) {
        List<TimeRange> merged = new ArrayList<>();

        for (TimeRange range : ranges.stream().sorted(Comparator.comparing(TimeRange::start)).toList()) {
            if (merged.isEmpty()) {
                merged.add(range);
                continue;
            }

            TimeRange last = merged.get(merged.size() - 1);

            if (range.start().isAfter(last.end())) {
                merged.add(range);
            } else if (range.end().isAfter(last.end())) {
                merged.set(merged.size() - 1, new TimeRange(last.start(), range.end()));
            }
        }

        return merged;
    }

    // Every cut applies to everything left, so a cut through the middle splits a span in two.
    public static List<TimeRange> subtract(List<TimeRange> from, List<TimeRange> cuts) {
        // Copied: with no cuts this returned the caller's list, which callers then mutate.
        List<TimeRange> remaining = new ArrayList<>(from);

        for (TimeRange cut : cuts) {
            List<TimeRange> next = new ArrayList<>();
            remaining.forEach(range -> next.addAll(range.minus(cut)));
            remaining = next;
        }

        return remaining;
    }

    public boolean covers(LocalTime from, LocalTime to) {
        return !from.isBefore(start) && !to.isAfter(end);
    }

    private List<TimeRange> minus(TimeRange cut) {
        if (!cut.start().isBefore(end) || !cut.end().isAfter(start)) {
            return List.of(this);
        }

        List<TimeRange> left = new ArrayList<>();

        if (start.isBefore(cut.start())) {
            left.add(new TimeRange(start, cut.start()));
        }
        if (cut.end().isBefore(end)) {
            left.add(new TimeRange(cut.end(), end));
        }

        return left;
    }
}
