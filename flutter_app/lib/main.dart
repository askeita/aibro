import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/session_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/report_screen.dart';
import 'screens/previous_sessions_screen.dart';
import 'screens/report_detail_screen.dart';
import 'services/api_service.dart';
import 'services/audio_service.dart';
import 'services/websocket_service.dart';
import 'services/prompt_voice_service.dart';


/// Synchronises locally stored API keys with the backend when the app starts.
Future<void> _syncApiKeysToBackendOnStartup() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString('userId')?.trim();
    final googleKey = prefs.getString('googleCloudApiKey')?.trim();
    // We keep a single locally stored AI key value for convenience,
    // regardless of which model is selected.
    final aiKey = prefs.getString('claudeApiKey')?.trim();
    final aiModel = prefs.getString('aiModel') ?? 'claude';

    if (userId == null || userId.isEmpty) {
      return;
    }

    if ((googleKey == null || googleKey.isEmpty) && (aiKey == null || aiKey.isEmpty)) {
      return;
    }

    String? claudeKey;
    String? openaiKey;
    String? geminiKey;

    if (aiKey != null && aiKey.isNotEmpty) {
      switch (aiModel) {
        case 'openai':
          openaiKey = aiKey;
          break;
        case 'gemini':
          geminiKey = aiKey;
          break;
        case 'claude':
        default:
          claudeKey = aiKey;
          break;
      }
    }

    final api = ApiService();
    await api.saveApiKeys(
      userId: userId,
      claudeApiKey: claudeKey,
      openaiApiKey: openaiKey,
      geminiApiKey: geminiKey,
      googleCloudApiKey: (googleKey == null || googleKey.isEmpty) ? null : googleKey,
    );
  } catch (_) {
    // On startup we don't want key sync failures to crash the app.
  }
}

/// Application entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _syncApiKeysToBackendOnStartup();
  runApp(const MyApp());
}

/// Root widget that wires up services and application routes.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Builds the top-level [MaterialApp] with routing and theming.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiService()),
        Provider(create: (_) => AudioService()),
        Provider(create: (_) => WebSocketService()),
        Provider(create: (_) => PromptVoiceService()),
      ],
      child: MaterialApp(
        title: 'AiBro - AI Brainstorming Assistant',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/session': (context) => const SessionScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/report': (context) => const ReportScreen(),
          '/reportDetail': (context) => const ReportDetailScreen(),
          '/recordings': (context) => const PreviousSessionsScreen(),
        },
      ),
    );
  }
}
