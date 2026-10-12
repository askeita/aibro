package com.aibro.service;

import com.aibro.model.Contribution;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Protocol;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;
import okio.Buffer;
import org.json.JSONObject;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link AIService}. Provider HTTP calls are answered by an
 * in-memory OkHttp interceptor, so no network access is needed.
 */
@ExtendWith(MockitoExtension.class)
class AIServiceTest {

    private static final String USER_ID = "user1";
    private static final String API_KEY = "provider-key";
    private static final String OPENAI_REPLY = "{\"choices\":[{\"message\":{\"content\":\"Idea\"}}]}";

    @Mock
    private ApiKeyService apiKeyService;

    @InjectMocks
    private AIService aiService;

    private final AtomicReference<Request> capturedRequest = new AtomicReference<>();

    @Test
    void analyzeConversation_returnsNullWhenApiKeyIsMissing() {
        when(apiKeyService.getApiKeyForModel("openai", USER_ID)).thenReturn(null);

        assertThat(aiService.analyzeConversationAndContribute(List.of(), "openai", USER_ID)).isNull();
    }

    @Test
    void analyzeConversation_returnsNullWhenApiKeyIsEmpty() {
        when(apiKeyService.getApiKeyForModel("claude", USER_ID)).thenReturn("");

        assertThat(aiService.analyzeConversationAndContribute(List.of(), "claude", USER_ID, "en-US", null)).isNull();
    }

    @Test
    void analyzeConversation_returnsNullForUnknownProvider() {
        when(apiKeyService.getApiKeyForModel("unknown", USER_ID)).thenReturn(API_KEY);

        assertThat(aiService.analyzeConversationAndContribute(List.of(), "unknown", USER_ID)).isNull();
    }

    @Test
    void generateSessionSummary_reportsMissingApiKey() {
        when(apiKeyService.getApiKeyForModel("gemini", USER_ID)).thenReturn(null);

        assertThat(aiService.generateSessionSummary(List.of(), "gemini", USER_ID))
                .isEqualTo("Summary generation failed: No API key configured.");
    }

    @Test
    void generateSessionSummary_reportsUnknownProvider() {
        when(apiKeyService.getApiKeyForModel("unknown", USER_ID)).thenReturn(API_KEY);

        assertThat(aiService.generateSessionSummary(List.of(), "unknown", USER_ID, null))
                .isEqualTo("Summary generation failed: Unknown AI model.");
    }

    @Test
    void analyzeConversation_sendsOpenAiRequestAndParsesResponse() throws IOException {
        givenApiKey("openai");
        givenProviderReplies("{\"choices\":[{\"message\":{\"content\":\"OpenAI idea\"}}]}", 200);
        List<Contribution> contributions = List.of(
                contribution("Alice", "one two three", Contribution.ContributionType.HUMAN),
                contribution("Bot", "Consider a prototype", Contribution.ContributionType.AI),
                contribution("Bob", "four", Contribution.ContributionType.HUMAN));

        String result = aiService.analyzeConversationAndContribute(
                contributions, "openai", USER_ID, "fr-FR", "  launch planning  ");

        assertThat(result).isEqualTo("OpenAI idea");
        assertThat(capturedRequest.get().url().toString()).isEqualTo("https://api.openai.com/v1/chat/completions");
        assertThat(capturedRequest.get().header("Authorization")).isEqualTo("Bearer " + API_KEY);
        // Alice (3 words) and Bob (1 word) average to 2 words per human turn.
        assertThat(messagesPrompt()).contains(
                "The user speaks French", "launch planning", "about 2 words", "Alice: one two three");
    }

    @Test
    void generateSessionSummary_sendsClaudeRequestAndParsesResponse() throws IOException {
        givenApiKey("claude");
        givenProviderReplies("{\"content\":[{\"text\":\"Claude summary\"}]}", 200);

        String result = aiService.generateSessionSummary(List.of(), "claude", USER_ID, "  team alignment  ");

        assertThat(result).isEqualTo("Claude summary");
        assertThat(capturedRequest.get().url().toString()).isEqualTo("https://api.anthropic.com/v1/messages");
        assertThat(capturedRequest.get().header("x-api-key")).isEqualTo(API_KEY);
        assertThat(messagesPrompt()).contains("team alignment");
    }

    @Test
    void generateSessionSummary_sendsGeminiRequestAndParsesResponse() throws IOException {
        givenApiKey("gemini");
        givenProviderReplies("{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Gemini summary\"}]}}]}", 200);
        List<Contribution> contributions = List.of(contribution("Riley", "Prototype", null));

        String result = aiService.generateSessionSummary(contributions, "gemini", USER_ID);

        assertThat(result).isEqualTo("Gemini summary");
        assertThat(capturedRequest.get().url().host()).isEqualTo("generativelanguage.googleapis.com");
        String prompt = requestBody().getJSONArray("contents").getJSONObject(0)
                .getJSONArray("parts").getJSONObject(0).getString("text");
        assertThat(prompt).contains("Riley: Prototype");
    }

