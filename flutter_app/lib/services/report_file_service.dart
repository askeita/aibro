import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/session.dart';
import '../models/session_report.dart';


/// Generates Word-compatible (RTF) reports for brainstorming sessions
/// and stores them on the local filesystem under:
///   <documents>/aibro/reports
class ReportFileService {
  static const String _reportsFolderPath = 'aibro/reports';

  /// Ensures the reports directory exists and returns it.
  Future<Directory> _getReportsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(p.join(docsDir.path, _reportsFolderPath));
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }

  /// Lists all report files that have been generated locally for any session.
  ///
  /// Files are returned most-recent-first based on last modified time.
  Future<List<StoredReport>> listStoredReports() async {
    final dir = await _getReportsDirectory();
    if (!await dir.exists()) {
      return [];
    }

    final entries = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.rtf'))
        .cast<File>()
        .toList();

    final stored = <StoredReport>[];
    for (final file in entries) {
      final fileName = p.basename(file.path);
      int? sessionId;

      // Expect filenames like: session_<id>_timestamp.rtf
      if (fileName.toLowerCase().startsWith('session_')) {
        final withoutPrefix = fileName.substring('session_'.length);
        final underscoreIndex = withoutPrefix.indexOf('_');
        if (underscoreIndex > 0) {
          final idStr = withoutPrefix.substring(0, underscoreIndex);
          sessionId = int.tryParse(idStr);
        }
      }

      final stat = await file.stat();
      stored.add(
        StoredReport(
          sessionId: sessionId,
          createdAt: stat.modified,
          filePath: file.path,
        ),
      );
    }

    stored.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return stored;
  }

  /// Generate an RTF report file for the given [session] and [report].
  ///
  /// The report includes:
  /// - Participant first names
  /// - Objective
  /// - Selected AI model
  /// - Duration (when available)
  /// - Contributions grouped by participant ("graphical" overview)
  /// - A refined textual summary (AI summary when available)
  Future<File> generateReport({
    required BrainstormingSession session,
    required SessionReport report,
  }) async {
    final dir = await _getReportsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final fileName = 'session_${session.id}_$timestamp.rtf';
    final file = File(p.join(dir.path, fileName));

    final rtfContent = _buildRtfContent(session, report);
    await file.writeAsString(rtfContent);
    return file;
  }

  /// Builds the RTF payload that will be written to disk.
  String _buildRtfContent(
    BrainstormingSession session,
    SessionReport report,
  ) {
    final buffer = StringBuffer();

    // Basic RTF header.
    buffer.writeln('{\\rtf1\\ansi');

    // Title
    buffer.writeln('\\b Brainstorming Session Report\\b0\\par');
    buffer.writeln('\\par');

    // Session metadata
    final participants = session.participants;
    final objective = (session.objective ?? '').trim();
    final aiModel = (session.aiModel).toString();
    final durationMinutes = report.statistics.durationMinutes;

    buffer.writeln('\\b Session metadata\\b0\\par');
    buffer.writeln('Participants: ${_escapeRtf(participants.isEmpty ? 'N/A' : participants.join(', '))}\\par');
    if (objective.isNotEmpty) {
      buffer.writeln(
          'Objective: ${_escapeRtf(objective)}\\par');
    }
    buffer.writeln('Selected AI model: ${_escapeRtf(aiModel)}\\par');
    if (durationMinutes > 0) {
      buffer.writeln('Duration: ${_escapeRtf('$durationMinutes minute(s)')}\\par');
    }
    buffer.writeln('\\par');

    // Graphical overview: ideas grouped by participant.
    buffer.writeln('\\b Ideas by participant (overview)\\b0\\par');
    buffer.writeln('\\par');
    buffer.writeln('Speaker\\tab Key ideas\\par');
    buffer.writeln('\\ul ${_escapeRtf('---------------------------------------------')}\\ul0\\par');

    final Map<String, List<String>> ideasBySpeaker = {};
    for (final c in report.contributions) {
      // Skip AI contributions here; we'll include them in the transcript
      // /summary section instead.
      if (c.type.toUpperCase() == 'AI') continue;
      ideasBySpeaker.putIfAbsent(c.speaker, () => []);
      ideasBySpeaker[c.speaker]!.add(c.content);
    }

    if (ideasBySpeaker.isEmpty) {
      buffer.writeln('No human contributions were recorded.\\par');
    } else {
      ideasBySpeaker.forEach((speaker, ideas) {
        buffer.writeln('\\par');
        // Speaker name as a bold header on the left column.
        buffer.writeln('\\b ${_escapeRtf(speaker)}\\b0\\tab');
        buffer.writeln('\\par');

        // Ideas listed as indented bullets to visually cluster them
        // under the speaker.
        for (final idea in ideas) {
          buffer.writeln('\\tab \\bullet ${_escapeRtf(idea)}\\par');
        }

        // Horizontal separator between speakers for a more "graphical"
        // classification.
        buffer.writeln('\\ul ${_escapeRtf('---------------------------------------------')}\\ul0\\par');
      });
    }

    buffer.writeln('\\par');

    // Full contributions recap (including AI).
    buffer.writeln('\\b Contributions timeline\\b0\\par');
    for (final c in report.contributions) {
      final ts = c.timestamp.toIso8601String();
      final speakerLabel =
          c.type.toUpperCase() == 'AI' ? '[AI] ${c.speaker}' : c.speaker;
      buffer.writeln('${_escapeRtf('[$ts] $speakerLabel: ${c.content}')}\\par');
    }

    buffer.writeln('\\par');

    // Refined textual summary – use AI summary when available, otherwise
    // fall back to a basic heuristic summary.
    final summaryText = (report.summary ?? '').trim().isNotEmpty
        ? report.summary!.trim()
        : _buildFallbackSummary(session, report);

    buffer.writeln('\\b Refined summary (AI-assisted)\\b0\\par');
    buffer.writeln('${_escapeRtf(summaryText)}\\par');

    // Close RTF document.
    buffer.writeln('}');

    return buffer.toString();
  }

  String _buildFallbackSummary(
    BrainstormingSession session,
    SessionReport report,
  ) {
    final objective = (session.objective ?? '').trim();
    final total = report.statistics.totalContributions;
    final human = report.statistics.humanContributions;
    final ai = report.statistics.aiContributions;

    final parts = <String>[];
    if (objective.isNotEmpty) {
      parts.add('The session aimed to: "$objective".');
    }
    parts.add(
        'A total of $total contributions were recorded ($human from participants and $ai from the AI assistant).');
    if (report.fullTranscript != null &&
        report.fullTranscript!.trim().isNotEmpty) {
      parts.add(
          'The discussion covered the following points in more detail: ${report.fullTranscript!.trim()}');
    }

    return parts.join(' ');
  }

  String _escapeRtf(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('{', '\\{')
        .replaceAll('}', '\\}')
        .replaceAll('\n', '\\par ');
  }
}

/// Lightweight metadata for a generated report stored on disk.
class StoredReport {
  final int? sessionId;
  final DateTime createdAt;
  final String filePath;

  StoredReport({
    required this.sessionId,
    required this.createdAt,
    required this.filePath,
  });

  String get fileName => p.basename(filePath);
}

