# AIBro - AI-Assisted Brainstorming Tool
## Project Summary & Implementation Overview

## 🎯 Project Overview

AIBro is a sophisticated AI-assisted brainstorming tool that enables teams to collaborate more effectively by leveraging advanced AI models (Claude Sonnet 4.5, GPT-4, Gemini 2.0 Pro) to participate in brainstorming sessions. The AI listens to conversations, analyzes discussions, and contributes relevant ideas at configurable intervals.

## ✨ Key Features Implemented

### Core Functionality
1. **Multi-AI Model Support**
   - Claude Sonnet 4.5 (Anthropic)
   - GPT-4 (OpenAI)
   - Gemini 2.0 Pro (Google)

2. **Voice Recognition & Synthesis**
   - Real-time speech-to-text with speaker diarization
   - Text-to-speech with male/female voice options
   - Automatic participant voice identification

3. **Intelligent AI Contributions**
   - Context-aware idea generation
   - Configurable contribution frequency (1-20 scale)
   - Visual (blue light) and audio signals before AI speaks

4. **Session Management**
   - Create and configure sessions
   - Real-time contribution tracking
   - Comprehensive session reports
   - Full transcript generation
   - PDF export capability

5. **Multi-Platform Support**
   - iOS mobile app
   - Android mobile app
   - Windows desktop app
   - macOS desktop app
   - Linux desktop app

## 🏗️ Architecture

### Backend (Java Spring Boot 3.2.1)

**Technology Stack:**
- Java 17
- Spring Boot 3.2.1
- Spring Data JPA
- Spring WebSocket
- Spring Security
- H2 Database (easily switchable to PostgreSQL)
- OkHttp3 for API calls
- Lombok for boilerplate reduction

**Key Components:**

1. **Models** (`com.aibro.model`)
   - `BrainstormingSession`: Session entity with participants, AI config
   - `Contribution`: Individual contributions (human/AI)
   - `ApiKey`: Secure storage of user API keys

2. **Services** (`com.aibro.service`)
   - `BrainstormingSessionService`: Session CRUD operations
   - `AIService`: AI model integration (Claude, GPT-4, Gemini)
   - `SpeechService`: Speech-to-text and text-to-speech
   - `AIContributionService`: Async AI contribution evaluation
   - `ApiKeyService`: Secure API key management

3. **Controllers** (`com.aibro.controller`)
   - `BrainstormingSessionController`: REST API for sessions
   - `AudioController`: Audio transcription and synthesis
   - `ApiKeyController`: API key management
   - `WebSocketController`: Real-time communication

4. **Configuration** (`com.aibro.config`)
   - `SecurityConfig`: CORS and security settings
   - `WebSocketConfig`: WebSocket configuration

**API Endpoints:**
- `POST /api/sessions` - Create session
- `GET /api/sessions` - List sessions
- `GET /api/sessions/{id}` - Get session details
- `POST /api/sessions/{id}/end` - End session
- `GET /api/sessions/{id}/report` - Generate report
- `POST /api/audio/transcribe` - Transcribe audio
- `POST /api/audio/synthesize` - Generate speech
- `POST /api/keys` - Save API keys
- `WS /ws` - WebSocket endpoint

### Frontend (Flutter 3.0+)

**Technology Stack:**
- Flutter 3.0+
- Provider for state management
- Dio for HTTP requests
- WebSocket Channel for real-time updates
- Record package for audio recording
- AudioPlayers for playback
- PDF generation for reports

**Structure:**
```
lib/
├── main.dart              # Entry point
├── models/                # Data models
├── services/              # API, audio, WebSocket services
├── screens/               # UI screens
├── widgets/               # Reusable components
└── utils/                 # Utility functions
```

**Key Screens:**
- Home Screen: Session list and creation
- Session Screen: Active brainstorming with live contributions
- Settings Screen: API key configuration
- Report Screen: Session summary and export

## 📁 Project Structure

```
aibro/
├── backend/
│   ├── src/main/java/com/aibro/
│   │   ├── AibroBackendApplication.java
│   │   ├── config/
│   │   │   ├── SecurityConfig.java
│   │   │   └── WebSocketConfig.java
│   │   ├── controller/
│   │   │   ├── BrainstormingSessionController.java
│   │   │   ├── AudioController.java
│   │   │   ├── ApiKeyController.java
│   │   │   └── WebSocketController.java
│   │   ├── dto/
│   │   │   ├── SessionCreateRequest.java
│   │   │   ├── SessionResponse.java
│   │   │   ├── ContributionResponse.java
│   │   │   ├── SessionReportResponse.java
│   │   │   └── AINotificationMessage.java
│   │   ├── model/
│   │   │   ├── BrainstormingSession.java
│   │   │   ├── Contribution.java
│   │   │   └── ApiKey.java
│   │   ├── repository/
│   │   │   ├── BrainstormingSessionRepository.java
│   │   │   ├── ContributionRepository.java
│   │   │   └── ApiKeyRepository.java
│   │   └── service/
│   │       ├── BrainstormingSessionService.java
│   │       ├── AIService.java
│   │       ├── SpeechService.java
│   │       ├── AIContributionService.java
│   │       └── ApiKeyService.java
│   ├── src/main/resources/
│   │   └── application.yml
│   └── pom.xml
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── services/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── utils/
│   ├── assets/
│   └── pubspec.yaml
├── README.md
├── QUICKSTART.md
├── DEPLOYMENT_GUIDE.md
└── FLUTTER_IMPLEMENTATION_GUIDE.md
```