    @ParameterizedTest
    @ValueSource(strings = {"claude", "openai", "gemini"})
    void analyzeConversation_returnsNullWhenProviderRejectsRequest(String provider) {
        givenApiKey(provider);
        givenProviderReplies("{}", 500);

        assertThat(aiService.analyzeConversationAndContribute(List.of(), provider, USER_ID)).isNull();
    }

    @ParameterizedTest
    @CsvSource({
            "ar, Arabic",
            "de-DE, German",
            "it-IT, Italian",
            "pt-PT, Portuguese",
            "es-ES, Spanish",
            "en-US, English",
            "xx, English"
    })
    void analyzeConversation_usesConfiguredLanguage(String languageCode, String languageName) throws IOException {
        givenApiKey("openai");
        givenProviderReplies(OPENAI_REPLY, 200);

        String result = aiService.analyzeConversationAndContribute(List.of(), "openai", USER_ID, languageCode, null);

        assertThat(result).isEqualTo("Idea");
        assertThat(messagesPrompt())
                .contains("The user speaks " + languageName + ". Respond only in " + languageName + ".");
    }

    @ParameterizedTest
    @NullAndEmptySource
    void analyzeConversation_usesConversationLanguageWhenCodeIsMissing(String languageCode) throws IOException {
        givenApiKey("openai");
        givenProviderReplies(OPENAI_REPLY, 200);
        List<Contribution> contributions = List.of(
                contribution("Assistant", "Prior thought", Contribution.ContributionType.AI),
                contribution("Alice", null, Contribution.ContributionType.HUMAN),
                contribution("Bob", "   ", Contribution.ContributionType.HUMAN));

        aiService.analyzeConversationAndContribute(contributions, "openai", USER_ID, languageCode, "  ");

        assertThat(messagesPrompt()).contains(
                "Please respond in the same language as the conversation.", "Assistant: Prior thought");
        assertThat(messagesPrompt()).doesNotContain("words per contribution", "objective of this brainstorming session");
    }

    @Test
    void analyzeConversation_limitsContextToMostRecentTenContributions() throws IOException {
        givenApiKey("openai");
        givenProviderReplies(OPENAI_REPLY, 200);
        List<Contribution> contributions = new ArrayList<>();
        for (int index = 0; index < 12; index++) {
            contributions.add(contribution("Participant", "Idea " + index, Contribution.ContributionType.HUMAN));
        }

        aiService.analyzeConversationAndContribute(contributions, "openai", USER_ID);

        // The trailing newline stops "Idea 1" from matching "Idea 10" or "Idea 11".
        assertThat(messagesPrompt()).doesNotContain("Participant: Idea 0\n", "Participant: Idea 1\n");
        assertThat(messagesPrompt()).contains("Participant: Idea 2\n", "Participant: Idea 11\n");
    }

    @Test
    void analyzeConversation_returnsNullWhenProviderResponseIsMalformed() {
        givenApiKey("openai");
        givenProviderReplies("{\"choices\":[]}", 200);

        assertThat(aiService.analyzeConversationAndContribute(List.of(), "openai", USER_ID)).isNull();
    }

    @Test
    void generateSessionSummary_reportsMalformedProviderResponse() {
        givenApiKey("gemini");
        givenProviderReplies("not-json", 200);

        assertThat(aiService.generateSessionSummary(List.of(), "gemini", USER_ID))
                .startsWith("Summary generation failed:");
    }

    private void givenApiKey(String provider) {
        when(apiKeyService.getApiKeyForModel(provider, USER_ID)).thenReturn(API_KEY);
    }

    private void givenProviderReplies(String responseBody, int statusCode) {
        OkHttpClient client = new OkHttpClient.Builder()
                .addInterceptor(chain -> {
                    capturedRequest.set(chain.request());
                    return new Response.Builder()
                            .request(chain.request())
                            .protocol(Protocol.HTTP_1_1)
                            .code(statusCode)
                            .message("stubbed")
                            .body(ResponseBody.create(responseBody, MediaType.parse("application/json")))
                            .build();
                })
                .build();
        ReflectionTestUtils.setField(aiService, "httpClient", client);
    }

    private Contribution contribution(String speaker, String content, Contribution.ContributionType type) {
        return Contribution.builder().speaker(speaker).content(content).type(type).build();
    }

    // Claude and OpenAI both send the prompt as messages[0].content.
    private String messagesPrompt() throws IOException {
        return requestBody().getJSONArray("messages").getJSONObject(0).getString("content");
    }

    private JSONObject requestBody() throws IOException {
        Buffer buffer = new Buffer();
        capturedRequest.get().body().writeTo(buffer);
        return new JSONObject(buffer.readUtf8());
    }
}
