package com.aibro.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;


@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
/**
 * DTO sent over WebSocket to notify clients about AI-related events such as
 * pre-contribution signals or actual AI contributions.
 */
public class AINotificationMessage {
    
    private Long sessionId;
    private String type; // "SIGNAL" for blue light/sound, "CONTRIBUTION" for actual contribution
    private String content;
    private String audioUrl; // URL to TTS audio file
}
