package com.aibro.controller;

import com.aibro.dto.SessionCreateRequest;
import com.aibro.dto.SessionReportResponse;
import com.aibro.dto.SessionResponse;
import com.aibro.service.BrainstormingSessionService;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

import java.util.Collections;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link BrainstormingSessionController} covering basic
 * CRUD-style session lifecycle and reporting endpoints.
 */
class BrainstormingSessionControllerTest {

    private final BrainstormingSessionService sessionService = mock(BrainstormingSessionService.class);
    private final BrainstormingSessionController controller = new BrainstormingSessionController(sessionService);

    /**
     * Verifies that creating a session delegates to the service and returns
     * the created session response.
     */
    @Test
    void createSession_returnsResponseFromService() {
        SessionCreateRequest request = SessionCreateRequest.builder()
                .sessionName("Test")
                .build();

        SessionResponse expected = SessionResponse.builder()
                .id(1L)
                .sessionName("Test")
                .build();

        when(sessionService.createSession(any(SessionCreateRequest.class))).thenReturn(expected);

        ResponseEntity<SessionResponse> response = controller.createSession(request);

        verify(sessionService).createSession(request);
        assertThat(response.getBody()).isEqualTo(expected);
    }

    /**
     * Verifies that updating a session returns the updated session data from
     * the service.
     */
    @Test
    void updateSession_returnsUpdatedSession() {
        SessionCreateRequest request = SessionCreateRequest.builder()
                .sessionName("Updated")
                .build();

        SessionResponse expected = SessionResponse.builder()
                .id(1L)
                .sessionName("Updated")
                .build();

        when(sessionService.updateSession(1L, request)).thenReturn(expected);

        ResponseEntity<SessionResponse> response = controller.updateSession(1L, request);

        verify(sessionService).updateSession(1L, request);
        assertThat(response.getBody()).isEqualTo(expected);
    }

    /**
     * Ensures that ending a session delegates to the service and returns the
     * resulting session.
     */
    @Test
    void endSession_delegatesToService() {
        SessionResponse expected = SessionResponse.builder()
                .id(1L)
                .build();

        when(sessionService.endSession(1L, "user1")).thenReturn(expected);

        ResponseEntity<SessionResponse> response = controller.endSession(1L, "user1");

        verify(sessionService).endSession(1L, "user1");
        assertThat(response.getBody()).isEqualTo(expected);
    }

    /**
     * Verifies that fetching a single session returns the session from the
     * service.
     */
    @Test
    void getSession_returnsSession() {
        SessionResponse expected = SessionResponse.builder()
                .id(1L)
                .build();

        when(sessionService.getSession(1L)).thenReturn(expected);

        ResponseEntity<SessionResponse> response = controller.getSession(1L);

        verify(sessionService).getSession(1L);
        assertThat(response.getBody()).isEqualTo(expected);
    }

    /**
     * Verifies that the controller returns all sessions from the service.
     */
    @Test
    void getAllSessions_returnsList() {
        List<SessionResponse> list = Collections.singletonList(SessionResponse.builder().id(1L).build());
        when(sessionService.getAllSessions()).thenReturn(list);

        ResponseEntity<List<SessionResponse>> response = controller.getAllSessions();

        verify(sessionService).getAllSessions();
        assertThat(response.getBody()).containsExactlyElementsOf(list);
    }

    /**
     * Verifies that the controller returns only active sessions from the
     * service.
     */
    @Test
    void getActiveSessions_returnsList() {
        List<SessionResponse> list = Collections.singletonList(SessionResponse.builder().id(2L).build());
        when(sessionService.getActiveSessions()).thenReturn(list);

        ResponseEntity<List<SessionResponse>> response = controller.getActiveSessions();

        verify(sessionService).getActiveSessions();
        assertThat(response.getBody()).containsExactlyElementsOf(list);
    }

    /**
     * Verifies that a session report is retrieved from the service and
     * returned by the controller.
     */
    @Test
    void getSessionReport_returnsReport() {
        SessionReportResponse report = SessionReportResponse.builder()
                .sessionId(1L)
                .build();

        when(sessionService.getSessionReport(1L)).thenReturn(report);

        ResponseEntity<SessionReportResponse> response = controller.getSessionReport(1L);

        verify(sessionService).getSessionReport(1L);
        assertThat(response.getBody()).isEqualTo(report);
    }
}
