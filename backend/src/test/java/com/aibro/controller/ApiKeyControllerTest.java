package com.aibro.controller;

import com.aibro.dto.ApiKeyRequest;
import com.aibro.service.ApiKeyService;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link ApiKeyController} validating that API key
 * operations delegate correctly to the service layer.
 */
class ApiKeyControllerTest {

    private final ApiKeyService apiKeyService = mock(ApiKeyService.class);
    private final ApiKeyController controller = new ApiKeyController(apiKeyService);

    /**
     * Verifies that saving API keys calls the service and returns a
     * successful response.
     */
    @Test
    void saveApiKeys_delegatesToServiceAndReturnsOk() {
        ApiKeyRequest request = ApiKeyRequest.builder()
                .userId("user1")
                .build();

        ResponseEntity<Void> response = controller.saveApiKeys(request);

        verify(apiKeyService).saveApiKeys(request);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
    }

    /**
     * Ensures that API key validation returns the boolean result from the
     * service in the response body.
     */
    @Test
    void validateApiKey_returnsServiceResultInBody() {
        when(apiKeyService.hasApiKeyForModel("openai", "user1")).thenReturn(true);

        ResponseEntity<Boolean> response = controller.validateApiKey("openai", "user1");

        verify(apiKeyService).hasApiKeyForModel("openai", "user1");
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(response.getBody()).isTrue();
    }
}
