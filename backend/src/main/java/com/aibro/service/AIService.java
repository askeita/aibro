package com.aibro.service;

import com.aibro.model.Contribution;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import okhttp3.*;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.List;
import java.util.concurrent.TimeUnit;


@Service
@RequiredArgsConstructor
@Slf4j
/**
 * Service responsible for interacting with external AI providers (Claude,
 * OpenAI, Gemini) to generate contributions and summaries based on
 * conversation context.
 */
public class AIService {

    private final ApiKeyService apiKeyService;
    private final OkHttpClient httpClient = new OkHttpClient.Builder()
            .connectTimeout(60, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(60, TimeUnit.SECONDS)
            .build();

    /**
     * Analyzes recent contributions and generates an AI response using the
     * configured provider.
     *
     * @param recentContributions the list of recent contributions to analyze
     * @param aiModel             the AI model identifier
     * @param userId              the user identifier used to resolve API
     *                            keys
     * @param languageCode        optional language code used to tailor the
     *                            response
     * @return the generated AI contribution text, or {@code null} if no
     * response could be produced
     */
    public String analyzeConversationAndContribute(List<Contribution> recentContributions,
                                                  String aiModel,
                                                  String userId,
                                                  String languageCode) {
        return analyzeConversationAndContribute(recentContributions, aiModel, userId, languageCode, null);
    }

    /**
     * Analyzes recent contributions and generates an AI response using the
     * configured provider, taking the session objective into account.
     *
     * @param recentContributions the list of recent contributions to analyze
     * @param aiModel             the AI model identifier
     * @param userId              the user identifier used to resolve API
     *                            keys
     * @param languageCode        optional language code used to tailor the
     *                            response
     * @param objective           optional session objective to focus ideas
     * @return the generated AI contribution text, or {@code null} if no
     * response could be produced
     */
    public String analyzeConversationAndContribute(List<Contribution> recentContributions,
                                                  String aiModel,
                                                  String userId,
                                                  String languageCode,
                                                  String objective) {
        String apiKey = getApiKeyForModel(aiModel, userId);
        if (apiKey == null || apiKey.isEmpty()) {
            log.warn("No API key found for model: {}", aiModel);
            return null;
        }

        String context = buildConversationContext(recentContributions);
        String languageInstruction = buildLanguageInstruction(languageCode);
        String objectiveInstruction = "";
        if (objective != null && !objective.isBlank()) {
            objectiveInstruction = "The objective of this brainstorming session is: \"" + objective.trim() + "\". "
                    + "Keep all of your ideas tightly focused on helping achieve this objective. ";
        }

        int averageHumanWords = computeAverageHumanWordCount(recentContributions);
        String lengthInstruction = buildLengthInstruction(averageHumanWords);

        String prompt = "You are participating in a brainstorming session. "
                + objectiveInstruction
                + languageInstruction
            + lengthInstruction
                + "Based on the following conversation, provide a creative and relevant contribution that helps move the group toward the objective.\n\n"
                + context;

        try {
            switch (aiModel.toLowerCase()) {
                case "claude":
                    return callClaudeAPI(prompt, apiKey);
                case "openai":
                    return callOpenAIAPI(prompt, apiKey);
                case "gemini":
                    return callGeminiAPI(prompt, apiKey);
                default:
                    log.error("Unknown AI model: {}", aiModel);
                    return null;
            }
        } catch (Exception e) {
            log.error("Error calling AI API: {}", e.getMessage(), e);
            return null;
        }
    }

    /**
     * Backwards-compatible overload for callers that do not specify a
     * language or objective.
     *
     * @param recentContributions the list of recent contributions to analyze
     * @param aiModel             the AI model identifier
     * @param userId              the user identifier used to resolve API
     *                            keys
     * @return the generated AI contribution text, or {@code null} if no
     * response could be produced
     */
    // Backwards-compatible overload for callers that don't specify a language.
    public String analyzeConversationAndContribute(List<Contribution> recentContributions,
                                                  String aiModel,
                                                  String userId) {
        return analyzeConversationAndContribute(recentContributions, aiModel, userId, null, null);
    }

    /**
     * Generates a textual summary for a completed session using the
     * configured AI model.
     *
     * @param contributions the full list of contributions in the session
     * @param aiModel       the AI model identifier
     * @param userId        the user identifier used to resolve API keys
     * @param objective     optional session objective to highlight in the
     *                      summary
     * @return the generated summary text, or an error message if the request
     * fails
     */
    public String generateSessionSummary(List<Contribution> contributions,
                                         String aiModel,
                                         String userId,
                                         String objective) {
        String apiKey = getApiKeyForModel(aiModel, userId);
        if (apiKey == null || apiKey.isEmpty()) {
            return "Summary generation failed: No API key configured.";
        }

        String context = buildConversationContext(contributions);
        String objectiveInstruction = "";
        if (objective != null && !objective.isBlank()) {
            objectiveInstruction = "The objective of this brainstorming session was: \"" + objective.trim() + "\". ";
        }

        String prompt = objectiveInstruction
                + "Please provide a comprehensive summary of the following brainstorming session, highlighting key ideas, themes, and how they relate to the stated objective (if any):\n\n"
                + context;

        try {
            switch (aiModel.toLowerCase()) {
                case "claude":
                    return callClaudeAPI(prompt, apiKey);
                case "openai":
                    return callOpenAIAPI(prompt, apiKey);
                case "gemini":
                    return callGeminiAPI(prompt, apiKey);
                default:
                    return "Summary generation failed: Unknown AI model.";
            }
        } catch (Exception e) {
            log.error("Error generating summary: {}", e.getMessage(), e);
            return "Summary generation failed: " + e.getMessage();
        }
    }

    /**
     * Overload of {@link #generateSessionSummary(List, String, String, String)}
     * that does not specify an objective.
     *
     * @param contributions the full list of contributions in the session
     * @param aiModel       the AI model identifier
     * @param userId        the user identifier used to resolve API keys
     * @return the generated summary text, or an error message if the request
     * fails
     */
    public String generateSessionSummary(List<Contribution> contributions, String aiModel, String userId) {
        return generateSessionSummary(contributions, aiModel, userId, null);
    }

    private int computeAverageHumanWordCount(List<Contribution> contributions) {
        if (contributions == null || contributions.isEmpty()) {
            return 0;
        }

        int totalWords = 0;
        int humanTurns = 0;

        for (Contribution c : contributions) {
            if (c == null || c.getType() != Contribution.ContributionType.HUMAN) {
                continue;
            }
            String content = c.getContent();
            if (content == null) {
                continue;
            }
            String trimmed = content.trim();
            if (trimmed.isEmpty()) {
                continue;
            }

            String[] words = trimmed.split("\\s+");
            totalWords += words.length;
            humanTurns++;
        }

        if (humanTurns == 0) {
            return 0;
        }

        return totalWords / humanTurns;
    }

    private String buildLengthInstruction(int averageHumanWords) {
        if (averageHumanWords <= 0) {
            return "";
        }

        return "On average, human participants are using about "
                + averageHumanWords
                + " words per contribution. Try to respond with a similar number of words (roughly plus or minus 30%), and avoid much longer paragraphs. ";
    }

    private String callClaudeAPI(String prompt, String apiKey) throws IOException {
        JSONObject requestBody = new JSONObject();
        requestBody.put("model", "claude-sonnet-4-20250514");
        requestBody.put("max_tokens", 1024);
        
        JSONArray messages = new JSONArray();
        JSONObject message = new JSONObject();
        message.put("role", "user");
        message.put("content", prompt);
        messages.put(message);
        requestBody.put("messages", messages);

        Request request = new Request.Builder()
                .url("https://api.anthropic.com/v1/messages")
                .header("x-api-key", apiKey)
                .header("anthropic-version", "2023-06-01")
                .header("content-type", "application/json")
                .post(RequestBody.create(requestBody.toString(), MediaType.parse("application/json")))
                .build();

        try (Response response = httpClient.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                log.error("Claude API error: {}", response.code());
                return null;
            }

            JSONObject responseBody = new JSONObject(response.body().string());
            JSONArray content = responseBody.getJSONArray("content");
            return content.getJSONObject(0).getString("text");
        }
    }

