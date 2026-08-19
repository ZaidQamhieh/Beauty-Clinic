package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.dtos.AddSessionRequest;
import com.example.backend.dtos.AppointmentResponse;
import com.example.backend.dtos.AppointmentSessionResponse;
import com.example.backend.dtos.BookAppointmentRequest;
import com.example.backend.dtos.FreeSlotQuery;
import com.example.backend.dtos.FreeSlotResponse;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

// The only things the model may do.
@Component
@Slf4j
@RequiredArgsConstructor
public class ClinicTools {

    private static final int MAX_SLOTS = 8;
    private static final int MAX_VISITS = 10;
    private static final int LOOKAHEAD_DAYS = 14;

    private final AppointmentService appointments;
    private final ClinicProperties clinic;
    private final CurrentUser currentUser;
    private final Clock clock;
    private final ChatOutcome outcome;
    private final ChatPending pending;

    @Tool(description = "List every treatment the clinic offers, with its price and how long it takes.")
    public String listTreatments() {
        StringBuilder out = new StringBuilder();

        for (TreatmentName treatment : TreatmentName.values()) {
            ClinicProperties.Tariff tariff = clinic.tariffFor(treatment);
            out.append(treatment.name())
                    .append(" | price ").append(money(tariff.price()))
                    .append(" | ").append(tariff.durationMinutes()).append(" minutes\n");
        }

        return out.toString().strip();
    }

    @Tool(description = "Find free appointment times for one treatment on one day. "
            + "Returns the times and which doctor is free, each with a practitionerUserId "
            + "and startTime. Call this before offering any time. When you later call book, "
            + "copy those two values character for character from this result. Never write "
            + "your own id from a doctor's name; if you do not have the exact value, call "
            + "findSlots again.")
    public String findSlots(
            @ToolParam(description = "Treatment name, exactly as listTreatments returns it")
            TreatmentName treatment,
            @ToolParam(description = "The day to search, as yyyy-MM-dd") String day) {

        LocalDate today = today();
        LocalDate date;
        try {
            date = LocalDate.parse(day, DateTimeFormatter.ISO_LOCAL_DATE);
        } catch (Exception notADate) {
            // Guessing today would answer another question.
            return "The day must be written as yyyy-MM-dd. Today is " + today
                    + ". Work out the date the patient means, then call findSlots again.";
        }

        String rejected = outOfRange(date, today);
        if (rejected != null) {
            return rejected;
        }

        List<FreeSlotResponse> slots = freeSlots(treatment, date);
        if (slots.isEmpty()) {
            return "No free times for " + treatment.name() + " on " + date
                    + ". Do not guess another day: call findNextAvailable to find the next one.";
        }

        return render(treatment, date, slots);
    }

    @Tool(description = "Find the first day with any free time for one treatment, searching "
            + "forward from a given day. Use it whenever the patient asks for the soonest "
            + "appointment, or after findSlots came back empty. Never guess a day yourself.")
    public String findNextAvailable(
            @ToolParam(description = "Treatment name, exactly as listTreatments returns it")
            TreatmentName treatment,
            @ToolParam(description = "The day to start searching from, as yyyy-MM-dd")
            String fromDay) {

        LocalDate today = today();
        LocalDate start;
        try {
            start = LocalDate.parse(fromDay, DateTimeFormatter.ISO_LOCAL_DATE);
        } catch (Exception notADate) {
            start = today;
        }

        if (start.isBefore(today)) {
            start = today;
        }

        String rejected = outOfRange(start, today);
        if (rejected != null) {
            return rejected;
        }

        LocalDate last = today.plusDays(clinic.maxHorizonDays());
        for (int ahead = 0; ahead < LOOKAHEAD_DAYS; ahead++) {
            LocalDate date = start.plusDays(ahead);
            if (date.isAfter(last)) {
                break;
            }

            List<FreeSlotResponse> slots = freeSlots(treatment, date);
            if (!slots.isEmpty()) {
                return render(treatment, date, slots);
            }
        }

        return "Nothing free for " + treatment.name() + " in the " + LOOKAHEAD_DAYS
                + " days from " + start + ". Offer to look further ahead, and name no day.";
    }

