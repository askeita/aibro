package com.aibro.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;


@Entity
@Table(name = "api_keys")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
/**
 * JPA entity storing API keys for a specific user across multiple external
 * providers.
 */
public class ApiKey {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String userId; // Device/user identifier

    @Column
    private String claudeApiKey;

    @Column
    private String openaiApiKey;

    @Column
    private String geminiApiKey;

    @Column
    private String googleCloudApiKey; // For speech services
}
