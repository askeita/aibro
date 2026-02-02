import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';


/// Metadata for a stored session-level audio recording.
class SessionRecording {
  final String id;
  final int sessionId;
  final String? objective;
  final DateTime recordedAt;
  final String filePath;

  /// Creates a new [SessionRecording] instance.
  SessionRecording({
    required this.id,
    required this.sessionId,
    required this.objective,
    required this.recordedAt,
    required this.filePath,
  });

  /// Builds a [SessionRecording] from a JSON map.
  factory SessionRecording.fromJson(Map<String, dynamic> json) {
    return SessionRecording(
      id: json['id'] as String,
      sessionId: json['sessionId'] as int,
      objective: json['objective'] as String?,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      filePath: json['filePath'] as String,
    );
  }

  /// Serialises this recording to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'objective': objective,
      'recordedAt': recordedAt.toIso8601String(),
      'filePath': filePath,
    };
  }
}

/// Handles storage and metadata for full-session audio recordings
/// saved on the local device.
class SessionRecordingService {
  // Store session recordings under a common AiBro folder so that
  // audio files live alongside generated reports:
  //   <documents>/aibro/audios
  static const String _recordingsFolderName = 'aibro/audios';
  static const String _metadataFileName = 'session_recordings.json';

  /// Returns the root directory that contains the session recordings.
  Future<Directory> _getRootDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docsDir.path, _recordingsFolderName));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<File> _getMetadataFile() async {
    final root = await _getRootDirectory();
    return File(p.join(root.path, _metadataFileName));
  }

  /// Returns an absolute file path where a new recording for [sessionId]
  /// should be stored.
  Future<String> createRecordingFilePath(int sessionId) async {
    final root = await _getRootDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'session_${sessionId}_$timestamp.wav';
    return p.join(root.path, fileName);
  }

  /// Lists all known session recordings whose files still exist on disk,
  /// sorted by most recent first.
  Future<List<SessionRecording>> listRecordings() async {
    final metadataFile = await _getMetadataFile();
    if (!await metadataFile.exists()) {
      return [];
    }

    try {
      final contents = await metadataFile.readAsString();
      if (contents.trim().isEmpty) {
        return [];
      }
      final List<dynamic> data = jsonDecode(contents) as List<dynamic>;
      final recordings = data
          .map((e) => SessionRecording.fromJson(e as Map<String, dynamic>))
          .toList();

      // Filter out entries whose files no longer exist.
      final existing = <SessionRecording>[];
      for (final rec in recordings) {
        if (await File(rec.filePath).exists()) {
          existing.add(rec);
        }
      }

      if (existing.length != recordings.length) {
        await _writeRecordings(existing);
      }

      // Newest first.
      existing.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return existing;
    } catch (_) {
      // On any parsing error, reset metadata.
      await _writeRecordings([]);
      return [];
    }
  }

  /// Adds a new [recording] entry to the local metadata file.
  Future<void> addRecording(SessionRecording recording) async {
    final current = await listRecordings();
    current.add(recording);
    await _writeRecordings(current);
  }

  /// Deletes the audio file for [recording] (if it exists) and removes it
  /// from the local metadata.
  Future<void> deleteRecording(SessionRecording recording) async {
    final file = File(recording.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    final current = await listRecordings();
    current.removeWhere((r) => r.id == recording.id);
    await _writeRecordings(current);
  }

  /// Writes the given list of [recordings] to the local metadata file.
  Future<void> _writeRecordings(List<SessionRecording> recordings) async {
    final metadataFile = await _getMetadataFile();
    final data = recordings.map((r) => r.toJson()).toList();
    await metadataFile.writeAsString(jsonEncode(data));
  }
}
