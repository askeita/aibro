package com.aibro.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import okhttp3.*;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.Base64;
import java.util.concurrent.TimeUnit;


@Service
@RequiredArgsConstructor
@Slf4j
/**
 * Service for integrating with external speech providers to perform speech
 * recognition with diarization and text-to-speech synthesis.
 */
public class SpeechService {

    private final ApiKeyService apiKeyService;

    @Value("${speech.recognition.provider}")
    private String recognitionProvider;

    @Value("${speech.recognition.language}")
    private String recognitionLanguage;

    @Value("${speech.text-to-speech.provider}")
    private String ttsProvider;

    @Value("${speech.text-to-speech.voices.male}")
    private String maleVoice;

    @Value("${speech.text-to-speech.voices.female}")
    private String femaleVoice;

    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(60, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .build();

    /**
     * Converts speech audio into text with speaker diarization.
     *
     * @param audioData            the raw audio bytes
     * @param userId               the user identifier used to resolve API
     *                             keys
     * @param languageCodeOverride optional language code overriding the
     *                             default configuration
     * @return the parsed recognition result containing diarized segments
     */
    public SpeechRecognitionResult recognizeSpeech(byte[] audioData, String userId, String languageCodeOverride) {
        String apiKey = apiKeyService.getGoogleCloudApiKey(userId);
        if (apiKey == null || apiKey.isEmpty()) {
            String message = "No Google Cloud API key found for user: " + userId;
            log.error(message);
            throw new IllegalStateException(message);
        }

        try {
            return callGoogleSpeechAPI(audioData, apiKey, languageCodeOverride);
        } catch (Exception e) {
            String message = "Error recognizing speech: " + e.getMessage();
            log.error(message, e);
            throw new IllegalStateException(message, e);
        }
    }

    /**
     * Converts text into synthesized speech audio using the configured
     * provider.
     *
     * @param text        the text to synthesize
     * @param voiceGender the desired voice gender (male or female)
     * @param userId      the user identifier used to resolve API keys
     * @return the synthesized audio bytes, or {@code null} if generation
     * fails
     */
    public byte[] textToSpeech(String text, String voiceGender, String userId) {
        String apiKey = apiKeyService.getGoogleCloudApiKey(userId);
        if (apiKey == null || apiKey.isEmpty()) {
            log.error("No Google Cloud API key found for user: {}", userId);
            return null;
        }

        String voiceName = "male".equalsIgnoreCase(voiceGender) ? maleVoice : femaleVoice;

        try {
            return callGoogleTTSAPI(text, voiceName, apiKey);
        } catch (Exception e) {
            log.error("Error generating speech: {}", e.getMessage(), e);
            return null;
        }
    }

    private SpeechRecognitionResult callGoogleSpeechAPI(byte[] audioData, String apiKey, String languageCodeOverride) throws IOException {
        String audioBase64 = Base64.getEncoder().encodeToString(audioData);

        JSONObject requestBody = new JSONObject();
        
        JSONObject config = new JSONObject();
        // Let Google auto-detect encoding; we currently send WAV from the client.
        // config.put("encoding", "LINEAR16");
        config.put("sampleRateHertz", 16000);
        String effectiveLanguageCode = (languageCodeOverride != null && !languageCodeOverride.isEmpty())
            ? languageCodeOverride
            : (recognitionLanguage != null && !recognitionLanguage.isEmpty() ? recognitionLanguage : "en-US");
        config.put("languageCode", effectiveLanguageCode);
        // Enable speaker diarization so we get stable speakerTag values
        // that can be mapped to participant first names during calibration.
        JSONObject diarizationConfig = new JSONObject();
        diarizationConfig.put("enableSpeakerDiarization", true);
        diarizationConfig.put("minSpeakerCount", 2);
        diarizationConfig.put("maxSpeakerCount", 6);
        config.put("diarizationConfig", diarizationConfig);
        config.put("model", "latest_long");
        config.put("useEnhanced", true);
        
        JSONObject audio = new JSONObject();
        audio.put("content", audioBase64);
        
        requestBody.put("config", config);
        requestBody.put("audio", audio);

        Request request = new Request.Builder()
                .url("https://speech.googleapis.com/v1/speech:recognize?key=" + apiKey)
                .header("Content-Type", "application/json")
                .post(RequestBody.create(requestBody.toString(), MediaType.parse("application/json")))
                .build();

        try (Response response = httpClient.newCall(request).execute()) {
            String bodyString = response.body() != null ? response.body().string() : "";

            if (!response.isSuccessful()) {
                String message = "Google Speech API error: " + response.code() + " - " + bodyString;
                log.error(message);
                throw new IOException(message);
            }

            JSONObject responseBody = new JSONObject(bodyString);
            return parseGoogleSpeechResponse(responseBody);
        }
    }

    private byte[] callGoogleTTSAPI(String text, String voiceName, String apiKey) throws IOException {
        JSONObject requestBody = new JSONObject();
        
        JSONObject input = new JSONObject();
        input.put("text", text);
        
        JSONObject voice = new JSONObject();
        voice.put("name", voiceName);
        voice.put("languageCode", "en-US");
        
        JSONObject audioConfig = new JSONObject();
        audioConfig.put("audioEncoding", "MP3");
        audioConfig.put("pitch", 0);
        audioConfig.put("speakingRate", 1.0);
        
        requestBody.put("input", input);
        requestBody.put("voice", voice);
        requestBody.put("audioConfig", audioConfig);

        Request request = new Request.Builder()
                .url("https://texttospeech.googleapis.com/v1/text:synthesize?key=" + apiKey)
                .header("Content-Type", "application/json")
                .post(RequestBody.create(requestBody.toString(), MediaType.parse("application/json")))
                .build();

        try (Response response = httpClient.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                log.error("Google TTS API error: {}", response.code());
                return null;
            }

            JSONObject responseBody = new JSONObject(response.body().string());
            String audioContentBase64 = responseBody.getString("audioContent");
            return Base64.getDecoder().decode(audioContentBase64);
        }
    }

