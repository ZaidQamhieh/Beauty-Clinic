package com.example.backend.services;

import com.example.backend.dtos.ChatReply;
import com.example.backend.dtos.ChatRequest;
import com.example.backend.dtos.ChatTurn;
import com.example.backend.config.ClinicProperties;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

// Model talks, tools act, server decides.
@Service
@Slf4j
public class ChatService {

    private static final int MAX_HISTORY = 30;
    private static final int LOOKBEHIND = 24;

    // Seen just before a claim, cancels it.
    private static final List<String> NOT_A_CLAIM = List.of(
            "not ", "n't ", "never ", "once ", "after ", "when ",
            "shall i", "should i", "want me", "would you", "do you want",
            "لم ", "ما ", "مش ", "بدك", "بدها", "تحب", "بتحب", "احجزلك", "اذا ");

    // A success claim with no write lies.
    private static final List<String> COMPLETION_CLAIMS = List.of(
            "booked", "is confirmed", "have confirmed", "successfully cancel",
            "has been cancelled", "has been canceled",
            "تم الحجز", "تم حجز", "حجزت لك", "حجزنا لك", "تأكد الحجز", "تأكد حجزك",
            "تم الإلغاء", "تم إلغاء", "الغينا لك", "تم إلغاء موعدك");

    private final ChatClient chat;
    private final ClinicTools tools;
    private final MedicalGate medicalGate;
    private final ChatOutcome outcome;
    private final ClinicProperties clinic;
    private final Clock clock;

    public ChatService(ObjectProvider<ChatModel> model, ClinicTools tools, MedicalGate medicalGate,
                       ChatOutcome outcome, ClinicProperties clinic, Clock clock) {
        // No key means no chat, not death.
        ChatModel configured = model.getIfAvailable();
        this.chat = configured == null ? null : ChatClient.create(configured);
        this.tools = tools;
        this.medicalGate = medicalGate;
        this.outcome = outcome;
        this.clinic = clinic;
        this.clock = clock;
    }

    public ChatReply reply(ChatRequest request) {
        ChatLanguage language = ChatLanguage.of(request.message());

        if (chat == null) {
            return ChatReply.of(unavailable(language));
        }

        // Never answered by a model, ever.
        if (medicalGate.isMedical(request.message())) {
            return ChatReply.of(handoff(language));
        }

        long started = System.nanoTime();
        outcome.reset();

        try {
            String answer = chat.prompt()
                    .system(systemPrompt())
                    .messages(transcript(request))
                    .user(request.message())
                    .tools(tools)
                    .call()
                    .content();

            log.debug("chat answered in {}ms", (System.nanoTime() - started) / 1_000_000);

            String text = answer == null ? unavailable(language) : answer.strip();

            if (!outcome.wroteThisTurn() && claimsCompletion(text)) {
                log.warn("Model claimed completion with no write this turn: {}", text);
                text = notActuallyDone(language);
            }

            return ChatReply.of(text).wrote(outcome.wroteThisTurn());
        } catch (Exception failure) {
            log.warn("Chat failed: {}", failure.getMessage(), failure);
            return ChatReply.of(unavailable(language));
        } finally {
            outcome.clear();
        }
    }

    // Catches more, false alarms over lies.
    private boolean claimsCompletion(String text) {
        // Hamza and tashkeel must not hide it.
        String said = ChatText.normalize(text);
        return COMPLETION_CLAIMS.stream()
                .anyMatch(claim -> asserted(said, ChatText.normalize(claim)));
    }

    // Offers and denials are not claims.
    private boolean asserted(String text, String claim) {
        for (int at = text.indexOf(claim); at >= 0; at = text.indexOf(claim, at + 1)) {
            String before = text.substring(Math.max(0, at - LOOKBEHIND), at);
            if (NOT_A_CLAIM.stream().noneMatch(before::contains)) {
                return true;
            }
        }

        return false;
    }

