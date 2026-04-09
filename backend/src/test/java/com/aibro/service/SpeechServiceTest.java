package com.aibro.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link SpeechService} focusing on behavior when API
 * keys are missing from configuration.
 */
class SpeechServiceTest {

    private ApiKeyService apiKeyService;
    private SpeechService speechService;

    /**
     * Initializes the {@link SpeechService} with a mocked
     * {@link ApiKeyService} before each test.
     */
    @BeforeEach
    void setUp() {
        apiKeyService = mock(ApiKeyService.class);
        speechService = new SpeechService(apiKeyService);
    }

    /**
     * Ensures that {@link SpeechService#recognizeSpeech(byte[], String, String)}
     * throws when no Google Cloud API key is configured for the user.
     */
    @Test
    void recognizeSpeech_throwsWhenNoApiKeyConfigured() {
        byte[] audio = new byte[] {1, 2, 3};
        String userId = "user1";

        when(apiKeyService.getGoogleCloudApiKey(userId)).thenReturn(null);

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> speechService.recognizeSpeech(audio, userId, null));

        assertThat(ex.getMessage()).contains("No Google Cloud API key found for user: " + userId);
    }

    /**
     * Verifies that {@link SpeechService#textToSpeech(String, String, String)}
     * returns {@code null} when no API key is configured.
     */
    @Test
    void textToSpeech_returnsNullWhenNoApiKeyConfigured() {
        String text = "Hello";
        String userId = "user1";

        when(apiKeyService.getGoogleCloudApiKey(userId)).thenReturn("");

        byte[] result = speechService.textToSpeech(text, "male", userId);

        assertThat(result).isNull();
    }
}
