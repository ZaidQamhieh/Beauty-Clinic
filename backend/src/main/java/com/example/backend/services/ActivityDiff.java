package com.example.backend.services;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

// Changed keys only; snapshots bloat the log.
public final class ActivityDiff {

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .registerModule(new JavaTimeModule());

    private ActivityDiff() {
    }

    public static Change between(Map<String, Object> before, Map<String, Object> after) {
        Set<String> keys = new LinkedHashSet<>(before.keySet());
        keys.addAll(after.keySet());

        ObjectNode oldValues = MAPPER.createObjectNode();
        ObjectNode newValues = MAPPER.createObjectNode();

        for (String key : keys) {
            Object was = before.get(key);
            Object now = after.get(key);

            if (Objects.equals(was, now)) {
                continue;
            }

            oldValues.set(key, MAPPER.valueToTree(was));
            newValues.set(key, MAPPER.valueToTree(now));
        }

        return new Change(oldValues, newValues);
    }

    // Empty means nothing happened worth logging.
    public record Change(ObjectNode oldValues, ObjectNode newValues) {

        public boolean isEmpty() {
            return oldValues.isEmpty();
        }

        public JsonNode before() {
            return isEmpty() ? null : oldValues;
        }

        public JsonNode after() {
            return isEmpty() ? null : newValues;
        }
    }
}
