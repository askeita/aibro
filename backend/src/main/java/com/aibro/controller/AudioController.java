package com.aibro.controller;

import com.aibro.model.BrainstormingSession;
import com.aibro.model.Contribution;
import com.aibro.repository.BrainstormingSessionRepository;
import com.aibro.service.AIContributionService;
import com.aibro.service.BrainstormingSessionService;
import com.aibro.service.SpeechService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;


@RestController
@RequestMapping("/api/audio")
@RequiredArgsConstructor
@Slf4j
/**
 * REST controller for handling audio transcription, TTS synthesis, and
 * speaker calibration for brainstorming sessions.
 */
public class AudioController {

    private final SpeechService speechService;
    private final BrainstormingSessionService sessionService;
    private final BrainstormingSessionRepository sessionRepository;
    private final AIContributionService aiContributionService;

    /**
     * Transcribes uploaded audio, saves human contributions, and optionally
     * triggers an AI contribution for the given session.
     *
     * @param sessionId    the ID of the brainstorming session
     * @param userId       the user identifier used to look up API keys
     * @param languageCode optional language code override for speech
     *                     recognition
     * @param forceAi      whether to force an AI contribution regardless of
     *                     frequency settings
     * @param audioFile    the uploaded audio file
     * @return a response indicating success and basic transcription metadata
     */
    @PostMapping("/transcribe")
    public ResponseEntity<Map<String, Object>> transcribeAudio(
            @RequestParam("sessionId") Long sessionId,
            @RequestParam("userId") String userId,
            @RequestParam(value = "languageCode", required = false) String languageCode,
            @RequestParam(value = "forceAi", required = false, defaultValue = "false") boolean forceAi,
            @RequestParam("audio") MultipartFile audioFile) {
        
        try {
            byte[] audioData = audioFile.getBytes();
            
            // Recognize speech with speaker diarization
            SpeechService.SpeechRecognitionResult result = speechService.recognizeSpeech(audioData, userId, languageCode);

            if (result == null || result.getSegments().isEmpty()) {
                log.info("Speech recognition returned no segments for session {} and user {}", sessionId, userId);
                Map<String, Object> response = new HashMap<>();
                response.put("success", false);
                response.put("segments", 0);
                response.put("message", "No speech recognized. Please try again.");
                return ResponseEntity.ok(response);
            }

            BrainstormingSession session = sessionRepository.findById(sessionId).orElse(null);
            if (session == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "Session not found"));
            }

            // Process each segment
            for (SpeechService.SpeechRecognitionResult.TranscriptSegment segment : result.getSegments()) {
                String speakerName = mapSpeakerTagToParticipant(segment.getSpeakerTag(), session);
                sessionService.addContribution(
                        sessionId,
                        speakerName,
                        segment.getText(),
                        Contribution.ContributionType.HUMAN,
                        segment.getConfidence()
                );
            }

            // Trigger AI evaluation (async)
            aiContributionService.evaluateAndContribute(sessionId, userId, languageCode, forceAi);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("segments", result.getSegments().size());
            