    @Tool(description = "Book one or more treatments for the patient you are speaking to. "
            + "Call it first with confirmed=false to get the total back, read that to the "
            + "patient, and only call it again with confirmed=true after they agree. The "
            + "confirming call books exactly what was quoted, so its picks are ignored and "
            + "may be sent empty.")
    public String book(
            @ToolParam(description = "The slots to quote, each named by the short code that "
                    + "findSlots just printed beside it, such as S1 or S3. Use only codes from "
                    + "the answer you just received, never a doctor's name, a time, or a code "
                    + "you remember from earlier.")
            List<Pick> picks,
            @ToolParam(description = "True only after the patient has agreed to the total")
            boolean confirmed) {

        UUID patient = currentUser.requireId();
        log.info("Chat book called: confirmed={}, picks={}", confirmed,
                picks == null ? 0 : picks.size());

        // The patient confirms, never the model.
        if (confirmed && pending.quoteFor(patient).isPresent()) {
            return confirmBooking(patient);
        }

        if (picks == null || picks.isEmpty()) {
            return "Nothing to quote: no treatments were given. Call findSlots, then book "
                    + "with confirmed=false and the slot it returned.";
        }

        List<AddSessionRequest> sessions = new ArrayList<>();
        for (Pick pick : picks) {
            String code = pick.slot();
            Optional<AddSessionRequest> known = code == null
                    ? Optional.empty()
                    : pending.offered(patient, code);

            if (known.isEmpty()) {
                log.info("Chat booking used an unknown slot code: {}", code);
                return "There is no slot " + code + ". Call findSlots again and pass one of "
                        + "the codes it prints, such as S1, exactly as written.";
            }

            sessions.add(known.get());
        }

        BigDecimal total = totalOf(sessions);
        pending.quote(patient, sessions, total);

        // Confirm with no quote: quote now instead.
        if (confirmed) {
            log.info("Chat confirm arrived with no quote; quoting {} instead", total);
            return "NOT BOOKED. Nothing had been quoted, so this is the quote, not a booking. "
                    + "The total is " + money(total) + ". Say only that total to the patient "
                    + "and ask them to confirm, then call book with confirmed=true again.";
        }

        return review(sessions, total);
    }

    // Null when every pick came from findSlots.
    private String firstPickNotFree(List<AddSessionRequest> sessions) {
        for (AddSessionRequest session : sessions) {
            LocalDate day = LocalDate.ofInstant(session.startTime(), clinic.zone());
            List<FreeSlotResponse> free = freeSlots(session.treatmentName(), day);

            boolean real = free.stream()
                    .anyMatch(slot -> slot.practitionerUserId().equals(session.practitionerUserId())
                            && slot.startTime().equals(session.startTime()));

            if (!real) {
                log.info("Pick rejected: doctor={} start={}; free were {}",
                        session.practitionerUserId(), session.startTime(),
                        free.stream()
                                .map(slot -> slot.practitionerUserId() + "@" + slot.startTime())
                                .toList());
                return "That doctor is not free for " + session.treatmentName().name()
                        + " at that time, so nothing was quoted. Call findSlots again for "
                        + day + " and copy a practitionerUserId and startTime from its"
                        + " answer exactly, without retyping them.";
            }
        }

        return null;
    }