    /**
     * Parses a Google Cloud Speech-to-Text response into a
     * {@link SpeechRecognitionResult}.
     *
     * @param response the JSON response from the API
     * @return the parsed recognition result
     */
    private SpeechRecognitionResult parseGoogleSpeechResponse(JSONObject response) {
        SpeechRecognitionResult result = new SpeechRecognitionResult();
        
        if (!response.has("results") || response.getJSONArray("results").isEmpty()) {
            return result;
        }

        var results = response.getJSONArray("results");
        for (int i = 0; i < results.length(); i++) {
            var resultObj = results.getJSONObject(i);
            if (!resultObj.has("alternatives")) {
                continue;
            }

            var alternatives = resultObj.getJSONArray("alternatives");
            if (alternatives.isEmpty()) {
                continue;
            }

            var alternative = alternatives.getJSONObject(0);
            String transcript = alternative.optString("transcript", "").trim();
            if (transcript.isEmpty()) {
                // No actual text returned for this alternative; skip it.
                continue;
            }

            double confidence = alternative.optDouble("confidence", 0.0);

            // Extract speaker information if available
            if (alternative.has("words")) {
                var words = alternative.getJSONArray("words");
                if (!words.isEmpty()) {
                    var firstWord = words.getJSONObject(0);
                    int speakerTag = firstWord.optInt("speakerTag", -1);
                    result.addSegment(transcript, confidence, speakerTag);
                    continue;
                }
            }

            result.addSegment(transcript, confidence, -1);
        }
        
        return result;
    }

    public static class SpeechRecognitionResult {
        private final java.util.List<TranscriptSegment> segments = new java.util.ArrayList<>();

        public void addSegment(String text, double confidence, int speakerTag) {
            segments.add(new TranscriptSegment(text, confidence, speakerTag));
        }

        public java.util.List<TranscriptSegment> getSegments() {
            return segments;
        }

        public static class TranscriptSegment {
            private final String text;
            private final double confidence;
            private final int speakerTag;

            public TranscriptSegment(String text, double confidence, int speakerTag) {
                this.text = text;
                this.confidence = confidence;
                this.speakerTag = speakerTag;
            }

            public String getText() {
                return text;
            }

            public double getConfidence() {
                return confidence;
            }

            public int getSpeakerTag() {
                return speakerTag;
            }
        }
    }
}
