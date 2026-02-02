package com.aibro.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;


@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
/**
 * Response DTO exposing the main properties of a brainstorming session to
 * clients.
 */
public class SessionResponse {
    
    private Long id;
    private String sessionName;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private String status;
    private List<String> participants;
    private String aiModel;
    private Integer aiContributionFrequency;
    private String aiVoiceGender;
    private String summary;
    private String objective;
}
