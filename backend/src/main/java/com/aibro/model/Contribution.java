package com.aibro.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;


@Entity
@Table(name = "contributions")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
/**
 * JPA entity representing a single contribution within a session, either
 * from a human participant or the AI assistant.
 */
public class Contribution {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "session_id", nullable = false)
    private BrainstormingSession session;

    @Column(nullable = false)
    private String speaker; // participant name or "AI"

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    @Column(nullable = false)
    private LocalDateTime timestamp;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ContributionType type;

    @Column
    private Double confidence; // for voice recognition confidence

    /**
     * Distinguishes between human and AI-generated contributions.
     */
    public enum ContributionType {
        HUMAN, AI
    }
}
