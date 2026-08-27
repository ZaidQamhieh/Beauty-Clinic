package com.example.backend.entities;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "form_question")
@Getter
@Setter
@NoArgsConstructor
public class FormQuestion {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "form_key", nullable = false, length = 80)
    private String formKey;

    @Column(name = "field_key", nullable = false, length = 80)
    private String fieldKey;

    @Column(nullable = false)
    private String label;

    @Column(name = "help_text")
    private String helpText;

    @Enumerated(EnumType.STRING)
    @Column(name = "field_type", nullable = false, length = 30)
    private FieldType fieldType;

    @Column(nullable = false)
    private boolean required;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    @Enumerated(EnumType.STRING)
    @Column(name = "visible_for_gender", nullable = false, length = 10)
    private VisibleForGender visibleForGender = VisibleForGender.BOTH;

    @Column(nullable = false)
    private boolean active = true;

    @OneToMany(mappedBy = "question", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    private List<FormQuestionOption> options = new ArrayList<>();

    public enum FieldType {
        BOOLEAN,
        SINGLE_SELECT,
        MULTI_SELECT
    }

    public enum VisibleForGender {
        MALE,
        FEMALE,
        BOTH;

        public boolean shows(UserAccount.Gender gender) {
            if (this == BOTH) {
                return true;
            }

            return gender != null && name().equals(gender.name());
        }
    }
}
