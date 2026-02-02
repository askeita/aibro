package com.aibro.controller;

import com.aibro.dto.SessionCreateRequest;
import com.aibro.dto.SessionReportResponse;
import com.aibro.dto.SessionResponse;
import com.aibro.service.BrainstormingSessionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;


@RestController
@RequestMapping("/api/sessions")
@RequiredArgsConstructor
/**
 * REST controller that exposes CRUD operations and reporting endpoints for
 * brainstorming sessions.
 */
public class BrainstormingSessionController {

    private final BrainstormingSessionService sessionService;

    /**
     * Creates a new brainstorming session.
     *
     * @param request the session creation payload
     * @return the created session representation
     */
    @PostMapping
    public ResponseEntity<SessionResponse> createSession(@RequestBody SessionCreateRequest request) {
        SessionResponse response = sessionService.createSession(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Updates an existing brainstorming session.
     *
     * @param sessionId the ID of the session to update
     * @param request   the updated session data
     * @return the updated session representation
     */
    @PutMapping("/{sessionId}")
    public ResponseEntity<SessionResponse> updateSession(
            @PathVariable Long sessionId,
            @RequestBody SessionCreateRequest request) {
        SessionResponse response = sessionService.updateSession(sessionId, request);
        return ResponseEntity.ok(response);
    }

    /**
     * Ends a brainstorming session, generating its summary and transcript.
     *
     * @param sessionId the ID of the session to end
     * @param userId    the user requesting the end, used to select API keys
     * @return the completed session representation
     */
    @PostMapping("/{sessionId}/end")
    public ResponseEntity<SessionResponse> endSession(
            @PathVariable Long sessionId,
            @RequestParam String userId) {
        SessionResponse response = sessionService.endSession(sessionId, userId);
        return ResponseEntity.ok(response);
    }

    /**
     * Retrieves a single brainstorming session by its ID.
     *
     * @param sessionId the session identifier
     * @return the session representation
     */
    @GetMapping("/{sessionId}")
    public ResponseEntity<SessionResponse> getSession(@PathVariable Long sessionId) {
        SessionResponse response = sessionService.getSession(sessionId);
        return ResponseEntity.ok(response);
    }

    /**
     * Returns all sessions ordered by start time.
     *
     * @return the list of all sessions
     */
    @GetMapping
    public ResponseEntity<List<SessionResponse>> getAllSessions() {
        List<SessionResponse> response = sessionService.getAllSessions();
        return ResponseEntity.ok(response);
    }

    /**
     * Returns only active sessions ordered by start time.
     *
     * @return the list of active sessions
     */
    @GetMapping("/active")
    public ResponseEntity<List<SessionResponse>> getActiveSessions() {
        List<SessionResponse> response = sessionService.getActiveSessions();
        return ResponseEntity.ok(response);
    }

    /**
     * Generates a report for the specified session, including statistics and
     * transcript.
     *
     * @param sessionId the session identifier
     * @return the session report payload
     */
    @GetMapping("/{sessionId}/report")
    public ResponseEntity<SessionReportResponse> getSessionReport(@PathVariable Long sessionId) {
        SessionReportResponse response = sessionService.getSessionReport(sessionId);
        return ResponseEntity.ok(response);
    }
}
