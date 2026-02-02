import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';


/// Handles microphone recording and provides raw audio bytes for upload.
///
/// This service supports two independent recording flows:
/// - Chunk recordings for live transcription upload.
/// - Long-running session recordings saved to disk.
class AudioService {
  final AudioRecorder _chunkRecorder = AudioRecorder();
  final AudioRecorder _sessionRecorder = AudioRecorder();

  bool _isChunkRecording = false;
  bool _isSessionRecording = false;

  bool get isRecording => _isChunkRecording;
  bool get isSessionRecording => _isSessionRecording;

  /// On desktop we rely on OS-level permissions; nothing to request here.
  Future<bool> requestPermission() async {
    return true;
  }

  /// Starts a short-lived recording used for audio chunks sent to the backend.
  /// If [filePath] is provided, audio will be written to that location;
  /// otherwise a temporary file is used.
  Future<void> startRecording({String? filePath}) async {
    if (_isChunkRecording) return;
    if (!await _chunkRecorder.hasPermission()) {
      throw Exception('Microphone permission not granted');
    }

    String path;
    if (filePath != null) {
      path = filePath;
    } else {
      final dir = await getTemporaryDirectory();
      // Use a timestamp to avoid collisions between multiple recordings.
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      path = '${dir.path}/aibro_recording_$timestamp.wav';
    }

    await _chunkRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    _isChunkRecording = true;
  }

  /// Stops the chunk recording and returns the recorded bytes, or null
  /// if nothing was recorded.
  Future<List<int>?> stopRecording() async {
    if (!_isChunkRecording) return null;

    final path = await _chunkRecorder.stop();
    _isChunkRecording = false;

    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Starts a long-running session recording that is saved directly to disk
  /// at [filePath]. This runs independently from chunk recordings.
  Future<void> startSessionRecording(String filePath) async {
    if (_isSessionRecording) return;
    if (!await _sessionRecorder.hasPermission()) {
      throw Exception('Microphone permission not granted');
    }

    await _sessionRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );

    _isSessionRecording = true;
  }

  /// Stops the long-running session recording, if any. The audio file
  /// remains on disk at the path provided to [startSessionRecording].
  Future<void> stopSessionRecording() async {
    if (!_isSessionRecording) return;
    await _sessionRecorder.stop();
    _isSessionRecording = false;
  }

  /// Releases underlying audio recorder resources.
  Future<void> dispose() async {
    await _chunkRecorder.dispose();
    await _sessionRecorder.dispose();
  }
}

