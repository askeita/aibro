# Quick Start Guide

## Prerequisites Installation

### Install Java 17
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install openjdk-17-jdk

# macOS
brew install openjdk@17

# Windows
# Download from https://adoptium.net/
```

### Install Maven
```bash
# Ubuntu/Debian
sudo apt install maven

# macOS
brew install maven

# Windows
# Download from https://maven.apache.org/download.cgi
```

### Install Flutter
```bash
# Linux/macOS
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Or download from https://flutter.dev/docs/get-started/install
```

## API Keys Setup

You'll need API keys from:

1. **Anthropic (Claude)**: https://console.anthropic.com/
2. **OpenAI (GPT-4)**: https://platform.openai.com/api-keys
3. **Google Cloud (Gemini & Speech)**: https://console.cloud.google.com/

## Running the Application

### 1. Start the Backend

```bash
cd backend
mvn spring-boot:run
```

Backend will be available at: `http://localhost:8080`

### 2. Start the Flutter App

```bash
cd flutter_app

# Get dependencies
flutter pub get

# Run on your device
flutter run
```

## First Time Setup in the App

1. **Configure API Keys**:
   - Open the app
   - Go to Settings
   - Enter your API keys for:
     - Claude API Key
     - OpenAI API Key
     - Google Cloud API Key

2. **Create Your First Session**:
   - Click "New Session"
   - Enter session name (e.g., "Product Ideas Brainstorm")
   - Add participant names
   - Select AI model (Claude/GPT-4/Gemini)
   - Set AI contribution frequency (1-20, where 20 is most active)
   - Choose AI voice (Male/Female)
   - Click "Start Session"

3. **During the Session**:
   - The app will listen to conversations
   - Speak naturally with other participants
   - When AI has an idea:
     - You'll see a blue pulsing light
     - A sound notification will play
     - AI will speak its contribution
   - All contributions are automatically transcribed and saved

4. **End Session**:
   - Click "End Session"
   - View the comprehensive report
   - Export as PDF if needed

## Testing the Backend API

### Health Check
```bash
curl http://localhost:8080/actuator/health
```

### Create a Session
```bash
curl -X POST http://localhost:8080/api/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "sessionName": "Test Session",
    "participants": ["Alice", "Bob", "Charlie"],
    "aiModel": "claude",
    "aiContributionFrequency": 10,
    "aiVoiceGender": "female",
    "userId": "test-user-123"
  }'
```

### Save API Keys
```bash
curl -X POST http://localhost:8080/api/keys \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-123",
    "claudeApiKey": "your-claude-key",
    "openaiApiKey": "your-openai-key",
    "geminiApiKey": "your-gemini-key",
    "googleCloudApiKey": "your-google-cloud-key"
  }'
```

## Troubleshooting

### Backend won't start
- Check Java version: `java -version` (should be 17+)
- Check Maven version: `mvn -version`
- Check port 8080 is available: `lsof -i :8080`

### Flutter app build fails
- Run `flutter doctor` to check setup
- Ensure Flutter is up to date: `flutter upgrade`
- Clear cache: `flutter clean && flutter pub get`

### Audio not recording
- Check microphone permissions
- On Android: Settings > Apps > AIBro > Permissions
- On iOS: Settings > AIBro > Microphone

### AI not responding
- Verify API keys are correctly entered
- Check backend logs for API errors
- Ensure you have internet connectivity
- Verify API keys have sufficient credits/quota

### WebSocket connection issues
- Check backend is running
- Verify WebSocket URL in Flutter app matches backend
- Check firewall settings

## Development Tips

### Hot Reload (Flutter)
Press `r` in terminal while app is running to hot reload changes

### Backend Live Reload
Use Spring Boot DevTools for automatic restart on changes

### View H2 Database
Open in browser: `http://localhost:8080/h2-console`
- JDBC URL: `jdbc:h2:mem:aibrodb`
- Username: `sa`
- Password: (leave empty)

### API Documentation
Swagger UI available at: `http://localhost:8080/swagger-ui.html`

## Next Steps

- [ ] Customize AI prompts in `AIService.java`
- [ ] Add more AI models
- [ ] Implement user authentication
- [ ] Add session sharing features
- [ ] Create custom AI voice options
- [ ] Add analytics dashboard
- [ ] Implement offline mode
- [ ] Add export to multiple formats (PDF, Word, Markdown)

## Support

For issues and questions:
- Check the full README.md
- Review DEPLOYMENT_GUIDE.md for production setup
- Check FLUTTER_IMPLEMENTATION_GUIDE.md for frontend details

## Useful Commands Reference

```bash
# Backend
mvn clean install          # Build
mvn spring-boot:run        # Run
mvn test                   # Run tests
mvn package -DskipTests    # Build JAR without tests

# Flutter
flutter doctor             # Check environment
flutter pub get            # Get dependencies
flutter run                # Run app
flutter build apk          # Build Android APK
flutter build ios          # Build iOS app
flutter build windows      # Build Windows app
flutter test               # Run tests
```

