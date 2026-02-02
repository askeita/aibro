import 'package:flutter_tts/flutter_tts.dart';


/// Simple wrapper around FlutterTts to speak short UI prompts.
class PromptVoiceService {
  final FlutterTts _tts = FlutterTts();

  /// Speaks the given [text] using the platform text-to-speech engine.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // If TTS fails for any reason, we silently ignore it so the
      // textual prompts still work.
    }
  }

  /// Stops any current speech and releases TTS resources when possible.
  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore errors during dispose.
    }
  }
}
