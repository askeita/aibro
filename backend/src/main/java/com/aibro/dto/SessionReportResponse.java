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
 * Response DTO representing a detailed report for a single session,
 * including transcript, contributions, and summary statistics.
 */
public class SessionReportResponse {
    
    private Long sessionId;
    private String sessionName;
    private String summary;
    private List<ContributionResponse> contributions;
    private String fullTranscript;
    private SessionStatistics statistics;
    
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    /**
     * Nested DTO capturing high-level statistics for a session.
     */
    public static class SessionStatistics {
        private int totalContributions;
        private int humanContributions;
        private int aiContributions;
        private long durationMinutes;
    }
}