    private String callOpenAIAPI(String prompt, String apiKey) throws IOException {
        JSONObject requestBody = new JSONObject();
        requestBody.put("model", "gpt-4-turbo-preview");
        
        JSONArray messages = new JSONArray();
        JSONObject message = new JSONObject();
        message.put("role", "user");
        message.put("content", prompt);
        messages.put(message);
        requestBody.put("messages", messages);
        requestBody.put("max_tokens", 1024);

        Request request = new Request.Builder()
                .url("https://api.openai.com/v1/chat/completions")
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .post(RequestBody.create(requestBody.toString(), MediaType.parse("application/json")))
                .build();

        try (Response response = httpClient.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                log.error("OpenAI API error: {}", response.code());
                return null;
            }

            JSONObject responseBody = new JSONObject(response.body().string());
            return responseBody.getJSONArray("choices")
                    .getJSONObject(0)
                    .getJSONObject("message")
                    .getString("content");
        }
    }

    private String callGeminiAPI(String prompt, String apiKey) throws IOException {
        JSONObject requestBody = new JSONObject();
        
        JSONArray contents = new JSONArray();
        JSONObject content = new JSONObject();
        JSONArray parts = new JSONArray();
        JSONObject part = new JSONObject();
        part.put("text", prompt);
        parts.put(part);
        content.put("parts", parts);
        contents.put(content);
        requestBody.put("contents", contents);

        Request request = new Request.Builder()
                .url("https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=" + apiKey)
                .header("Content-Type", "application/json")
                .post(RequestBody.create(requestBody.toString(), MediaType.parse("application/json")))
                .build();

        try (Response response = httpClient.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                log.error("Gemini API error: {}", response.code());
                return null;
            }

            JSONObject responseBody = new JSONObject(response.body().string());
            return responseBody.getJSONArray("candidates")
                    .getJSONObject(0)
                    .getJSONObject("content")
                    .getJSONArray("parts")
                    .getJSONObject(0)
                    .getString("text");
        }
    }

    private String getApiKeyForModel(String aiModel, String userId) {
        return apiKeyService.getApiKeyForModel(aiModel, userId);
    }

    private String buildLanguageInstruction(String languageCode) {
        if (languageCode == null || languageCode.isEmpty()) {
            return "Please respond in the same language as the conversation. ";
        }

        String languageName;
        switch (languageCode) {
            case "ar":
                languageName = "Arabic";
                break;
            case "fr-FR":
                languageName = "French";
                break;
            case "de-DE":
                languageName = "German";
                break;
            case "it-IT":
                languageName = "Italian";
                break;
            case "pt-PT":
                languageName = "Portuguese";
                break;
            case "es-ES":
                languageName = "Spanish";
                break;
            case "en-US":
            default:
                languageName = "English";
                break;
        }

        return "The user speaks " + languageName + ". Respond only in " + languageName + ". ";
    }

    private String buildConversationContext(List<Contribution> contributions) {
        StringBuilder context = new StringBuilder();
        int limit = Math.min(contributions.size(), 10); // Last 10 contributions
        int start = Math.max(0, contributions.size() - limit);
        
        for (int i = start; i < contributions.size(); i++) {
            Contribution c = contributions.get(i);
            context.append(c.getSpeaker()).append(": ").append(c.getContent()).append("\n");
        }
        
        return context.toString();
    }
}
