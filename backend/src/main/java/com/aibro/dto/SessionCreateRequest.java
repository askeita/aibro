package com.aibro.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;


@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
/**
 * Request DTO used to create or update a brainstorming session.
 */
public class SessionCreateRequest {
    
    private String sessionName;
    private List<String> participants;
    private String aiModel; // claude, openai, gemini
    private Integer aiContributionFrequency; // 1-20
    private String aiVoiceGender; // male, female
    private String userId; // To retrieve API keys
    private String objective; // Objective of the brainstorming session
}
