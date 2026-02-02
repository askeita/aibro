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
 * Request DTO carrying API keys to be stored for a user.
 */
public class ApiKeyRequest {
    
    private String userId;
    private String claudeApiKey;
    private String openaiApiKey;
    private String geminiApiKey;
    private String googleCloudApiKey;
}
