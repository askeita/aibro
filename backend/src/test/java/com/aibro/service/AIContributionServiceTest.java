package com.aibro.service;

import com.aibro.dto.AINotificationMessage;
import com.aibro.model.BrainstormingSession;
import com.aibro.model.Contribution;
import com.aibro.repository.BrainstormingSessionRepository;
import com.aibro.repository.ContributionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link AIContributionService} validating that forced AI
 * contributions are generated, persisted, and broadcast to clients.
 */
class AIContributionServiceTest {

    private BrainstormingSessionRepository sessionRepository;
    private ContributionRepository contributionRepository;
    private AIService aiService;
    private SpeechService speechService;
    private SimpMessagingTemplate messagingTemplate;
    private AIContributionService service;

    /**
     * Initializes {@link AIContributionService} with mocked dependencies
     * before each test.
     */
    @BeforeEach
    void setUp() {
        sessionRepository = mock(BrainstormingSessionRepository.class);
        contributionRepository = mock(ContributionRepository.class);
        aiService = mock(AIService.class);
        speechService = mock(SpeechService.class);
        messagingTemplate = mock(SimpMessagingTemplate.class);

        service = new AIContributionService(sessionRepository, contributionRepository, aiService, speechService, messagingTemplate);
    }

    /**
     * Ensures that when AI contribution is forced, the service generates
     * an AI response, saves it as a contribution, sends WebSocket
     * notifications, and optionally synthesizes audio.
     */
    @Test
    void evaluateAndContribute_generatesAndSavesContributionWhenForced() throws Exception {
        Long sessionId = 1L;
        String userId = "user1";
        String languageCode = "en-US";

        BrainstormingSession session = BrainstormingSession.builder()
                .id(sessionId)
                .status(BrainstormingSession.SessionStatus.ACTIVE)
                .aiModel("openai")
                .aiVoiceGender("female")
                .objective("Grow business")
                .build();

        Contribution recent = Contribution.builder()
                .id(10L)
                .speaker("Alice")
                .content("Idea")
                .timestamp(LocalDateTime.now().minusMinutes(1))
                .type(Contribution.ContributionType.HUMAN)
                .build();

        List<Contribution> contributions = Collections.singletonList(recent);

        when(sessionRepository.findById(sessionId)).thenReturn(Optional.of(session));
        when(contributionRepository.findBySessionIdOrderByTimestampAsc(sessionId)).thenReturn(contributions);
        when(aiService.analyzeConversationAndContribute(anyList(), eq("openai"), eq(userId), eq(languageCode), eq("Grow business")))
                .thenReturn("AI response");
        when(speechService.textToSpeech("AI response", "female", userId)).thenReturn(new byte[] {1, 2, 3});

        service.evaluateAndContribute(sessionId, userId, languageCode, true);

        // Verify that a signal and a contribution notification were sent
        verify(messagingTemplate, atLeastOnce()).convertAndSend(eq("/topic/session/" + sessionId + "/ai"), any(AINotificationMessage.class));

        // Verify that a contribution was saved
        ArgumentCaptor<Contribution> captor = ArgumentCaptor.forClass(Contribution.class);
        verify(contributionRepository).save(captor.capture());
        Contribution saved = captor.getValue();

        assertThat(saved.getSession()).isEqualTo(session);
        assertThat(saved.getSpeaker()).isEqualTo("AI Assistant");
        assertThat(saved.getContent()).isEqualTo("AI response");
        assertThat(saved.getType()).isEqualTo(Contribution.ContributionType.AI);
        assertThat(saved.getConfidence()).isEqualTo(1.0);
        assertThat(saved.getTimestamp()).isNotNull();

        verify(speechService).textToSpeech("AI response", "female", userId);
    }
}
