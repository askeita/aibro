package com.aibro.repository;

import com.aibro.model.Contribution;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;


@Repository
/**
 * Spring Data repository for accessing contribution records.
 */
public interface ContributionRepository extends JpaRepository<Contribution, Long> {
    
    /**
     * Finds all contributions for a given session ordered by timestamp
     * ascending.
     *
     * @param sessionId the session identifier
     * @return the ordered list of contributions
     */
    List<Contribution> findBySessionIdOrderByTimestampAsc(Long sessionId);
    
    /**
     * Finds contributions of a specific type for a given session ordered by
     * timestamp ascending.
     *
     * @param sessionId the session identifier
     * @param type      the contribution type
     * @return the ordered list of matching contributions
     */
    List<Contribution> findBySessionIdAndTypeOrderByTimestampAsc(Long sessionId, Contribution.ContributionType type);
}
