package com.aibro.controller;

import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit tests for {@link WebSocketController} verifying that simple
 * WebSocket endpoints echo back the received payload.
 */
class WebSocketControllerTest {

    private final WebSocketController controller = new WebSocketController();

    /**
     * Ensures that the session status handler echoes the incoming payload
     * unchanged.
     */
    @Test
    void handleSessionStatus_echoesMessage() {
        Map<String, Object> payload = new HashMap<>();
        payload.put("status", "ACTIVE");

        Map<String, Object> result = controller.handleSessionStatus(1L, payload);

        assertThat(result).isEqualTo(payload);
    }

    /**
     * Ensures that the contribution handler echoes the incoming
     * contribution payload unchanged.
     */
    @Test
    void handleContribution_echoesContribution() {
        Map<String, Object> payload = new HashMap<>();
        payload.put("speaker", "Alice");

        Map<String, Object> result = controller.handleContribution(1L, payload);

        assertThat(result).isEqualTo(payload);
    }
}
