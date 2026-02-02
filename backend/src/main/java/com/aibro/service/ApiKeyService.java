package com.aibro.service;

import com.aibro.dto.ApiKeyRequest;
import com.aibro.model.ApiKey;
import com.aibro.repository.ApiKeyRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;


@Service
@RequiredArgsConstructor
@Slf4j
/**
 * Service for persisting and retrieving per-user API keys for AI and speech
 * providers.
 */
public class ApiKeyService {

    private final ApiKeyRepository apiKeyRepository;

    /**
     * Saves or updates API keys for the given user.
     *
     * @param request the API key payload
     */
    @Transactional
    public void saveApiKeys(ApiKeyRequest request) {
        ApiKey apiKey = apiKeyRepository.findByUserId(request.getUserId())
                .orElse(ApiKey.builder()
                        .userId(request.getUserId())
                        .build());

        if (request.getClaudeApiKey() != null && !request.getClaudeApiKey().isEmpty()) {
            apiKey.setClaudeApiKey(request.getClaudeApiKey());
        }
        if (request.getOpenaiApiKey() != null && !request.getOpenaiApiKey().isEmpty()) {
            apiKey.setOpenaiApiKey(request.getOpenaiApiKey());
        }
        if (request.getGeminiApiKey() != null && !request.getGeminiApiKey().isEmpty()) {
            apiKey.setGeminiApiKey(request.getGeminiApiKey());
        }
        if (request.getGoogleCloudApiKey() != null && !request.getGoogleCloudApiKey().isEmpty()) {
            apiKey.setGoogleCloudApiKey(request.getGoogleCloudApiKey());
        }

        apiKeyRepository.save(apiKey);
        log.info("Saved API keys for user: {}", request.getUserId());
    }

    /**
     * Returns the API key associated with the given AI model for a user.
     *
     * @param model  the AI model identifier (e.g. claude, openai, gemini)
     * @param userId the user identifier
     * @return the API key or {@code null} if none is stored
     */
    public String getApiKeyForModel(String model, String userId) {
        ApiKey apiKey = apiKeyRepository.findByUserId(userId).orElse(null);
        if (apiKey == null) {
            return null;
        }

        switch (model.toLowerCase()) {
            case "claude":
                return apiKey.getClaudeApiKey();
            case "openai":
                return apiKey.getOpenaiApiKey();
            case "gemini":
                return apiKey.getGeminiApiKey();
            default:
                return null;
        }
    }

    /**
     * Returns the Google Cloud API key used for speech services for the
     * specified user.
     *
     * @param userId the user identifier
     * @return the API key or {@code null} if none is stored
     */
    public String getGoogleCloudApiKey(String userId) {
        ApiKey apiKey = apiKeyRepository.findByUserId(userId).orElse(null);
        return apiKey != null ? apiKey.getGoogleCloudApiKey() : null;
    }

    /**
     * Checks whether the user has a non-empty API key stored for the
     * specified model.
     *
     * @param model  the AI model identifier
     * @param userId the user identifier
     * @return {@code true} if a key exists, otherwise {@code false}
     */
    public boolean hasApiKeyForModel(String model, String userId) {
        String key = getApiKeyForModel(model, userId);
        return key != null && !key.isEmpty();
    }
}
