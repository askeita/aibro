import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';
import '../models/session_report.dart';


/// Thin HTTP client for talking to the AiBro backend REST API.
class ApiService {
  final Dio _dio;

  /// Creates an [ApiService] with default base options.
  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8080/api',
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  /// Creates a new brainstorming session with the provided configuration.
  Future<BrainstormingSession> createSession({
    required String sessionName,
    required List<String> participants,
    required String objective,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'local-user';
    final aiModel = prefs.getString('aiModel') ?? 'claude';
    final contributionMode = prefs.getString('aiContributionMode') ?? 'ai-decide';

    int frequency;
    switch (contributionMode) {
      case 'ai-always':
        frequency = 20; // always respond
        break;
      case 'ai-most':
        frequency = 15; // often
        break;
      case 'human-decide':
        frequency = 0; // no automatic contributions
        break;
      case 'ai-decide':
      default:
        frequency = 10; // balanced
        break;
    }

    final data = {
      'sessionName': sessionName,
      'participants': participants,
      'aiModel': aiModel,
      'aiContributionFrequency': frequency,
      'aiVoiceGender': 'female',
      'userId': userId,
      'objective': objective,
    };

    final response = await _dio.post('/sessions', data: data);
    return BrainstormingSession.fromJson(response.data as Map<String, dynamic>);
  }

  /// Backwards-compatible helper to create a quick default session.
  Future<BrainstormingSession> createQuickSession() {
    return createSession(
      sessionName: 'New Session',
      participants: const ['You'],
      objective: 'General brainstorming',
    );
  }

  /// Mark a session as ended on the backend.
  Future<BrainstormingSession> endSession(int sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'local-user';

    final response = await _dio.post(
      '/sessions/$sessionId/end',
      queryParameters: {'userId': userId},
    );
    return BrainstormingSession.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Fetch metadata for a single brainstorming session.
  Future<BrainstormingSession> getSession(int sessionId) async {
    final response = await _dio.get('/sessions/$sessionId');
    return BrainstormingSession.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Fetch a full report (including contributions) for a session.
  Future<SessionReport> getSessionReport(int sessionId) async {
    final response = await _dio.get('/sessions/$sessionId/report');
    return SessionReport.fromJson(response.data as Map<String, dynamic>);
  }

  /// Send recorded audio to the backend for transcription.
  Future<void> transcribeAudio(
    int sessionId,
    String userId,
    List<int> audioBytes, {
    bool forceAi = false,
  }
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('speechLanguageCode') ?? 'en-US';

    final formData = FormData.fromMap({
      'sessionId': sessionId,
      'userId': userId,
      'languageCode': languageCode,
      'forceAi': forceAi,
      'audio': MultipartFile.fromBytes(
        audioBytes,
        filename: 'audio.wav',
      ),
    });

    await _dio.post('/audio/transcribe', data: formData);
  }

  /// Send a short multi-speaker recording used only to
  /// calibrate the mapping between diarization speaker tags
  /// and participant first names for a given session.
  Future<void> calibrateSpeakers(
    int sessionId,
    String userId,
    List<int> audioBytes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('speechLanguageCode') ?? 'en-US';

    final formData = FormData.fromMap({
      'sessionId': sessionId,
      'userId': userId,
      'languageCode': languageCode,
      'audio': MultipartFile.fromBytes(
        audioBytes,
        filename: 'calibration.wav',
      ),
    });

    await _dio.post('/audio/calibrate', data: formData);
  }

  /// Save API keys for the current user so that
  /// speech recognition (Google) and AI models can run.
  Future<void> saveApiKeys({
    required String userId,
    String? claudeApiKey,
    String? openaiApiKey,
    String? geminiApiKey,
    String? googleCloudApiKey,
  }) async {
    final payload = <String, dynamic>{
      'userId': userId,
      'claudeApiKey': claudeApiKey,
      'openaiApiKey': openaiApiKey,
      'geminiApiKey': geminiApiKey,
      'googleCloudApiKey': googleCloudApiKey,
    };

    await _dio.post('/keys', data: payload);
  }
}
