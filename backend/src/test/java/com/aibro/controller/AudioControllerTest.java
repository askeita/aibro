package com.aibro.controller;

import com.aibro.model.BrainstormingSession;
import com.aibro.model.Contribution;
import com.aibro.repository.BrainstormingSessionRepository;
import com.aibro.service.AIContributionService;
import com.aibro.service.BrainstormingSessionService;
import com.aibro.service.SpeechService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockMultipartFile;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link AudioController} covering transcription,
 * synthesis, and speaker calibration workflows.
 */
class AudioControllerTest {

    private SpeechService speechService;
    private BrainstormingSessionService sessionService;
    private BrainstormingSessionRepository sessionRepository;
    private AIContributionService aiContributionService;
    private AudioController controller;

    /**
     * Sets up a controller instance backed by mocked dependencies before
     * each test.
     */
    @BeforeEach
    void setUp() {
        speechService = mock(SpeechService.class);
        sessionService = mock(BrainstormingSessionService.class);
        sessionRepository = mock(BrainstormingSessionRepository.class);
        aiContributionService = mock(AIContributionService.class);
        controller = new AudioController(speechService, sessionService, sessionRepository, aiContributionService);
    }

    /**
     * Verifies that a successful transcription request returns OK, saves
     * human contributions, and triggers an AI contribution.
     */
    @Test
    void transcribeAudio_successfulFlowReturnsOkAndTriggersServices() {
        Long sessionId = 1L;
        String userId = "user1";

        // Prepare recognition result with one segment
        SpeechService.SpeechRecognitionResult result = new SpeechService.SpeechRecognitionResult();
        result.addSegment("Hello world", 0.9, 1);

        when(speechService.recognizeSpeech(any(), eq(userId), eq("en-US"))).thenReturn(result);

        BrainstormingSession session = BrainstormingSession.builder()
                .id(sessionId)
                .participants(List.of("Alice", "Bob"))
                .speakerMappingJson("{\"1\":\"Bob\"}")
                .build();
        when(sessionRepository.findById(sessionId)).thenReturn(Optional.of(session));

        MockMultipartFile file = new MockMultipartFile("audio", "test.wav", "audio/wav", new byte[]{1, 2, 3});

        ResponseEntity<Map<String, Object>> response = controller.transcribeAudio(sessionId, userId, "en-US", true, file);

        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        Map<String, Object> body = response.getBody();
        assertThat(body).isNotNull();
        assertThat(body.get("success")).isEqualTo(true);
        assertThat(body.get("segments")).isEqualTo(1);

        verify(sessionService).addContribution(eq(sessionId), eq("Bob"), eq("Hello world"), eq(Contribution.ContributionType.HUMAN), anyDouble());
        verify(aiContributionService).evaluateAndContribute(sessionId, userId, "en-US", true);
    }

    /**
     * Ensures that an {@link IllegalStateException} from the speech
     * service results in a 4xx error with the message in the body.
     */
    @Test
    void transcribeAudio_returnsBadRequestOnIllegalState() {
        Long sessionId = 1L;
        String userId = "user1";

        when(speechService.recognizeSpeech(any(), eq(userId), isNull())).thenThrow(new IllegalStateException("No API key"));
        when(sessionRepository.findById(sessionId)).thenReturn(Optional.of(BrainstormingSession.builder().id(sessionId).build()));

        MockMultipartFile file = new MockMultipartFile("audio", "test.wav", "audio/wav", new byte[]{1, 2, 3});

        ResponseEntity<Map<String, Object>> response = controller.transcribeAudio(sessionId, userId, null, false, file);

        assertThat(response.getStatusCode().is4xxClientError()).isTrue();
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().get("error").toString()).contains("No API key");
    }

    /**
     * Verifies that when text-to-speech returns no audio, the controller
     * responds with an internal server error.
     */
    @Test
    void synthesizeText_returnsInternalServerErrorWhenNoAudio() {
        String text = "Hello";
        String userId = "user1";

        when(speechService.textToSpeech(text, "male", userId)).thenReturn(null);

        ResponseEntity<byte[]> response = controller.synthesizeText(text, "male", userId);

        assertThat(response.getStatusCode().is5xxServerError()).isTrue();
    }

    /**
     * Verifies that speaker calibration builds a mapping between speaker
     * tags and participants and persists it on the session.
     */
    @Test
    void calibrateSpeakers_buildsAndPersistsMapping() {
        Long sessionId = 1L;
        String userId = "user1";

        // Recognition result with two speakers
        SpeechService.SpeechRecognitionResult result = new SpeechService.SpeechRecognitionResult();
        result.addSegment("Hi", 0.9, 5);
        result.addSegment("Hello", 0.8, 6);

        when(speechService.recognizeSpeech(any(), eq(userId), isNull())).thenReturn(result);

        BrainstormingSession session = BrainstormingSession.builder()
                .id(sessionId)
                .participants(List.of("Alice", "Bob"))
                .build();
        when(sessionRepository.findById(sessionId)).thenReturn(Optional.of(session));
        when(sessionRepository.save(any(BrainstormingSession.class))).thenAnswer(invocation -> invocation.getArgument(0));

        MockMultipartFile file = new MockMultipartFile("audio", "calibrate.wav", "audio/wav", new byte[]{4, 5, 6});

        ResponseEntity<Map<String, Object>> response = controller.calibrateSpeakers(sessionId, userId, null, file);

        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        Map<String, Object> body = response.getBody();
        assertThat(body).isNotNull();
        assertThat(body.get("success")).isEqualTo(true);
        assertThat(body.get("mappedSpeakers")).isEqualTo(2);

        // Verify mapping JSON persisted on session
        assertThat(session.getSpeakerMappingJson()).isEqualTo("{\"5\":\"Alice\",\"6\":\"Bob\"}");
    }
}
