package com.aibro.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;


@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
/**
 * Response DTO representing a single contribution as returned to clients.
 */
public class ContributionResponse {
    
    private Long id;
    private String speaker;
    private String content;
    private LocalDateTime timestamp;
    private String type; // HUMAN or AI
    private Double confidence;
}
