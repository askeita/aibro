package com.aibro.service;

import com.aibro.dto.ContributionResponse;
import com.aibro.dto.SessionCreateRequest;
import com.aibro.dto.SessionReportResponse;
import com.aibro.dto.SessionResponse;
import com.aibro.model.BrainstormingSession;
import com.aibro.model.Contribution;
import com.aibro.repository.BrainstormingSessionRepository;
import com.aibro.repository.ContributionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link BrainstormingSessionService} covering session
 * lifecycle management, contribution handling, and reporting.
 */
class BrainstormingSessionServiceTest {

    private BrainstormingSessionRepository sessionRepository;
    private ContributionRepository contributionRepository;
    private AIService aiService;
    private BrainstormingSessionService service;

        /**
         * Configures a {@link BrainstormingSessionService} with mocked
         * repositories and AI service before each test.
         */
        @BeforeEach
        void setUp() {
        sessionRepository = mock(BrainstormingSessionRepository.class);
        contributionRepository = mock(ContributionRepository.class);
        aiService = mock(AIService.class);
        service = new BrainstormingSessionService(sessionRepository, contributionRepository, aiService);
    }

        /**
         * Verifies that creating a session persists an entity and returns a
         * fully populated response DTO.
         */
        @Test
        void createSession_persistsAndReturnsResponse() {
        SessionCreateRequest request = SessionCreateRequest.builder()
                .sessionName("Test session")
                .participants(Arrays.asList("Alice", "Bob"))
                .aiModel("openai")
                .aiContributionFrequency(10)
                .aiVoiceGender("female")
                .objective("Brainstorm new ideas")
                .build();

        when(sessionRepository.save(any(BrainstormingSession.class))).thenAnswer(invocation -> {
            BrainstormingSession s = invocation.getArgument(0);
            s.setId(42L);
            return s;
        });

        SessionResponse response = service.createSession(request);

        assertThat(response.getId()).isEqualTo(42L);
        assertThat(response.getSessionName()).isEqualTo("Test session");
        assertThat(response.getParticipants()).containsExactly("Alice", "Bob");
        assertThat(response.getAiModel()).isEqualTo("openai");
        assertThat(response.getAiContributionFrequency()).isEqualTo(10);
        assertThat(response.getAiVoiceGender()).isEqualTo("female");
        assertThat(response.getObjective()).isEqualTo("Brainstorm new ideas");
        assertThat(response.getStatus()).isEqualTo(BrainstormingSession.SessionStatus.ACTIVE.name());
        assertThat(response.getStartTime()).isNotNull();
    }

