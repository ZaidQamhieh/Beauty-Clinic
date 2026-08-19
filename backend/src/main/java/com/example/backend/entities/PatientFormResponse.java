package com.example.backend.entities;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

@Entity
@Table(name = "patient_form_response")
@Getter
@Setter
@NoArgsConstructor
public class PatientFormResponse {

    @EmbeddedId
    private Id id;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "answers", nullable = false, columnDefinition = "jsonb")
    private JsonNode answers;

    @Embeddable
    @Getter
    @Setter
    @NoArgsConstructor
    public static class Id implements Serializable {

        @Column(name = "patient_user_id", nullable = false)
        private UUID patientUserId;

        @Column(name = "form_key", nullable = false, length = 80)
        private String formKey;

        public Id(UUID patientUserId, String formKey) {
            this.patientUserId = patientUserId;
            this.formKey = formKey;
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) {
                return true;
            }
            if (!(other instanceof Id that)) {
                return false;
            }
            return Objects.equals(patientUserId, that.patientUserId)
                    && Objects.equals(formKey, that.formKey);
        }

        @Override
        public int hashCode() {
            return Objects.hash(patientUserId, formKey);
        }
    }
}
