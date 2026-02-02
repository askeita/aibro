package com.aibro.service;

import com.aibro.dto.*;
import com.aibro.model.BrainstormingSession;
import com.aibro.model.Contribution;
import com.aibro.repository.BrainstormingSessionRepository;
import com.aibro.repository.ContributionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;


@Service
@RequiredArgsConstructor
@Slf4j
/**
 * Service encapsulating business logic for creating, updating, ending, and
 * reporting on brainstorming sessions.
 */
public class BrainstormingSessionService {

    private final BrainstormingSessionRepository sessionRepository;
    private final ContributionRepository contributionRepository;
    private final AIService aiService;

    /**
     * Creates and persists a new brainstorming session.
     *
     * @param request the session creation payload
     * @return the created session representation
     */
    @Transactional
    public SessionResponse createSession(SessionCreateRequest request) {
        BrainstormingSession session = BrainstormingSession.builder()
                .sessionName(request.getSessionName())
                .startTime(LocalDateTime.now())
                .status(BrainstormingSession.SessionStatus.ACTIVE)
                .participants(request.getParticipants())
                .aiModel(request.getAiModel())
                .aiContributionFrequency(request.getAiContributionFrequency())
                .aiVoiceGender(request.getAiVoiceGender())
                                .objective(request.getObjective())
                .build();

        session = sessionRepository.save(session);
        log.info("Created new brainstorming session: {}", session.getId());

        return mapToResponse(session);
    }

    /**
     * Updates an existing brainstorming session.
     *
     * @param sessionId the ID of the session to update
     * @param request   the updated session data
     * @return the updated session representation
     */
    @Transactional
    public SessionResponse updateSession(Long sessionId, SessionCreateRequest request) {
        BrainstormingSession session = sessionRepository.findById(sessionId)
                                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Session not found"));

        session.setSessionName(request.getSessionName());
        session.setParticipants(request.getParticipants());
        session.setAiModel(request.getAiModel());
        session.setAiContributionFrequency(request.getAiContributionFrequency());
        session.setAiVoiceGender(request.getAiVoiceGender());
        session.setObjective(request.getObjective());

        session = sessionRepository.save(session);
        return mapToResponse(session);
    }

    /**
     * Marks a session as completed, generating its summary and full
     * transcript.
     *
     * @param sessionId the ID of the session to end
     * @param userId    the user identifier used to resolve API keys
     * @return the completed session representation
     */
    @Transactional
    public SessionResponse endSession(Long sessionId, String userId) {
        BrainstormingSession session = sessionRepository.findById(sessionId)
                                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Session not found"));

        session.setEndTime(LocalDateTime.now());
        session.setStatus(BrainstormingSession.SessionStatus.COMPLETED);

        // Generate summary
        List<Contribution> contributions = contributionRepository.findBySessionIdOrderByTimestampAsc(sessionId);
        String summary = aiService.generateSessionSummary(contributions, session.getAiModel(), userId, session.getObjective());
        session.setSummary(summary);

        // Generate full transcript
        String transcript = generateTranscript(contributions);
        session.setFullTranscript(transcript);

        session = sessionRepository.save(session);
        log.info("Ended brainstorming session: {}", sessionId);

        return mapToResponse(session);
    }

    /**
     * Retrieves a single session by its identifier.
     *
     * @param sessionId the session identifier
     * @return the session representation
     */
    public SessionResponse getSession(Long sessionId) {
        BrainstormingSession session = sessionRepository.findById(sessionId)
                                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Session not found"));
        return mapToResponse(session);
    }

