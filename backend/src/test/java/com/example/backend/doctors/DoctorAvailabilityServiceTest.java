package com.example.backend.doctors;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.dtos.CreateDoctorAvailabilityRequest;
import com.example.backend.dtos.DoctorAvailabilityDayStatus;
import com.example.backend.dtos.DoctorAvailabilityResponse;
import com.example.backend.dtos.SplitDoctorAvailabilityRequest;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.DoctorAvailabilityRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.example.backend.services.DoctorAvailabilityService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
class DoctorAvailabilityServiceTest extends AbstractIntegrationTest {

    private static final LocalDate TODAY = LocalDate.now();
    private static final LocalDate TOMORROW = TODAY.plusDays(1);
    private static final LocalDate WEEK_LATER = TODAY.plusDays(7);

    @Autowired
    private DoctorAvailabilityService availabilityService;

    @Autowired
    private DoctorAvailabilityRepository availabilityRepository;

    @Autowired
    private DoctorProfileRepository doctorProfileRepository;

    @Autowired
    private UserAccountRepository userAccountRepository;

    @Autowired
    private TransactionTemplate transactions;

    @Test
    void addRegularAvailabilityHappyPath() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest request = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.REGULAR,
                DayOfWeek.MONDAY,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TODAY,
                null,
                false);

        DoctorAvailabilityResponse response = availabilityService.add(doctorId, request);

        assertThat(response).isNotNull();
        assertThat(response.kind()).isEqualTo(AvailabilityKind.REGULAR);
        assertThat(response.dayOfWeek()).isEqualTo(DayOfWeek.MONDAY);
    }

    @Test
    void addModifiedAvailabilityWithDateRange() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest request = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.MODIFIED,
                null,
                LocalTime.of(8, 0),
                LocalTime.of(12, 0),
                TODAY,
                TODAY,
                false);

        DoctorAvailabilityResponse response = availabilityService.add(doctorId, request);

        assertThat(response.kind()).isEqualTo(AvailabilityKind.MODIFIED);
        assertThat(response.effectiveFrom()).isEqualTo(TODAY);
        assertThat(response.effectiveTo()).isEqualTo(TODAY);
    }

    @Test
    void addVacationRequiresDateRange() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest request = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.VACATION,
                null,
                null,
                null,
                TODAY,
                WEEK_LATER,
                false);

        DoctorAvailabilityResponse response = availabilityService.add(doctorId, request);

        assertThat(response.kind()).isEqualTo(AvailabilityKind.VACATION);
    }

    @Test
    void addThrowsForMissingDoctor() {
        UUID fakeId = UUID.randomUUID();

        CreateDoctorAvailabilityRequest request = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.REGULAR,
                DayOfWeek.MONDAY,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TODAY,
                null,
                false);

        assertThatThrownBy(() -> availabilityService.add(fakeId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void addRejectsRedundantOverlappingWindow() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest existing = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.REGULAR,
                DayOfWeek.MONDAY,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TODAY,
                null,
                false);

        availabilityService.add(doctorId, existing);

        CreateDoctorAvailabilityRequest duplicate = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.REGULAR,
                DayOfWeek.MONDAY,
                LocalTime.of(10, 0),
                LocalTime.of(15, 0),
                TODAY,
                null,
                false);

        assertThatThrownBy(() -> availabilityService.add(doctorId, duplicate))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void addWithConfirmationSkipsShadowCheck() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest vacation = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.VACATION,
                null,
                null,
                null,
                TODAY,
                TODAY,
                true);

        DoctorAvailabilityResponse response = availabilityService.add(doctorId, vacation);

        assertThat(response.kind()).isEqualTo(AvailabilityKind.VACATION);
    }

    @Test
    void listFiltersVacationForNonStaff() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest vacation = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.VACATION,
                null,
                null,
                null,
                TODAY,
                TODAY,
                true);

        availabilityService.add(doctorId, vacation);

        List<DoctorAvailabilityResponse> response = availabilityService.list(doctorId);

        assertThat(response).isEmpty();
    }

    @Test
    void updateChangesWindowDetails() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest original = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.MODIFIED,
                null,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TODAY,
                TODAY,
                false);

        DoctorAvailabilityResponse created = availabilityService.add(doctorId, original);

        CreateDoctorAvailabilityRequest updated = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.MODIFIED,
                null,
                LocalTime.of(8, 0),
                LocalTime.of(18, 0),
                TODAY,
                TODAY,
                false);

        DoctorAvailabilityResponse response = availabilityService.update(
                doctorId, created.id(), updated);

        assertThat(response.startTime()).isEqualTo(LocalTime.of(8, 0));
        assertThat(response.endTime()).isEqualTo(LocalTime.of(18, 0));
    }

    @Test
    void updateThrowsForMissingAvailability() {
        UUID doctorId = createDoctor();
        UUID fakeId = UUID.randomUUID();

        CreateDoctorAvailabilityRequest request = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.MODIFIED,
                null,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TODAY,
                TODAY,
                false);

        assertThatThrownBy(() -> availabilityService.update(doctorId, fakeId, request))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void splitTruncatesHistoryAndAddsNewSegment() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest original = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.MODIFIED,
                null,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TODAY,
                WEEK_LATER,
                false);

        DoctorAvailabilityResponse created = availabilityService.add(doctorId, original);

        LocalDate splitDate = TODAY.plusDays(3);

        CreateDoctorAvailabilityRequest newSegment = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.MODIFIED,
                null,
                LocalTime.of(10, 0),
                LocalTime.of(16, 0),
                splitDate,
                WEEK_LATER,
                false);

        SplitDoctorAvailabilityRequest split = new SplitDoctorAvailabilityRequest(
                splitDate, newSegment);

        List<DoctorAvailabilityResponse> response = availabilityService.split(
                doctorId, created.id(), split);

        assertThat(response).hasSize(2);
        assertThat(response.get(0).effectiveTo()).isEqualTo(splitDate.minusDays(1));
        assertThat(response.get(1).effectiveFrom()).isEqualTo(splitDate);
    }

    @Test
    void splitDeletesFutureWithoutNewSegment() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest original = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.MODIFIED,
                null,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TOMORROW,
                WEEK_LATER,
                false);

        DoctorAvailabilityResponse created = availabilityService.add(doctorId, original);

        LocalDate splitDate = TODAY.plusDays(3);

        SplitDoctorAvailabilityRequest split = new SplitDoctorAvailabilityRequest(
                splitDate, null);

        List<DoctorAvailabilityResponse> response = availabilityService.split(
                doctorId, created.id(), split);

        assertThat(response).hasSize(1);
        assertThat(response.get(0).effectiveTo()).isEqualTo(splitDate.minusDays(1));
    }

    @Test
    void splitRejectsSplitDateBeforeEffectiveFrom() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest original = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.MODIFIED,
                null,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TODAY,
                WEEK_LATER,
                false);

        DoctorAvailabilityResponse created = availabilityService.add(doctorId, original);

        SplitDoctorAvailabilityRequest split = new SplitDoctorAvailabilityRequest(
                TODAY.minusDays(1), null);

        assertThatThrownBy(() -> availabilityService.split(doctorId, created.id(), split))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void removeDeletesAvailability() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest request = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.MODIFIED,
                null,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TOMORROW,
                TOMORROW,
                false);

        DoctorAvailabilityResponse created = availabilityService.add(doctorId, request);

        availabilityService.remove(doctorId, created.id());

        assertThat(availabilityRepository.findById(created.id())).isEmpty();
    }

    @Test
    void removeThrowsForMissingAvailability() {
        UUID doctorId = createDoctor();
        UUID fakeId = UUID.randomUUID();

        assertThatThrownBy(() -> availabilityService.remove(doctorId, fakeId))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void calendarStatusReturnsDayStatusForDateRange() {
        UUID doctorId = createDoctor();

        CreateDoctorAvailabilityRequest request = new CreateDoctorAvailabilityRequest(
                AvailabilityKind.REGULAR,
                DayOfWeek.MONDAY,
                LocalTime.of(9, 0),
                LocalTime.of(17, 0),
                TODAY,
                null,
                false);

        availabilityService.add(doctorId, request);

        LocalDate monday = TODAY;
        while (monday.getDayOfWeek() != DayOfWeek.MONDAY) {
            monday = monday.plusDays(1);
        }

        LocalDate endDate = monday.plusDays(6);

        List<DoctorAvailabilityDayStatus> response = availabilityService.calendarStatus(
                doctorId, monday, endDate);

        assertThat(response).hasSize(7);
    }

    @Test
    void calendarStatusRejectsInvertedDateRange() {
        UUID doctorId = createDoctor();

        assertThatThrownBy(() -> availabilityService.calendarStatus(
                doctorId, TOMORROW, TODAY))
                .isInstanceOf(ResponseStatusException.class)
                .extracting("statusCode").isEqualTo(HttpStatus.BAD_REQUEST);
    }

    private UUID createDoctor() {
        return transactions.execute(status -> {
            String unique = UUID.randomUUID().toString().substring(0, 8);
            UserAccount account = userAccountRepository.save(
                    new UserAccount("doctor-" + unique + "@example.com", "hash",
                            "Dr", "Test", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(account);
            doctorProfileRepository.save(profile);
            return profile.getUserId();
        });
    }
}
