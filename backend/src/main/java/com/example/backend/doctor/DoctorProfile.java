package com.example.backend.doctor;

import com.example.backend.catalogue.ClinicService;
import com.example.backend.user.UserAccount;
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

import java.util.LinkedHashSet;
import java.util.Set;
import java.util.UUID;

@Entity
@Table(name = "doctor_profile")
@Getter
@Setter
@NoArgsConstructor
public class DoctorProfile {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @MapsId
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id")
    private UserAccount user;

    @Column(length = 120)
    private String specialty;

    @Column(name = "license_number", length = 60)
    private String licenseNumber;

    @Column
    private String bio;

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
            name = "doctor_service",
            joinColumns = @JoinColumn(name = "doctor_id"),
            inverseJoinColumns = @JoinColumn(name = "service_id")
    )
    private Set<ClinicService> services = new LinkedHashSet<>();

    public DoctorProfile(UserAccount user) {
        this.user = user;
    }
}