    /**
     * Returns all sessions ordered by start time descending.
     *
     * @return the list of all sessions
     */
    public List<SessionResponse> getAllSessions() {
        return sessionRepository.findAllByOrderByStartTimeDesc().stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    /**
     * Returns all active sessions ordered by start time descending.
     *
     * @return the list of active sessions
     */
    public List<SessionResponse> getActiveSessions() {
        return sessionRepository.findByStatusOrderByStartTimeDesc(BrainstormingSession.SessionStatus.ACTIVE)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    /**
     * Builds a detailed report for the given session, including
     * contributions, statistics, and transcript.
     *
     * @param sessionId the session identifier
     * @return the session report payload
     */
    public SessionReportResponse getSessionReport(Long sessionId) {
        BrainstormingSession session = sessionRepository.findById(sessionId)
                                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Session not found"));

        List<Contribution> contributions = contributionRepository.findBySessionIdOrderByTimestampAsc(sessionId);
        List<ContributionResponse> contributionResponses = contributions.stream()
                .map(this::mapContributionToResponse)
                .collect(Collectors.toList());

        long humanContributions = contributions.stream()
                .filter(c -> c.getType() == Contribution.ContributionType.HUMAN)
                .count();

        long aiContributions = contributions.stream()
                .filter(c -> c.getType() == Contribution.ContributionType.AI)
                .count();

        long durationMinutes = 0;
        if (session.getEndTime() != null) {
            durationMinutes = Duration.between(session.getStartTime(), session.getEndTime()).toMinutes();
        }

        SessionReportResponse.SessionStatistics statistics = SessionReportResponse.SessionStatistics.builder()
                .totalContributions(contributions.size())
                .humanContributions((int) humanContributions)
                .aiContributions((int) aiContributions)
                .durationMinutes(durationMinutes)
                .build();

        return SessionReportResponse.builder()
                .sessionId(session.getId())
                .sessionName(session.getSessionName())
                .summary(session.getSummary())
                .contributions(contributionResponses)
                .fullTranscript(session.getFullTranscript())
                .statistics(statistics)
                .build();
    }

    /**
     * Adds a contribution to the specified session.
     *
     * @param sessionId  the session identifier
     * @param speaker    the speaker name
     * @param content    the contribution text
     * @param type       the contribution type (human or AI)
     * @param confidence optional confidence score (used for STT results)
     */
    @Transactional
    public void addContribution(Long sessionId, String speaker, String content, Contribution.ContributionType type, Double confidence) {
        BrainstormingSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new RuntimeException("Session not found"));

        Contribution contribution = Contribution.builder()
                .session(session)
                .speaker(speaker)
                .content(content)
                .timestamp(LocalDateTime.now())
                .type(type)
                .confidence(confidence)
                .build();

        contributionRepository.save(contribution);
        log.debug("Added contribution from {} to session {}", speaker, sessionId);
    }

    /**
     * Builds a human-readable transcript from the ordered list of
     * contributions.
     *
     * @param contributions the contributions for the session
     * @return the textual transcript
     */
    private String generateTranscript(List<Contribution> contributions) {
        StringBuilder transcript = new StringBuilder();
        for (Contribution contribution : contributions) {
            transcript.append(String.format("[%s] %s: %s\n",
                    contribution.getTimestamp().toString(),
                    contribution.getSpeaker(),
                    contribution.getContent()));
        }
        return transcript.toString();
    }

    /**
     * Maps an entity to its API response DTO.
     *
     * @param session the session entity
     * @return the mapped response DTO
     */
    private SessionResponse mapToResponse(BrainstormingSession session) {
        return SessionResponse.builder()
                .id(session.getId())
                .sessionName(session.getSessionName())
                .startTime(session.getStartTime())
                .endTime(session.getEndTime())
                .status(session.getStatus().name())
                .participants(session.getParticipants())
                .aiModel(session.getAiModel())
                .aiContributionFrequency(session.getAiContributionFrequency())
                .aiVoiceGender(session.getAiVoiceGender())
                .summary(session.getSummary())
                .objective(session.getObjective())
                .build();
    }

    /**
     * Maps a contribution entity to its API response DTO.
     *
     * @param contribution the contribution entity
     * @return the mapped response DTO
     */
    private ContributionResponse mapContributionToResponse(Contribution contribution) {
        return ContributionResponse.builder()
                .id(contribution.getId())
                .speaker(contribution.getSpeaker())
                .content(contribution.getContent())
                .timestamp(contribution.getTimestamp())
                .type(contribution.getType().name())
                .confidence(contribution.getConfidence())
                .build();
    }
}