    @Tool(description = "The patient's own upcoming appointments: what is booked, when, what "
            + "each treatment costs and the visit's total, plus the id needed to cancel one. "
            + "Call this whenever they ask what they have booked or what it costs.")
    public String myVisits() {
        List<AppointmentResponse> visits = upcoming();

        if (visits.isEmpty()) {
            return "The patient has no upcoming appointments. Describe no visit.";
        }

        StringBuilder out = new StringBuilder();
        visits.forEach(visit -> {
            out.append("id ").append(visit.id())
                    .append(" | ").append(visit.scheduledAt())
                    .append('\n');

            BigDecimal total = BigDecimal.ZERO;
            for (AppointmentSessionResponse session : visit.sessions()) {
                ClinicProperties.Tariff tariff = clinic.tariffFor(session.treatmentName());
                total = total.add(tariff.price());
                out.append("   ").append(session.treatmentName().name())
                        .append(" at ").append(time(session.startTime()))
                        .append(" | ").append(money(tariff.price()))
                        .append('\n');
            }

            out.append("   visit total ").append(money(total)).append('\n');
        });

        return out.toString().strip();
    }

    @Tool(description = "Cancel one of the patient's own appointments. Call with confirmed=false "
            + "first to see what would be cancelled, and only pass confirmed=true once they say "
            + "yes. The confirming call cancels exactly the visit that was read back.")
    public String cancel(
            @ToolParam(description = "The appointment id from myVisits") String appointmentId,
            @ToolParam(description = "True only after the patient has agreed to cancel")
            boolean confirmed) {

        UUID patient = currentUser.requireId();

        if (confirmed) {
            return confirmCancel(patient);
        }

        UUID id;
        try {
            id = UUID.fromString(appointmentId);
        } catch (IllegalArgumentException | NullPointerException notAnId) {
            return "That is not an appointment id. Call myVisits first.";
        }

        Optional<AppointmentResponse> visit = upcoming().stream()
                .filter(candidate -> candidate.id().equals(id))
                .findFirst();

        if (visit.isEmpty()) {
            return "That id is not in the patient's upcoming visits. Call myVisits again "
                    + "and use an id from it.";
        }

        pending.cancellation(patient, id);
        return "NOT CANCELLED YET. Read this back and ask them to confirm: "
                + visit.get().scheduledAt() + ", " + treatmentsIn(visit.get())
                + ". As soon as they agree in any language, call cancel again with "
                + "confirmed=true. Never ask them twice.";
    }

    private String confirmBooking(UUID patient) {
        Optional<ChatPending.Quote> quote = pending.quoteFor(patient);
        if (quote.isEmpty()) {
            return "Nothing has been quoted to this patient. Call book with confirmed=false "
                    + "first, read the total back, and only confirm after they agree.";
        }

        try {
            // The signed-in patient, never the model.
            AppointmentResponse booked = appointments.book(
                    new BookAppointmentRequest(patient, quote.get().sessions(), null));

            pending.clearQuote(patient);
            outcome.markWritten();
            log.info("Chat booked appointment {}", booked.id());
            return "Booked. Appointment " + booked.id() + " starts " + booked.scheduledAt() + ".";
        } catch (ResponseStatusException refused) {
            // A dead quote never confirms twice.
            pending.clearQuote(patient);
            log.info("Chat booking refused: {}", refused.getReason());
            return "Could not book: " + refused.getReason()
                    + " Call findSlots again and quote a new time.";
        }
    }

    private String confirmCancel(UUID patient) {
        Optional<ChatPending.Cancellation> asked = pending.cancellationFor(patient);
        if (asked.isEmpty()) {
            return "No cancellation has been read back to this patient. Call myVisits, then "
                    + "cancel with confirmed=false, and only confirm after they agree.";
        }

        UUID id = asked.get().appointmentId();
        try {
            appointments.cancel(id);
            pending.clearCancellation(patient);
            outcome.markWritten();
            log.info("Chat cancelled appointment {}", id);
            return "Cancelled appointment " + id + ".";
        } catch (ResponseStatusException refused) {
            pending.clearCancellation(patient);
            log.info("Chat cancel refused: {}", refused.getReason());
            return "Could not cancel: " + refused.getReason();
        }
    }