        /**
         * Ensures that an existing session is updated with the incoming
         * request data when found.
         */
        @Test
        void updateSession_updatesFieldsWhenSessionExists() {
        BrainstormingSession existing = BrainstormingSession.builder()
                .id(1L)
                .sessionName("Old name")
                .participants(Arrays.asList("Alice"))
                .aiModel("claude")
                .aiContributionFrequency(5)
                .aiVoiceGender("male")
                .objective("Old objective")
                .status(BrainstormingSession.SessionStatus.ACTIVE)
                .startTime(LocalDateTime.now())
                .build();

        when(sessionRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(sessionRepository.save(any(BrainstormingSession.class))).thenAnswer(invocation -> invocation.getArgument(0));

        SessionCreateRequest update = SessionCreateRequest.builder()
                .sessionName("New name")
                .participants(Arrays.asList("Bob", "Carol"))
                .aiModel("openai")
                .aiContributionFrequency(15)
                .aiVoiceGender("female")
                .objective("New objective")
                .build();

        SessionResponse response = service.updateSession(1L, update);

        assertThat(response.getId()).isEqualTo(1L);
        assertThat(response.getSessionName()).isEqualTo("New name");
        assertThat(response.getParticipants()).containsExactly("Bob", "Carol");
        assertThat(response.getAiModel()).isEqualTo("openai");
        assertThat(response.getAiContributionFrequency()).isEqualTo(15);
        assertThat(response.getAiVoiceGender()).isEqualTo("female");
        assertThat(response.getObjective()).isEqualTo("New objective");
    }

        /**
         * Verifies that updating a non-existent session results in a
         * NOT_FOUND {@link ResponseStatusException}.
         */
        @Test
        void updateSession_throwsWhenSessionNotFound() {
        when(sessionRepository.findById(99L)).thenReturn(Optional.empty());

        SessionCreateRequest update = SessionCreateRequest.builder()
                .sessionName("Does not matter")
                .build();

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.updateSession(99L, update));

        assertThat(ex.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

        /**
         * Ensures that ending a session generates a summary and transcript,
         * updates status to COMPLETED, and sets an end time.
         */
        @Test
        void endSession_setsSummaryAndTranscriptAndMarksCompleted() {
        Long sessionId = 1L;
        String userId = "user1";

        BrainstormingSession session = BrainstormingSession.builder()
                .id(sessionId)
                .sessionName("Session")
                .startTime(LocalDateTime.of(2024, 1, 1, 10, 0))
                .status(BrainstormingSession.SessionStatus.ACTIVE)
                .aiModel("openai")
                .objective("Objective")
                .build();

        Contribution c1 = Contribution.builder()
                .id(10L)
                .session(session)
                .speaker("Alice")
                .content("Idea 1")
                .timestamp(LocalDateTime.of(2024, 1, 1, 10, 0))
                .type(Contribution.ContributionType.HUMAN)
                .build();

        Contribution c2 = Contribution.builder()
                .id(11L)
                .session(session)
                .speaker("Bob")
                .content("Idea 2")
                .timestamp(LocalDateTime.of(2024, 1, 1, 10, 5))
                .type(Contribution.ContributionType.AI)
                .build();

        List<Contribution> contributions = Arrays.asList(c1, c2);

        when(sessionRepository.findById(sessionId)).thenReturn(Optional.of(session));
        when(contributionRepository.findBySessionIdOrderByTimestampAsc(sessionId)).thenReturn(contributions);
        when(aiService.generateSessionSummary(contributions, "openai", userId, "Objective"))
                .thenReturn("Summary text");
        when(sessionRepository.save(any(BrainstormingSession.class))).thenAnswer(invocation -> invocation.getArgument(0));

        SessionResponse response = service.endSession(sessionId, userId);

        assertThat(response.getSummary()).isEqualTo("Summary text");
        assertThat(response.getStatus()).isEqualTo(BrainstormingSession.SessionStatus.COMPLETED.name());

        ArgumentCaptor<BrainstormingSession> captor = ArgumentCaptor.forClass(BrainstormingSession.class);
        verify(sessionRepository).save(captor.capture());
        BrainstormingSession saved = captor.getValue();

        assertThat(saved.getSummary()).isEqualTo("Summary text");
        assertThat(saved.getFullTranscript()).isEqualTo("[2024-01-01T10:00] Alice: Idea 1\n[2024-01-01T10:05] Bob: Idea 2\n");
        assertThat(saved.getStatus()).isEqualTo(BrainstormingSession.SessionStatus.COMPLETED);
        assertThat(saved.getEndTime()).isNotNull();
    }

        /**
         * Verifies that a detailed session report is built with contribution
         * responses and aggregate statistics.
         */
        @Test
        void getSessionReport_buildsStatisticsAndContributionResponses() {
        Long sessionId = 1L;

        BrainstormingSession session = BrainstormingSession.builder()
                .id(sessionId)
                .sessionName("Report session")
                .summary("Existing summary")
                .fullTranscript("Full transcript")
                .startTime(LocalDateTime.of(2024, 1, 1, 10, 0))
                .endTime(LocalDateTime.of(2024, 1, 1, 11, 0))
                .build();

        Contribution human1 = Contribution.builder()
                .id(1L)
                .speaker("Alice")
                .content("Idea 1")
                .timestamp(LocalDateTime.of(2024, 1, 1, 10, 5))
                .type(Contribution.ContributionType.HUMAN)
                .confidence(0.9)
                .build();

        Contribution human2 = Contribution.builder()
                .id(2L)
                .speaker("Bob")
                .content("Idea 2")
                .timestamp(LocalDateTime.of(2024, 1, 1, 10, 10))
                .type(Contribution.ContributionType.HUMAN)
                .confidence(0.8)
                .build();

        Contribution ai = Contribution.builder()
                .id(3L)
                .speaker("AI Assistant")
                .content("AI idea")
                .timestamp(LocalDateTime.of(2024, 1, 1, 10, 15))
                .type(Contribution.ContributionType.AI)
                .confidence(1.0)
                .build();

        List<Contribution> contributions = Arrays.asList(human1, human2, ai);

        when(sessionRepository.findById(sessionId)).thenReturn(Optional.of(session));
        when(contributionRepository.findBySessionIdOrderByTimestampAsc(sessionId)).thenReturn(contributions);

        SessionReportResponse report = service.getSessionReport(sessionId);

        assertThat(report.getSessionId()).isEqualTo(sessionId);
        assertThat(report.getSessionName()).isEqualTo("Report session");
        assertThat(report.getSummary()).isEqualTo("Existing summary");
        assertThat(report.getFullTranscript()).isEqualTo("Full transcript");

        assertThat(report.getContributions()).hasSize(3);
        ContributionResponse first = report.getContributions().get(0);
        assertThat(first.getId()).isEqualTo(1L);
        assertThat(first.getSpeaker()).isEqualTo("Alice");
        assertThat(first.getType()).isEqualTo("HUMAN");

        SessionReportResponse.SessionStatistics stats = report.getStatistics();
        assertThat(stats.getTotalContributions()).isEqualTo(3);
        assertThat(stats.getHumanContributions()).isEqualTo(2);
        assertThat(stats.getAiContributions()).isEqualTo(1);
        assertThat(stats.getDurationMinutes()).isEqualTo(60);
    }

        /**
         * Ensures that adding a contribution associates it with the session
         * and persists it with expected fields.
         */
        @Test
        void addContribution_savesContributionWithSession() {
        Long sessionId = 1L;

        BrainstormingSession session = BrainstormingSession.builder()
                .id(sessionId)
                .build();

        when(sessionRepository.findById(sessionId)).thenReturn(Optional.of(session));

        service.addContribution(sessionId, "Alice", "Idea", Contribution.ContributionType.HUMAN, 0.95);

        ArgumentCaptor<Contribution> captor = ArgumentCaptor.forClass(Contribution.class);
        verify(contributionRepository).save(captor.capture());
        Contribution saved = captor.getValue();

        assertThat(saved.getSession()).isEqualTo(session);
        assertThat(saved.getSpeaker()).isEqualTo("Alice");
        assertThat(saved.getContent()).isEqualTo("Idea");
        assertThat(saved.getType()).isEqualTo(Contribution.ContributionType.HUMAN);
        assertThat(saved.getConfidence()).isEqualTo(0.95);
        assertThat(saved.getTimestamp()).isNotNull();
    }

        /**
         * Verifies that adding a contribution to a non-existent session fails
         * with an appropriate exception.
         */
        @Test
        void addContribution_throwsWhenSessionNotFound() {
        when(sessionRepository.findById(123L)).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                service.addContribution(123L, "Alice", "Idea", Contribution.ContributionType.HUMAN, null));

        assertThat(ex.getMessage()).isEqualTo("Session not found");
    }
}