    private String notActuallyDone(ChatLanguage language) {
        return language.arabic()
                ? "عذراً، ما قدرت أأكد هذا الإجراء فعلياً. خليني أعيد المحاولة."
                : "Sorry, I could not actually confirm that action. Let me try again.";
    }

    // The client keeps the conversation, not us.
    private List<Message> transcript(ChatRequest request) {
        List<ChatTurn> turns = request.historyOrEmpty();
        List<Message> messages = new ArrayList<>();

        turns.stream()
                .skip(Math.max(0, turns.size() - MAX_HISTORY))
                .filter(turn -> turn != null && turn.text() != null && !turn.text().isBlank())
                .forEach(turn -> messages.add(Boolean.TRUE.equals(turn.fromPatient())
                        ? new UserMessage(turn.text())
                        : new AssistantMessage(turn.text())));

        return messages;
    }

    private String systemPrompt() {
        LocalDate today = LocalDate.now(clock.withZone(clinic.zone()));

        return """
                You are Yasmine, the receptionist at a dermatology and aesthetics clinic.
                Today is %s, a %s, in %s, so tomorrow is %s. Reply in the patient's own \
                language, English or Arabic dialect, warmly and in two sentences at most.

                These are the only treatments the clinic offers, with their price and length:
                %s

                Quote a price only from that list, and never state a total yourself: only book \
                totals a visit. You do not know the clinic's opening hours, which doctors work \
                there, or what is free at any moment. Only findSlots knows, so never name a \
                time, a day or a doctor that a tool did not just return, and never say a day is \
                full without calling a tool. If a tool did not answer, say you could not check.

                Booking is two steps. Call book with confirmed=false, read the total back to \
                the patient, then wait. The moment they agree, call book again immediately with \
                confirmed=true; the clinic then books exactly what was quoted, so you do not \
                need to repeat the ids. Treat any short agreement as consent, in any language: \
                yes, yeah, ok, sure, go ahead, do it, اه, ايه, ايوا, نعم, تمام, اكيد, ماشي, \
                يلا, احجز. Never ask the same confirmation question twice; if you already asked \
                and they answered, book it. Cancelling works the same way: myVisits, then \
                cancel with confirmed=false, then confirmed=true. Never claim something is \
                booked or cancelled before the tool says so.

                Earlier turns show only what was said, not what the tools returned, so re-read \
                anything you need with a tool rather than trusting your own earlier wording.

                The clinic books up to %d days ahead. A patient may cancel until %d minutes \
                before the visit starts, and no later.

                You never give medical advice. If the patient asks whether a treatment is safe \
                for them, or mentions pregnancy, a medication, an allergy or a condition, tell \
                them the clinic's doctors will answer that and offer a consultation booking.

                You only ever act for the patient you are speaking to. If they ask you to book \
                or cancel for someone else, say you cannot.
                """.formatted(today, today.getDayOfWeek(), clinic.timezone(), today.plusDays(1),
                catalogue(), clinic.maxHorizonDays(), clinic.cancellationCutoffMinutes());
    }

    // Static facts, so no tool round trip.
    private String catalogue() {
        return Arrays.stream(TreatmentName.values())
                .map(treatment -> {
                    ClinicProperties.Tariff tariff = clinic.tariffFor(treatment);
                    return "- " + treatment.name() + ": "
                            + tariff.price().stripTrailingZeros().toPlainString()
                            + " " + clinic.currency()
                            + ", " + tariff.durationMinutes() + " minutes";
                })
                .collect(Collectors.joining("\n"));
    }

    private String handoff(ChatLanguage language) {
        return language.arabic()
                ? "هذا سؤال طبي وما بقدر أجاوب عليه. الأفضل استشارة العيادة قبل الحجز."
                : "That is a medical question and I cannot answer it. "
                + "Please speak to the clinic before booking.";
    }

    private String unavailable(ChatLanguage language) {
        return language.arabic()
                ? "ما قدرت أرد هلق. جربي بعد شوي."
                : "I could not answer just now. Please try again in a moment.";
    }
}
