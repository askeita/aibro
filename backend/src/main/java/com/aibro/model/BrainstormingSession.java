package com.aibro.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;


@Entity
@Table(name = "brainstorming_sessions")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
/**
 * JPA entity representing a single brainstorming session and its
 * configuration, timing, participants, and persisted contributions.
 */
public class BrainstormingSession {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String sessionName;

    @Column(nullable = false)
    private LocalDateTime startTime;

    @Column
    private LocalDateTime endTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SessionStatus status;

    @ElementCollection
    @CollectionTable(name = "session_participants", joinColumns = @JoinColumn(name = "session_id"))
    @Column(name = "participant_name")
    private List<String> participants = new ArrayList<>();

    @Column
    private String aiModel; // claude, openai, gemini

    @Column
    private Integer aiContributionFrequency;

    @Column
    private String aiVoiceGender; // male, female

    @Column(columnDefinition = "TEXT")
    private String summary;

    @Column(columnDefinition = "TEXT")
    private String objective;

    @Column(columnDefinition = "TEXT")
    private String fullTranscript;

    // JSON-encoded mapping from Google Speech speakerTag (as String key)
    // to participant first name for this session, populated during a
    // short calibration phase where each participant introduces themselves.
    @Column(columnDefinition = "TEXT")
    private String speakerMappingJson;

    @OneToMany(mappedBy = "session", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Contribution> contributions = new ArrayList<>();

    /**
     * Lifecycle status values for a brainstorming session.
     */
    public enum SessionStatus {
        ACTIVE, PAUSED, COMPLETED, CANCELLED
    }
}
