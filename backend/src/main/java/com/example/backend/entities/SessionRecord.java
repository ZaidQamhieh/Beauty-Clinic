package com.example.backend.entities;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Immutable;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

// Insert-only, enforced by trg_session_record_immutable. A correction is a new row
// pointing at the original.
@Entity
@Table(name = "session_record")
@Immutable
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SessionRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "session_id", nullable = false)
    private AppointmentSession session;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "author_user_id", nullable = false)
    private DoctorProfile author;

    @Column
    private String note;

    @Enumerated(EnumType.STRING)
    @Column(name = "skin_reaction", length = 20)
    private SkinReaction skinReaction;

    @Column(name = "follow_up_date")
    private LocalDate followUpDate;

    @OneToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "amends_record_id")
    private SessionRecord amends;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    private SessionRecord(
            AppointmentSession session,
            DoctorProfile author,
            String note,
            SkinReaction skinReaction,
            LocalDate followUpDate,
            SessionRecord amends
    ) {
        this.session = session;
        this.author = author;
        this.note = note;
        this.skinReaction = skinReaction;
        this.followUpDate = followUpDate;
        this.amends = amends;
    }

    public static SessionRecord initial(
            AppointmentSession session,
            DoctorProfile author,
            String note,
            SkinReaction skinReaction,
            LocalDate followUpDate
    ) {
        return new SessionRecord(
                Objects.requireNonNull(session),
                Objects.requireNonNull(author),
                note,
                skinReaction,
                followUpDate,
                null
        );
    }

    public SessionRecord amendedWith(
            DoctorProfile author,
            String note,
            SkinReaction skinReaction,
            LocalDate followUpDate
    ) {
        return new SessionRecord(
                this.session,
                Objects.requireNonNull(author),
                note,
                skinReaction,
                followUpDate,
                this
        );
    }

    public enum SkinReaction {
        NONE,
        MILD,
        MODERATE,
        SEVERE
    }
}
