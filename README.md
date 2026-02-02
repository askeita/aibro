# AiBro - AI-Assisted Brainstorming Tool

An intelligent brainstorming assistant that listens to conversations, analyzes discussions, and contributes ideas using advanced AI models (Claude Sonnet 4.5, GPT-4, Gemini 2.0).

## Features

- **Multi-Platform Support**: Available as mobile apps (iOS/Android) and desktop applications (Windows/macOS/Linux)
- **Voice Recognition**: Real-time speech-to-text with speaker diarization
- **Voice Calibration & Mapping**: Optional per-session calibration step where each participant briefly introduces themselves so diarized speaker tags can be mapped to their first names
- **AI Models**: Support for Claude Sonnet 4.5, GPT-4, and Gemini 2.0 Pro
- **Smart Contributions**: AI analyzes conversations, contributes relevant ideas, and targets a length close to the average number of words used by human participants
- **Configurable Frequency**: Tune how often the AI participates
- **Voice Selection**: Choose between male and female AI voices
- **Session Reports**: Comprehensive summaries with full transcripts and AI-generated, Word-compatible (RTF) reports saved locally
- **Real-time Updates**: WebSocket-based real-time session synchronization
- **Session-Level Recording**: Optional full-session audio recording stored locally on the device under an `aibro/audios` folder (Linux, Windows, macOS, Android, iOS)
- **Previous Sessions Library**: Browse, play, share, or delete past session recordings from the device

## Architecture

### Backend (Java Spring Boot)
- **Spring Boot 3.2.1** with Java 17
- RESTful APIs for session management
- WebSocket support for real-time communication
- Integration with Claude, OpenAI, and Gemini APIs
- Google Cloud Speech-to-Text and Text-to-Speech
- H2 in-memory database (easily switchable to PostgreSQL)

### Frontend (Flutter)
- Cross-platform mobile and desktop application
- Provider/BLoC for state management
- Audio recording and playback
- Real-time WebSocket communication
- Beautiful, responsive UI

## Getting Started

### Prerequisites

- Java 17 or higher
- Maven 3.6+
- Flutter 3.0+
- API Keys:
  - Anthropic (Claude)
  - OpenAI (GPT-4)
  - Google Cloud (Gemini & Speech services)

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Build the project:
```bash
mvn clean install
```

3. Run the application:
```bash
mvn spring-boot:run
```

The backend will start on `http://localhost:8080`

### Frontend Setup

1. Navigate to the Flutter app directory:
```bash
cd flutter_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run on your preferred platform:
```bash
# For Android
flutter run -d android

# For iOS
flutter run -d ios

# For Desktop (Windows)
flutter run -d windows

# For Desktop (macOS)
flutter run -d macos

# For Desktop (Linux)
flutter run -d linux
```

## API Configuration

Users must configure their API keys in the app settings:

1. Open the app
2. Navigate to Settings
3. Enter your API keys:
   - Claude API Key
   - OpenAI API Key
   - Google Cloud API Key (for Speech services and Gemini)

## Usage

1. **Start a Session**:
   - First, configure AI model, contribution frequency (1–20), and AI voice (male/female) in the Settings screen
   - From the Home screen, tap **Start Session**
   - Enter the number of participants (integer between 1 and 6)
   - Enter each participant's first name
   - Define the objective of the brainstorming session
   - If there are at least 2 participants, you can optionally run a short **Calibrate voices** step where, in order, each participant briefly introduces themselves so AiBro can map diarized voices to their first names
   - During the session, you can optionally start a **session-level recording** from the session header card; the audio will be stored locally on the device and can be reviewed later

2. **During the Session**:
   - The app listens to conversations
   - AI analyzes discussions in real-time
   - When AI has an idea:
     - Blue light indicator appears
     - Sound notification plays
     - AI speaks its contribution
   - AI contributions aim for a word count similar to the average length of human contributions, so the assistant does not dominate the conversation
   - You can toggle a **session timer** from the session header card, either as a simple elapsed-time indicator or as a countdown to a target session duration; when running, the timer is prominently displayed above the session controls

3. **End Session**:
   - Tap **End session** in the session header; a confirmation dialog will appear before closing the session
   - If there is **no discussion and no full-session recording**, you are returned to the Home screen
   - If there is **either a discussion or a full-session recording**, you are taken to the **Report** screen for that session
   - From the Report screen you can generate a comprehensive, Word-compatible (RTF) report that includes participants, objective, selected AI model, duration (when available), ideas grouped by participant, a contributions timeline, and an AI-refined textual summary

4. **Review Previous Sessions (Recordings)**:
    - From the Home screen, tap **Previous sessions**
    - See a list of all full-session audio recordings stored on the current device, with session id, objective, timestamp, and file name
    - For each recording you can:
       - Play or stop the audio directly in the app
       - Open the recording in the system's default file handler (or its containing folder on desktop platforms)
       - Export/share the audio via email or other apps
       - Delete the recording from the device

5. **Local File Storage (Reports & Audio)**:
   - On each platform, AiBro uses the OS documents directory as a base and creates an `aibro` folder
   - **Reports** are generated as Word-compatible `.rtf` files under `aibro/reports`
   - **Full-session audio recordings** are stored under `aibro/audios`

## API Endpoints

### Sessions
- `POST /api/sessions` - Create new session
- `GET /api/sessions` - List all sessions
- `GET /api/sessions/{id}` - Get session details
- `PUT /api/sessions/{id}` - Update session
- `POST /api/sessions/{id}/end` - End session
- `GET /api/sessions/{id}/report` - Get session report

### Audio
- `POST /api/audio/transcribe` - Transcribe audio with speaker diarization
- `POST /api/audio/synthesize` - Convert text to speech
- `POST /api/audio/calibrate` - Calibrate diarized speakers against participant first names using a short introduction round

### API Keys
- `POST /api/keys` - Save API keys
- `GET /api/keys/validate/{model}` - Validate API key for specific model

### WebSocket
- `/ws` - WebSocket endpoint
- `/topic/session/{id}/ai` - AI contributions
- `/topic/session/{id}/status` - Session status updates
- `/topic/session/{id}/contributions` - Real-time contributions

## Project Structure

```
aibro/
├── backend/                    # Spring Boot backend
│   ├── src/main/java/com/aibro/
│   │   ├── config/            # Configuration classes
│   │   ├── controller/        # REST & WebSocket controllers
│   │   ├── dto/               # Data transfer objects
│   │   ├── model/             # JPA entities
│   │   ├── repository/        # Data repositories
│   │   └── service/           # Business logic
│   ├── src/main/resources/
│   │   └── application.yml    # Application configuration
│   └── pom.xml
├── flutter_app/               # Flutter frontend
│   ├── lib/
│   │   ├── models/           # Data models
│   │   ├── services/         # API & business services
│   │   ├── screens/          # UI screens
│   │   ├── widgets/          # Reusable widgets
│   │   └── utils/            # Utility functions
│   ├── assets/               # Images, sounds, animations
│   └── pubspec.yaml
└── README.md
```

## Technologies Used

### Backend
- Spring Boot 3.2.1
- Spring Data JPA
- Spring WebSocket
- Spring Security
- OkHttp3
- H2 Database
- Lombok
- Maven

### Frontend
- Flutter 3.0+
- Provider (State Management)
- Dio (HTTP Client)
- WebSocket Channel
- Audio Recorder
- Audio Players
- PDF / report export (including Word-compatible RTF generation stored under `aibro/reports`)
- Shared Preferences

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License.

## Support

For issues and questions, please create an issue in the repository.