    private List<AppointmentResponse> upcoming() {
        return appointments.readOwnUpcoming(PageRequest.of(0, MAX_VISITS)).getContent();
    }

    private List<FreeSlotResponse> freeSlots(TreatmentName treatment, LocalDate date) {
        return appointments.freeSlots(
                new FreeSlotQuery(treatment, date, null, null, List.of(), null));
    }

    private String render(TreatmentName treatment, LocalDate date, List<FreeSlotResponse> slots) {
        StringBuilder out = new StringBuilder("Free times for " + treatment.name() + " on "
                + date + " (" + date.getDayOfWeek() + "):\n");

        Map<String, AddSessionRequest> offered = new LinkedHashMap<>();
        List<FreeSlotResponse> shown = slots.stream().limit(MAX_SLOTS).toList();

        for (int at = 0; at < shown.size(); at++) {
            FreeSlotResponse slot = shown.get(at);
            String code = "S" + (at + 1);

            offered.put(code, new AddSessionRequest(
                    slot.practitionerUserId(), treatment, slot.startTime()));

            out.append(code)
                    .append(" | ").append(time(slot.startTime()))
                    .append(" | doctor ").append(slot.practitionerName())
                    .append('\n');
        }

        pending.offer(currentUser.requireId(), offered);
        out.append("To book, pass the slot code exactly as written, for example S1.");

        return out.toString().strip();
    }

    // Neither the past nor past the horizon.
    private String outOfRange(LocalDate date, LocalDate today) {
        if (date.isBefore(today)) {
            return "That day has passed. Today is " + today + ".";
        }

        LocalDate last = today.plusDays(clinic.maxHorizonDays());
        if (date.isAfter(last)) {
            return "The clinic only books up to " + clinic.maxHorizonDays()
                    + " days ahead, so no later than " + last + ".";
        }

        return null;
    }

    private BigDecimal totalOf(List<AddSessionRequest> sessions) {
        return sessions.stream()
                .map(session -> clinic.tariffFor(session.treatmentName()).price())
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    // Priced here; the model never adds.
    private String review(List<AddSessionRequest> sessions, BigDecimal total) {
        StringBuilder out = new StringBuilder("NOT BOOKED YET. Read this back to the patient "
                + "and ask them to confirm. As soon as they agree in any language, for example "
                + "yes, ok, sure, go ahead, aywa, ah, tamam, akkid, naam, call book AGAIN with "
                + "confirmed=true. Never ask them twice.\n");

        for (AddSessionRequest session : sessions) {
            ClinicProperties.Tariff tariff = clinic.tariffFor(session.treatmentName());
            out.append(session.treatmentName().name())
                    .append(" | ").append(time(session.startTime()))
                    .append(" | ").append(tariff.durationMinutes()).append(" minutes")
                    .append(" | ").append(money(tariff.price()))
                    .append('\n');
        }

        return out.append("Total ").append(money(total)).toString();
    }

    private String money(BigDecimal amount) {
        return amount.stripTrailingZeros().toPlainString() + " " + clinic.currency();
    }

    private String treatmentsIn(AppointmentResponse visit) {
        return visit.sessions().stream()
                .map(AppointmentSessionResponse::treatmentName)
                .map(Enum::name)
                .reduce((left, right) -> left + ", " + right)
                .orElse("");
    }

    // Accepts an offset, or clinic local time.
    private Instant parseStart(String startTime) {
        try {
            return Instant.parse(startTime);
        } catch (DateTimeParseException noOffset) {
            return LocalDateTime.parse(startTime).atZone(clinic.zone()).toInstant();
        }
    }

    private LocalDate today() {
        return LocalDate.now(clock.withZone(clinic.zone()));
    }

    private String time(Instant moment) {
        return moment.atZone(clinic.zone()).toLocalTime().toString();
    }

    /// One slot, named by its code.
    public record Pick(String slot) {
    }
}