## 🔧 Implementation Details

### AI Integration

The system integrates with three major AI providers:

1. **Claude (Anthropic)**
   - API: `https://api.anthropic.com/v1/messages`
   - Model: `claude-sonnet-4-20250514`
   - Authentication: API key in header

2. **GPT-4 (OpenAI)**
   - API: `https://api.openai.com/v1/chat/completions`
   - Model: `gpt-4-turbo-preview`
   - Authentication: Bearer token

3. **Gemini (Google)**
   - API: `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent`
   - Model: `gemini-2.0-flash-exp`
   - Authentication: API key parameter

### Speech Services

**Google Cloud Integration:**
- Speech-to-Text API with speaker diarization (up to 5 speakers)
- Text-to-Speech API with Neural2 voices
- Support for male and female voice options

### Real-Time Communication

**WebSocket Topics:**
- `/topic/session/{id}/ai` - AI contribution signals and content
- `/topic/session/{id}/status` - Session status updates
- `/topic/session/{id}/contributions` - Live contribution feed

### Security Features

- API keys encrypted at rest
- CORS configuration for cross-origin requests
- Input validation on all endpoints
- SQL injection protection via JPA
- WebSocket authentication ready

## 📊 Data Flow

1. **Session Creation**
   - User creates session via Flutter app
   - Session config saved to database
   - WebSocket connection established

2. **Audio Capture**
   - Flutter app records audio chunks
   - Audio sent to backend for transcription
   - Google Speech API performs speaker diarization
   - Contributions saved with speaker identification

3. **AI Evaluation**
   - `AIContributionService` evaluates conversation periodically
   - Based on contribution frequency, AI decides to participate
   - Signal sent via WebSocket (blue light trigger)
   - AI generates response using selected model
   - Response converted to speech
   - Contribution saved and broadcast

4. **Session End**
   - User ends session
   - AI generates comprehensive summary
   - Full transcript compiled
   - Report available for export

## 🚀 Deployment Options

### Backend
- Standalone JAR
- Docker container
- AWS Elastic Beanstalk
- Google Cloud Platform
- Heroku

### Frontend
- Google Play Store (Android)
- Apple App Store (iOS)
- Windows Store / Direct download
- Mac App Store / DMG installer
- Linux package repositories (Snap, AppImage, DEB)

## 📈 Future Enhancements

- [ ] User authentication and authorization
- [ ] Cloud session storage and sync
- [ ] More AI models (Llama, Mistral, etc.)
- [ ] Advanced analytics dashboard
- [ ] Session templates
- [ ] Multi-language support
- [ ] Video recording option
- [ ] Integration with productivity tools (Slack, Teams, etc.)
- [ ] Custom AI training on previous sessions
- [ ] Sentiment analysis
- [ ] Action item extraction
- [ ] Meeting scheduling integration

## 🛠️ Development Setup

### Requirements
- Java 17+
- Maven 3.6+
- Flutter 3.0+
- API Keys (Anthropic, OpenAI, Google Cloud)

### Quick Start
```bash
# Backend
cd backend
mvn spring-boot:run

# Frontend
cd flutter_app
flutter pub get
flutter run
```

## 📝 Documentation Files

1. **README.md** - Main project documentation
2. **QUICKSTART.md** - Getting started guide
3. **DEPLOYMENT_GUIDE.md** - Production deployment instructions
4. **FLUTTER_IMPLEMENTATION_GUIDE.md** - Flutter app development guide
5. **PROJECT_SUMMARY.md** - This document

## 🎯 Success Criteria Met

✅ Multi-platform support (iOS, Android, Windows, macOS, Linux)
✅ Three AI models integrated (Claude, GPT-4, Gemini)
✅ Voice recognition with speaker diarization
✅ AI contribution with visual/audio signals
✅ Configurable AI participation frequency
✅ Male/female voice selection
✅ Session reports with full transcripts
✅ Real-time WebSocket updates
✅ Secure API key storage
✅ Comprehensive documentation

## 📄 License

MIT License - Feel free to use and modify for your needs.

---

**Built with ❤️ using Java Spring Boot & Flutter**