            return ResponseEntity.ok(response);
            
        } catch (IOException e) {
            log.error("Error processing audio: {}", e.getMessage(), e);
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        } catch (IllegalStateException e) {
            // Known validation / configuration issues (e.g. missing API key, Google API error)
            log.error("Speech transcription failed: {}", e.getMessage(), e);
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Synthesizes speech audio from the given text.
     *
     * @param text        the text to synthesize
     * @param voiceGender desired voice gender (male or female)
     * @param userId      the user identifier used to look up API keys
     * @return the synthesized audio bytes or an error response if generation
     * fails
     */
    @PostMapping(value = "/synthesize", produces = MediaType.APPLICATION_OCTET_STREAM_VALUE)
    public ResponseEntity<byte[]> synthesizeText(
            @RequestParam("text") String text,
            @RequestParam("voiceGender") String voiceGender,
            @RequestParam("userId") String userId) {
        
        byte[] audioData = speechService.textToSpeech(text, voiceGender, userId);
        
        if (audioData == null) {
            return ResponseEntity.internalServerError().build();
        }
        
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("audio/mpeg"))
                .body(audioData);
    }

    /**
     * Calibrates speaker diarization by mapping detected speaker tags from a
     * short audio sample to the session participants.
     *
     * @param sessionId the ID of the brainstorming session
     * @param userId    the user identifier used to look up API keys
     * @param languageCode optional language code override for speech
     *                     recognition
     * @param audioFile the uploaded calibration audio file
     * @return a response with the inferred mapping between speaker tags and
     * participants
     */
    @PostMapping("/calibrate")
    public ResponseEntity<Map<String, Object>> calibrateSpeakers(
            @RequestParam("sessionId") Long sessionId,
            @RequestParam("userId") String userId,
            @RequestParam(value = "languageCode", required = false) String languageCode,
            @RequestParam("audio") MultipartFile audioFile) {

        try {
            byte[] audioData = audioFile.getBytes();

            // Recognize speech with diarization enabled
            SpeechService.SpeechRecognitionResult result = speechService.recognizeSpeech(audioData, userId, languageCode);

            if (result == null || result.getSegments().isEmpty()) {
                Map<String, Object> response = new HashMap<>();
                response.put("success", false);
                response.put("segments", 0);
                response.put("message", "No speech recognized during calibration. Please try again.");
                return ResponseEntity.ok(response);
            }

            BrainstormingSession session = sessionRepository.findById(sessionId).orElse(null);
            if (session == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "Session not found"));
            }

            // Build first-seen order of distinct speaker tags
            Map<Integer, Integer> speakerOrder = new LinkedHashMap<>();
            int index = 0;
            for (SpeechService.SpeechRecognitionResult.TranscriptSegment segment : result.getSegments()) {
                int tag = segment.getSpeakerTag();
                if (tag < 0) {
                    continue;
                }
                if (!speakerOrder.containsKey(tag)) {
                    speakerOrder.put(tag, index++);
                }
            }

            if (speakerOrder.isEmpty()) {
                Map<String, Object> response = new HashMap<>();
                response.put("success", false);
                response.put("segments", result.getSegments().size());
                response.put("message", "No distinct speakers detected during calibration.");
                return ResponseEntity.ok(response);
            }

            // Map ordered speaker tags to participant list order
            Map<String, String> mapping = new LinkedHashMap<>();
            int participantCount = session.getParticipants().size();
            int i = 0;
            for (Integer tag : speakerOrder.keySet()) {
                if (i >= participantCount) {
                    break;
                }
                String participantName = session.getParticipants().get(i);
                mapping.put(String.valueOf(tag), participantName);
                i++;
            }

            // Persist mapping as JSON on the session
            String json = mapping.entrySet().stream()
                    .map(e -> "\"" + e.getKey() + "\":\"" + e.getValue().replace("\"", "\\\"") + "\"")
                    .collect(Collectors.joining(","));
            session.setSpeakerMappingJson("{" + json + "}");
            sessionRepository.save(session);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("segments", result.getSegments().size());
            response.put("mappedSpeakers", mapping.size());
            response.put("mapping", mapping);
            return ResponseEntity.ok(response);

        } catch (IOException e) {
            log.error("Error processing calibration audio: {}", e.getMessage(), e);
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        } catch (IllegalStateException e) {
            log.error("Speaker calibration failed: {}", e.getMessage(), e);
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Maps a Google Speech speaker tag to a participant name using the
     * persisted mapping for the session, falling back to a simple
     * index-based mapping when no explicit mapping exists.
     *
     * @param speakerTag the numeric speaker tag from diarization
     * @param session    the brainstorming session
     * @return the resolved participant name, or a generic label when unknown
     */
    private String mapSpeakerTagToParticipant(int speakerTag, BrainstormingSession session) {
        if (session.getSpeakerMappingJson() != null && !session.getSpeakerMappingJson().isEmpty() && speakerTag >= 0) {
            try {
                String json = session.getSpeakerMappingJson().trim();
                if (json.startsWith("{") && json.endsWith("}")) {
                    json = json.substring(1, json.length() - 1);
                }
                Map<String, String> mapping = new HashMap<>();
                if (!json.isEmpty()) {
                    String[] entries = json.split(",");
                    for (String entry : entries) {
                        String[] kv = entry.split(":", 2);
                        if (kv.length == 2) {
                            String key = kv[0].trim().replace("\"", "");
                            String value = kv[1].trim().replaceAll("^\"|\"$", "");
                            mapping.put(key, value);
                        }
                    }
                }
                String mapped = mapping.get(String.valueOf(speakerTag));
                if (mapped != null && !mapped.isEmpty()) {
                    return mapped;
                }
            } catch (Exception ex) {
                log.warn("Failed to parse speakerMappingJson for session {}: {}", session.getId(), ex.getMessage());
            }
        }

        // Fallback: simple mapping based on participant index
        if (speakerTag < 0 || session.getParticipants().isEmpty()) {
            return "Unknown Speaker";
        }

        int participantIndex = speakerTag % session.getParticipants().size();
        return session.getParticipants().get(participantIndex);
    }
}
