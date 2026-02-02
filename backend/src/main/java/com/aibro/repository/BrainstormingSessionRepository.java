package com.aibro.repository;

import com.aibro.model.BrainstormingSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;


@Repository
/**
 * Spring Data repository for accessing brainstorming session entities.
 */
public interface BrainstormingSessionRepository extends JpaRepository<BrainstormingSession, Long> {
    
    /**
     * Finds sessions with the given status ordered by start time descending.
     *
     * @param status the desired session status
     * @return the ordered list of matching sessions
     */
    List<BrainstormingSession> findByStatusOrderByStartTimeDesc(BrainstormingSession.SessionStatus status);
    
    /**
     * Returns all sessions ordered by start time descending.
     *
     * @return the ordered list of all sessions
     */
    List<BrainstormingSession> findAllByOrderByStartTimeDesc();
}
