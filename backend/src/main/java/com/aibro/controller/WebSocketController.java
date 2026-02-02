package com.aibro.controller;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.stereotype.Controller;

import java.util.Map;


@Controller
@RequiredArgsConstructor
@Slf4j
/**
 * STOMP WebSocket controller that echoes session status updates and
 * contributions back to subscribed clients.
 */
public class WebSocketController {

    /**
     * Handles session status messages and broadcasts them to the
     * corresponding topic.
     *
     * @param sessionId the session identifier extracted from the destination
     * @param message   the status payload
     * @return the same message so it is broadcast to subscribers
     */
    @MessageMapping("/session/{sessionId}/status")
    @SendTo("/topic/session/{sessionId}/status")
    public Map<String, Object> handleSessionStatus(
            @DestinationVariable Long sessionId,
            Map<String, Object> message) {
        log.debug("Received status update for session {}: {}", sessionId, message);
        return message;
    }

    /**
     * Handles contribution messages and broadcasts them to the
     * contributions topic for the session.
     *
     * @param sessionId    the session identifier extracted from the
     *                     destination
     * @param contribution the contribution payload
     * @return the same contribution so it is broadcast to subscribers
     */
    @MessageMapping("/session/{sessionId}/contribution")
    @SendTo("/topic/session/{sessionId}/contributions")
    public Map<String, Object> handleContribution(
            @DestinationVariable Long sessionId,
            Map<String, Object> contribution) {
        log.debug("Received contribution for session {}: {}", sessionId, contribution);
        return contribution;
    }
}
