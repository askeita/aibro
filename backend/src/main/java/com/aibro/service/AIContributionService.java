package com.aibro.service;

import com.aibro.dto.AINotificationMessage;
import com.aibro.model.BrainstormingSession;
import com.aibro.model.Contribution;
import com.aibro.repository.BrainstormingSessionRepository;
import com.aibro.repository.ContributionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;


@Service
@RequiredArgsConstructor
@Slf4j
/**
 * Orchestrates when and how the AI contributes to brainstorming sessions,
 * including probability-based triggering, WebSocket notifications, and
 * persistence of AI contributions.
 */
public class AIContributionService {

    private final BrainstormingSessionRepository sessionRepository;
    private final ContributionRepository contributionRepository;
    private final AIService aiService;
    private final SpeechService speechService;
    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Analyzes recent conversation and determines whether the AI should
     * contribute, then generates and broadcasts a contribution when
     * appropriate.
     *
     * @param sessionId    the session identifier
     * @param userId       the user identifier used to resolve API keys
     * @param languageCode optional language code passed to the AI service
     * @param forceAi      whether to force an AI turn regardless of
     *                     configured frequency
     */
    @Async
    public void evaluateAndContribute(Long sessionId, String userId, String languageCode, boolean forceAi) {
        try {
            BrainstormingSession session = sessionRepository.findById(sessionId).orElse(null);
            if (session == null || session.getStatus() != BrainstormingSession.SessionStatus.ACTIVE) {
                return;
            }

            // Get recent contributions (last 5 minutes)
            List<Contribution> recentContributions = contributionRepository
                    .findBySessionIdOrderByTimestampAsc(sessionId)
                    .stream()
                    .filter(c -> c.getTimestamp().isAfter(LocalDateTime.now().minusMinutes(5)))
                    .toList();

            if (recentContributions.isEmpty()) {
                log.debug("No recent contributions to analyze for session {}", sessionId);
                return;
            }

            // Determine if AI should contribute (based on frequency, context, and optional human override)
            boolean shouldContribute;
            if (forceAi) {
                shouldContribute = true;
            } else {
                Integer frequency = session.getAiContributionFrequency();
                if (frequency == null || frequency <= 0) {
                    // 0 or null means "never automatically contribute" (human decides)
                    shouldContribute = false;
                } else {
                    shouldContribute = decideIfShouldContribute(frequency);
                }
            }
            
            if (!shouldContribute) {
                log.debug("AI decided not to contribute to session {}", sessionId);
                return;
            }

            // Send signal notification (blue light/sound)
            sendSignalNotification(sessionId);

            // Wait a moment for dramatic effect
            Thread.sleep(2000);

            // Generate AI contribution
            String aiResponse = aiService.analyzeConversationAndContribute(
                    recentContributions,
                    session.getAiModel(),
                    userId,
                    languageCode,
                    session.getObjective()
            );

            if (aiResponse != null && !aiResponse.isEmpty()) {
                // Generate audio for the contribution
                byte[] audioData = speechService.textToSpeech(
                        aiResponse,
                        session.getAiVoiceGender(),
                        userId
                );

                // Save contribution
                Contribution aiContribution = Contribution.builder()
                        .session(session)
                        .speaker("AI Assistant")
                        .content(aiResponse)
                        .timestamp(LocalDateTime.now())
                        .type(Contribution.ContributionType.AI)
                        .confidence(1.0)
                        .build();

                contributionRepository.save(aiContribution);

                // Send contribution notification via WebSocket
                sendContributionNotification(sessionId, aiResponse, audioData);

                log.info("AI contributed to session {}: {}", sessionId, aiResponse);
            }

        } catch (Exception e) {
            log.error("Error in AI contribution evaluation: {}", e.getMessage(), e);
        }
    }

    /**
     * Decides stochastically whether the AI should contribute based on the
     * configured frequency.
     *
     * @param frequency the configured AI contribution frequency (1-20)
     * @return {@code true} if the AI should contribute, otherwise
     * {@code false}
     */
    private boolean decideIfShouldContribute(Integer frequency) {
        // Frequency is 1-20, where 20 is most frequent
        // Convert to probability (e.g., frequency 10 = 50% chance)
        int probability = frequency * 5; // frequency 20 = 100%, frequency 1 = 5%
        int random = ThreadLocalRandom.current().nextInt(100);
        return random < probability;
    }

    /**
     * Sends a pre-contribution signal notification (e.g. light or sound) to
     * clients connected to the session.
     *
     * @param sessionId the session identifier
     */
    private void sendSignalNotification(Long sessionId) {
        AINotificationMessage message = AINotificationMessage.builder()
                .sessionId(sessionId)
                .type("SIGNAL")
                .content("AI is about to contribute")
                .build();

        messagingTemplate.convertAndSend("/topic/session/" + sessionId + "/ai", message);
        log.debug("Sent signal notification for session {}", sessionId);
    }

    /**
     * Sends a WebSocket notification containing the AI contribution text and
     * optional audio.
     *
     * @param sessionId the session identifier
     * @param content   the AI contribution text
     * @param audioData the generated audio bytes (currently unused and not
     *                  stored)
     */
    private void sendContributionNotification(Long sessionId, String content, byte[] audioData) {
        // In a real implementation, you would save the audio file and provide a URL
        // For now, we'll send the text content
        AINotificationMessage message = AINotificationMessage.builder()
                .sessionId(sessionId)
                .type("CONTRIBUTION")
                .content(content)
                .audioUrl(null) // Would be a URL to the saved audio file
                .build();

        messagingTemplate.convertAndSend("/topic/session/" + sessionId + "/ai", message);
        log.debug("Sent contribution notification for session {}", sessionId);
    }
}
