package com.aibro.service;

import com.aibro.dto.ApiKeyRequest;
import com.aibro.model.ApiKey;
import com.aibro.repository.ApiKeyRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link ApiKeyService} validating persistence and lookup
 * logic for stored API keys.
 */
class ApiKeyServiceTest {

    private ApiKeyRepository apiKeyRepository;
    private ApiKeyService apiKeyService;

    /**
     * Configures {@link ApiKeyService} with a mocked
     * {@link ApiKeyRepository} before each test.
     */
    @BeforeEach
    void setUp() {
        apiKeyRepository = mock(ApiKeyRepository.class);
        apiKeyService = new ApiKeyService(apiKeyRepository);
    }

    /**
     * Verifies that saving API keys for a new user creates a new
     * {@link ApiKey} entity with all provided values.
     */
    @Test
    void saveApiKeys_createsNewEntityWhenNoneExists() {
        ApiKeyRequest request = ApiKeyRequest.builder()
                .userId("user1")
                .claudeApiKey("claude-key")
                .openaiApiKey("openai-key")
                .geminiApiKey("gemini-key")
                .googleCloudApiKey("google-key")
                .build();

        when(apiKeyRepository.findByUserId("user1")).thenReturn(Optional.empty());

        apiKeyService.saveApiKeys(request);

        ArgumentCaptor<ApiKey> captor = ArgumentCaptor.forClass(ApiKey.class);
        verify(apiKeyRepository).save(captor.capture());
        ApiKey saved = captor.getValue();

        assertThat(saved.getUserId()).isEqualTo("user1");
        assertThat(saved.getClaudeApiKey()).isEqualTo("claude-key");
        assertThat(saved.getOpenaiApiKey()).isEqualTo("openai-key");
        assertThat(saved.getGeminiApiKey()).isEqualTo("gemini-key");
        assertThat(saved.getGoogleCloudApiKey()).isEqualTo("google-key");
    }

    /**
     * Ensures that saving API keys for an existing user updates only
     * non-empty fields, leaving others unchanged.
     */
    @Test
    void saveApiKeys_updatesOnlyNonEmptyValues() {
        ApiKey existing = ApiKey.builder()
                .id(1L)
                .userId("user1")
                .claudeApiKey("existing-claude")
                .openaiApiKey("existing-openai")
                .geminiApiKey("existing-gemini")
                .googleCloudApiKey("existing-google")
                .build();

        when(apiKeyRepository.findByUserId("user1")).thenReturn(Optional.of(existing));

        ApiKeyRequest request = ApiKeyRequest.builder()
                .userId("user1")
                .claudeApiKey("") // should be ignored
                .openaiApiKey("new-openai")
                .geminiApiKey(null)
                .googleCloudApiKey("new-google")
                .build();

        apiKeyService.saveApiKeys(request);

        ArgumentCaptor<ApiKey> captor = ArgumentCaptor.forClass(ApiKey.class);
        verify(apiKeyRepository).save(captor.capture());
        ApiKey saved = captor.getValue();

        assertThat(saved.getClaudeApiKey()).isEqualTo("existing-claude");
        assertThat(saved.getOpenaiApiKey()).isEqualTo("new-openai");
        assertThat(saved.getGeminiApiKey()).isEqualTo("existing-gemini");
        assertThat(saved.getGoogleCloudApiKey()).isEqualTo("new-google");
    }

    /**
     * Verifies that {@link ApiKeyService#getApiKeyForModel(String, String)}
     * returns the appropriate key for each model or {@code null}.
     */
    @Test
    void getApiKeyForModel_returnsCorrectKeyOrNull() {
        ApiKey apiKey = ApiKey.builder()
                .userId("user1")
                .claudeApiKey("claude-key")
                .openaiApiKey("openai-key")
                .geminiApiKey("gemini-key")
                .build();

        when(apiKeyRepository.findByUserId("user1")).thenReturn(Optional.of(apiKey));

        assertThat(apiKeyService.getApiKeyForModel("claude", "user1")).isEqualTo("claude-key");
        assertThat(apiKeyService.getApiKeyForModel("OPENAI", "user1")).isEqualTo("openai-key");
        assertThat(apiKeyService.getApiKeyForModel("gemini", "user1")).isEqualTo("gemini-key");
        assertThat(apiKeyService.getApiKeyForModel("unknown", "user1")).isNull();
    }

    /**
     * Ensures that requesting a Google Cloud API key for a missing user
     * returns {@code null}.
     */
    @Test
    void getGoogleCloudApiKey_returnsNullWhenNoRecord() {
        when(apiKeyRepository.findByUserId("user1")).thenReturn(Optional.empty());

        String result = apiKeyService.getGoogleCloudApiKey("user1");

        assertThat(result).isNull();
    }

    /**
     * Verifies that {@link ApiKeyService#hasApiKeyForModel(String, String)}
     * only reports true when the stored key is non-empty.
     */
    @Test
    void hasApiKeyForModel_checksForNonEmptyKey() {
        ApiKey apiKeyWithEmpty = ApiKey.builder()
                .userId("user1")
                .openaiApiKey("")
                .build();

        when(apiKeyRepository.findByUserId("user1")).thenReturn(Optional.of(apiKeyWithEmpty));

        assertThat(apiKeyService.hasApiKeyForModel("openai", "user1")).isFalse();
    }
}
