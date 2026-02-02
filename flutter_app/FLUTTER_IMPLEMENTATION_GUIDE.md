# Flutter Implementation Guide

This guide provides the structure and key implementation files for the AIBro Flutter application.

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── models/                   # Data models
│   ├── session.dart
│   ├── contribution.dart
│   ├── participant.dart
│   └── api_keys.dart
├── services/                 # Business logic & API
│   ├── api_service.dart     # REST API communication
│   ├── audio_service.dart   # Audio recording/playback
│   ├── websocket_service.dart  # Real-time updates
│   └── storage_service.dart    # Local storage
├── screens/                  # UI Screens
│   ├── home_screen.dart     # Main dashboard
│   ├── session_screen.dart  # Active session
│   ├── settings_screen.dart # API keys configuration
│   └── report_screen.dart   # Session reports
├── widgets/                  # Reusable widgets
│   ├── ai_indicator.dart    # Blue light indicator
│   ├── participant_tile.dart
│   ├── contribution_card.dart
│   └── audio_visualizer.dart
└── utils/                    # Utilities
    ├── constants.dart
    └── permissions.dart
```

## Key Implementation Files

### 1. Models (lib/models/session.dart)

```dart
import 'package:json_annotation/json_annotation.dart';

part 'session.g.dart';

@JsonSerializable()
class BrainstormingSession {
  final int? id;
  final String sessionName;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final List<String> participants;
  final String aiModel;
  final int aiContributionFrequency;
  final String aiVoiceGender;
  final String? summary;

  BrainstormingSession({
    this.id,
    required this.sessionName,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.participants,
    required this.aiModel,
    required this.aiContributionFrequency,
    required this.aiVoiceGender,
    this.summary,
  });

  factory BrainstormingSession.fromJson(Map<String, dynamic> json) =>
      _$BrainstormingSessionFromJson(json);

  Map<String, dynamic> toJson() => _$BrainstormingSessionToJson(this);
}
```

### 2. API Service (lib/services/api_service.dart)

```dart
import 'package:dio/dio.dart';
import '../models/session.dart';

class ApiService {
  final Dio _dio;
  final String baseUrl = 'http://localhost:8080/api'; // Change for production

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8080/api',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // Sessions
  Future<BrainstormingSession> createSession(Map<String, dynamic> data) async {
    final response = await _dio.post('/sessions', data: data);
    return BrainstormingSession.fromJson(response.data);
  }

  Future<List<BrainstormingSession>> getSessions() async {
    final response = await _dio.get('/sessions');
    return (response.data as List)
        .map((e) => BrainstormingSession.fromJson(e))
        .toList();
  }

  Future<BrainstormingSession> endSession(int sessionId, String userId) async {
    final response = await _dio.post(
      '/sessions/$sessionId/end',
      queryParameters: {'userId': userId},
    );
    return BrainstormingSession.fromJson(response.data);
  }

  // API Keys
  Future<void> saveApiKeys(Map<String, String> keys) async {
    await _dio.post('/keys', data: keys);
  }

  // Audio
  Future<void> transcribeAudio(int sessionId, String userId, List<int> audioData) async {
    final formData = FormData.fromMap({
      'sessionId': sessionId,
      'userId': userId,
      'audio': MultipartFile.fromBytes(audioData, filename: 'audio.wav'),
    });
    await _dio.post('/audio/transcribe', data: formData);
  }
}
```

### 3. WebSocket Service (lib/services/websocket_service.dart)

```dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(int sessionId) {
    final uri = Uri.parse('ws://localhost:8080/ws');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        _messageController.add(data);
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
      },
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _messageController.close();
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }
}
```

### 4. Audio Service (lib/services/audio_service.dart)

```dart
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;

  Future<bool> requestPermissions() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startRecording(String path) async {
    if (await _recorder.hasPermission()) {
      await _recorder.start(const RecordConfig(), path: path);
      _isRecording = true;
    }
  }

  Future<String?> stopRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      _isRecording = false;
      return path;
    }
    return null;
  }

  Future<void> playAudio(String url) async {
    await _player.play(UrlSource(url));
  }

  Future<void> stopAudio() async {
    await _player.stop();
  }

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
```

### 5. Session Screen (lib/screens/session_screen.dart)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/websocket_service.dart';
import '../widgets/ai_indicator.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  bool _isRecording = false;
  bool _aiIsActive = false;
  List<Map<String, dynamic>> _contributions = [];

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  void _initializeSession() {
    final wsService = context.read<WebSocketService>();
    // Get sessionId from arguments
    final sessionId = 1; // Replace with actual session ID
    
    wsService.connect(sessionId);
    wsService.messages.listen((message) {
      if (message['type'] == 'SIGNAL') {
        setState(() => _aiIsActive = true);
      } else if (message['type'] == 'CONTRIBUTION') {
        setState(() {
          _contributions.add(message);
          _aiIsActive = false;
        });
      }
    });
  }

  Future<void> _toggleRecording() async {
    final audioService = context.read<AudioService>();
    
    if (_isRecording) {
      final path = await audioService.stopRecording();
      if (path != null) {
        // Send audio for transcription
        // Implementation here
      }
    } else {
      await audioService.startRecording('/path/to/audio.wav');
    }
    
    setState(() => _isRecording = !_isRecording);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brainstorming Session'),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: _endSession,
          ),
        ],
      ),
      body: Column(
        children: [
          // AI Indicator
          if (_aiIsActive) const AIIndicator(),
          
          // Contributions List
          Expanded(
            child: ListView.builder(
              itemCount: _contributions.length,
              itemBuilder: (context, index) {
                final contribution = _contributions[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(contribution['speaker'][0]),
                  ),
                  title: Text(contribution['speaker']),
                  subtitle: Text(contribution['content']),
                );
              },
            ),
          ),
          
          // Recording Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton(
              onPressed: _toggleRecording,
              backgroundColor: _isRecording ? Colors.red : Colors.blue,
              child: Icon(_isRecording ? Icons.stop : Icons.mic),
            ),
          ),
        ],
      ),
    );
  }

  void _endSession() {
    // End session logic
    Navigator.pop(context);
  }

  @override
  void dispose() {
    context.read<WebSocketService>().disconnect();
    super.dispose();
  }
}
```

### 6. AI Indicator Widget (lib/widgets/ai_indicator.dart)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AIIndicator extends StatelessWidget {
  const AIIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .fadeIn(duration: 500.ms)
              .fadeOut(duration: 500.ms),
          const SizedBox(width: 12),
          const Text(
            'AI is thinking...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
```

## Running the Application

1. Ensure backend is running on `http://localhost:8080`

2. Generate JSON serialization code:
```bash
flutter pub run build_runner build
```

3. Run the app:
```bash
flutter run
```

## Platform-Specific Configurations

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS (ios/Runner/Info.plist)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone for recording brainstorming sessions.</string>
```

### Windows/macOS/Linux
No additional permissions required, but ensure microphone access is granted through system settings.

## Next Steps

1. Implement complete CRUD operations for sessions
2. Add offline support with local database
3. Implement PDF report generation
4. Add user authentication (optional)
5. Implement session sharing features
6. Add analytics and insights
7. Create app store assets and prepare for deployment

