package com.example.backend.entities;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.MapsId;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.SoftDelete;
import org.hibernate.type.SqlTypes;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Entity
@Table(name = "doctor")
@SoftDelete
@Getter
@Setter
@NoArgsConstructor
public class Doctor {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    // Eager, and not by choice: Hibernate rejects a lazy to-one pointing at a
    // @SoftDelete entity, because the proxy would have to be resolved before
    // anyone could tell whether the row behind it still counts as present.
    @MapsId
    @OneToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "user_id")
    private UserAccount user;

    @Column(length = 120)
    private String specialty;

    @Column(name = "license_number", length = 60)
    private String licenseNumber;

    @Column
    private String bio;

    // Soft-deleted like every table: dropping a treatment flags the join row
    // instead of removing it, and re-offering it later inserts a fresh one.
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
            name = "doctor_service",
            joinColumns = @JoinColumn(name = "doctor_id"),
            inverseJoinColumns = @JoinColumn(name = "service_id")
    )
    @SoftDelete
    private Set<ClinicService> services = new LinkedHashSet<>();

    // Weekly schedule as jsonb, read and written whole.
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(nullable = false, columnDefinition = "jsonb")
    private List<WorkingHours> availability = new ArrayList<>();

    public Doctor(UserAccount user) {
        this.user = user;
    }
}
