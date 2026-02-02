# AiBro – Copilot Instructions for AI Coding Agents

These instructions capture repo-specific knowledge so you can be productive immediately. Keep changes minimal, match existing patterns, and prefer updating docs when behavior changes.

## Big Picture
- Backend: Spring Boot 3.2 (Java 17) providing REST + WebSocket for sessions, audio, and keys. See [backend/src/main/java/com/aibro](../backend/src/main/java/com/aibro).
- Frontend: Flutter app consuming REST and STOMP topics for real-time updates. See [flutter_app/lib](../flutter_app/lib).
- Data flow: Audio → STT diarization → save human `Contribution` → async AI evaluation → AI text (+ optional TTS) → broadcast via WebSocket → persisted and shown in UI.

## Architecture & Boundaries
- Controllers: REST in [controller](../backend/src/main/java/com/aibro/controller) map 1:1 to use-cases. Examples:
  - Sessions: [BrainstormingSessionController.java](../backend/src/main/java/com/aibro/controller/BrainstormingSessionController.java)
  - Audio: [AudioController.java](../backend/src/main/java/com/aibro/controller/AudioController.java)
  - API Keys: [ApiKeyController.java](../backend/src/main/java/com/aibro/controller/ApiKeyController.java)
  - WebSocket: [WebSocketController.java](../backend/src/main/java/com/aibro/controller/WebSocketController.java)
- Services encapsulate integrations and business rules:
  - AI: [AIService.java](../backend/src/main/java/com/aibro/service/AIService.java) (Claude/OpenAI/Gemini via OkHttp)
  - AI Orchestration: [AIContributionService.java](../backend/src/main/java/com/aibro/service/AIContributionService.java) (decides when to contribute; pushes STOMP messages)
  - Speech: [SpeechService.java](../backend/src/main/java/com/aibro/service/SpeechService.java) (Google STT/TTS)
  - Sessions: [BrainstormingSessionService.java](../backend/src/main/java/com/aibro/service/BrainstormingSessionService.java)
- Persistence: `model` + `repository`. DTOs in [dto](../backend/src/main/java/com/aibro/dto) define API contracts.

## Real-time Channels
- Config in [application.yml](../backend/src/main/resources/application.yml):
  - STOMP endpoint: `/ws`, app prefix `/app`, topic prefix `/topic` (see [WebSocketConfig.java](../backend/src/main/java/com/aibro/config/WebSocketConfig.java)).
  - Topics used by server-side push: `/topic/session/{id}/ai`, `/topic/session/{id}/status`, `/topic/session/{id}/contributions`.
- Server publishes via `SimpMessagingTemplate` in `AIContributionService`.

## REST Endpoints (canonical)
- Sessions: `POST /api/sessions`, `GET /api/sessions`, `GET /api/sessions/{id}`, `PUT /api/sessions/{id}`, `POST /api/sessions/{id}/end`, `GET /api/sessions/{id}/report`.
- Audio: `POST /api/audio/transcribe` (multipart: `audio`, `sessionId`, `userId`), `POST /api/audio/synthesize`.
- API Keys: `POST /api/keys`, `GET /api/keys/validate/{model}?userId=...`.
- Contract examples: [SessionCreateRequest.java](../backend/src/main/java/com/aibro/dto/SessionCreateRequest.java), [SessionResponse.java](../backend/src/main/java/com/aibro/dto/SessionResponse.java), [ContributionResponse.java](../backend/src/main/java/com/aibro/dto/ContributionResponse.java).

## Conventions & Inputs
- `aiModel` accepted values: `claude`, `openai`, `gemini` (switch handled in `AIService`).
- AI frequency: integer 1–20 (higher = more talkative), enforced by `AIContributionService.decideIfShouldContribute()`.
- Voice gender: `male` | `female` used by TTS voice selection in `SpeechService`.
- Security/CORS: open by default for local/dev; see [SecurityConfig.java](../backend/src/main/java/com/aibro/config/SecurityConfig.java). No auth token enforcement yet.

## Configuration
- Single source of truth: [application.yml](../backend/src/main/resources/application.yml). Includes:
  - DB: H2 in-memory (`jdbc:h2:mem:aibrodb`), H2 console `/h2-console`.
  - WebSocket prefixes and endpoint.
  - AI model names and base URLs.
  - Speech providers and voice ids (`en-US-Neural2-D/F`).
  - Logging levels.
- API keys are user-scoped and retrieved via `ApiKeyService` (not committed to code).

## Build, Run, Test
- Backend (from repo root):
  - Build: `cd backend && mvn clean install`
  - Run: `cd backend && mvn spring-boot:run` (serves at http://localhost:8080)
  - Quick checks: Health `/actuator/health`, Swagger `/swagger-ui.html`, H2 `/h2-console` (user `sa`).
- Flutter app:
  - `cd flutter_app && flutter pub get && flutter run`
  - API base URL is hardcoded to `http://localhost:8080/api` in early templates; production uses a `--dart-define` (see deployment docs).

## Patterns You Should Follow
- Add a new endpoint: Controller → DTOs → Service. Return DTOs, not entities.
- Emit real-time events by posting to the appropriate `/topic/session/{id}/...` channel via `SimpMessagingTemplate`.
- Persist conversation via `ContributionRepository` and let `AIContributionService` decide when to speak.
- For new AI providers: extend switch in `AIService.analyzeConversationAndContribute()` and `generateSessionSummary()`, add config under `ai.models` in `application.yml`, and wire key retrieval in `ApiKeyService`.
- For speech changes: keep Google STT diarization fields and `16000` sample rate unless backend and clients change together.

## Client Integration (Flutter)
- HTTP: Dio-based `ApiService` (see template in [flutter_app/FLUTTER_IMPLEMENTATION_GUIDE.md](../flutter_app/FLUTTER_IMPLEMENTATION_GUIDE.md)).
- Real-time: `web_socket_channel` to `/ws`; subscribe to `/topic/session/{id}/ai` etc.
- Project structure: models/services/screens/widgets in [flutter_app/lib](../flutter_app/lib). Use provided templates when adding features.

## Useful File Map
- AI: [backend/src/main/java/com/aibro/service/AIService.java](../backend/src/main/java/com/aibro/service/AIService.java)
- Orchestration: [backend/src/main/java/com/aibro/service/AIContributionService.java](../backend/src/main/java/com/aibro/service/AIContributionService.java)
- Speech: [backend/src/main/java/com/aibro/service/SpeechService.java](../backend/src/main/java/com/aibro/service/SpeechService.java)
- Sessions: [backend/src/main/java/com/aibro/controller/BrainstormingSessionController.java](../backend/src/main/java/com/aibro/controller/BrainstormingSessionController.java)
- Config: [backend/src/main/resources/application.yml](../backend/src/main/resources/application.yml), [backend/src/main/java/com/aibro/config](../backend/src/main/java/com/aibro/config)

## Gotchas
- Keep `aiModel` string values consistent across client and server.
- Multipart upload for `/api/audio/transcribe` must include `audio` bytes and query fields; server expects 16kHz mono LINEAR16 in current config.
- WebSocket: STOMP app prefix `/app`, topics `/topic/*`; SockJS is enabled.
- CORS is permissive for dev; tighten before production.
