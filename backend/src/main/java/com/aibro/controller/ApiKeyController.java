package com.aibro.controller;

import com.aibro.dto.ApiKeyRequest;
import com.aibro.service.ApiKeyService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;


@RestController
@RequestMapping("/api/keys")
@RequiredArgsConstructor
/**
 * REST controller for managing and validating per-user API keys for external
 * AI and speech providers.
 */
public class ApiKeyController {

    private final ApiKeyService apiKeyService;

    /**
     * Persists or updates API keys for a given user.
     *
     * @param request the API key payload
     * @return an empty 200 OK response on success
     */
    @PostMapping
    public ResponseEntity<Void> saveApiKeys(@RequestBody ApiKeyRequest request) {
        apiKeyService.saveApiKeys(request);
        return ResponseEntity.ok().build();
    }

    /**
     * Validates whether the given user has an API key configured for the
     * requested AI model.
     *
     * @param model  the AI model identifier (e.g. claude, openai, gemini)
     * @param userId the user identifier
     * @return {@code true} if a non-empty key exists, otherwise {@code false}
     */
    @GetMapping("/validate/{model}")
    public ResponseEntity<Boolean> validateApiKey(
            @PathVariable String model,
            @RequestParam String userId) {
        boolean hasKey = apiKeyService.hasApiKeyForModel(model, userId);
        return ResponseEntity.ok(hasKey);
    }
}
