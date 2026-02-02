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
 * Request DTO encapsulating audio data and metadata for transcription.
 */
public class AudioTranscriptionRequest {
    
    private Long sessionId;
    private byte[] audioData;
    private String format; // wav, mp3, etc.
}
