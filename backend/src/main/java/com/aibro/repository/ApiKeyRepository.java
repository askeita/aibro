package com.aibro.repository;

import com.aibro.model.ApiKey;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;


@Repository
/**
 * Spring Data repository for accessing stored API keys.
 */
public interface ApiKeyRepository extends JpaRepository<ApiKey, Long> {
    
    /**
     * Finds API keys associated with the given user identifier.
     *
     * @param userId the user identifier
     * @return an optional containing the ApiKey entity if present
     */
    Optional<ApiKey> findByUserId(String userId);
}
