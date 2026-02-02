import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../models/session_report.dart';
import '../services/api_service.dart';


/// Screen showing a single report in detail, with a fallback to reading
/// local report files when the backend data is unavailable.
class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

/// State for [ReportDetailScreen] handling backend and local file loading.
class _ReportDetailScreenState extends State<ReportDetailScreen> {
  BrainstormingSession? _session;
  SessionReport? _report;
  bool _isLoading = true;
  String? _error;

  // Optional path to the locally stored RTF report file, when launched
  // from the Reports list.
  String? _localReportPath;

  // When we cannot load structured data from the backend (for example
  // because the session no longer exists) but a local RTF file is
  // available, we fall back to rendering plain text extracted from that
  // file.
  String? _fallbackReportText;

  late final ApiService _api;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _api = context.read<ApiService>();
      _initialized = true;

      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final sessionId = args['sessionId'];
        final filePath = args['filePath'];
        if (filePath is String) {
          _localReportPath = filePath;
        }
        if (sessionId is int) {
          _loadData(sessionId);
        } else {
          setState(() {
            _isLoading = false;
            _error = 'No session id provided to Report detail screen.';
          });
        }
      } else if (args is int) {
        _loadData(args);
      } else if (args is BrainstormingSession) {
        _loadData(args.id);
      } else {
        setState(() {
          _isLoading = false;
          _error = 'No session id provided to Report detail screen.';
        });
      }
    }
  }

  /// Loads session and report data for [sessionId], using a local RTF
  /// file as a fallback when the backend returns 404.
  Future<void> _loadData(int sessionId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _api.getSession(sessionId);
      final report = await _api.getSessionReport(sessionId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _report = report;
        _isLoading = false;
      });
    } on DioException catch (e) {
      // If the session no longer exists on the backend but we have a
      // local RTF report file, fall back to showing the contents of
      // that file as plain text so the user still sees the report.
      if (e.response?.statusCode == 404 && _localReportPath != null) {
        final fallback = await _loadReportFromFile(_localReportPath!);
        if (!mounted) return;

        if (fallback != null) {
          setState(() {
            _fallbackReportText = fallback;
            _isLoading = false;
            _error = null;
          });
          return;
        }

        setState(() {
          _error =
              'This session no longer exists on the server; the associated report file could not be read.';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = 'Failed to load report details: $e';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load report details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 100,
        automaticallyImplyLeading: false,
        leading: TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: AppColors.lightGrayBackground,
            foregroundColor: AppColors.darkGray,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          icon: const Icon(Icons.arrow_back),
          label: const Text('Home'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _fallbackReportText != null
                        ? _buildFallbackBody(_fallbackReportText!)
                        : _buildDetailBody(_session!, _report!),
          ),
        ),
      ),
    );
  }

  /// Builds a simple body showing plain text extracted from an RTF file.
  Widget _buildFallbackBody(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Brainstorming Session Report',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Showing contents from the saved report file.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SelectableText(text),
          ],
        ),
      ),
    );
  }

  /// Builds the rich report detail body backed by structured data.
  Widget _buildDetailBody(
    BrainstormingSession session,
    SessionReport report,
  ) {
    final objective = (session.objective ?? '').trim();
    final participants = session.participants;
    final aiModel = session.aiModel;
    final durationMinutes = report.statistics.durationMinutes;

    // Build ideas by participant (human only).
    final Map<String, List<String>> ideasBySpeaker = {};
    for (final c in report.contributions) {
      if (c.type.toUpperCase() == 'AI') continue;
      ideasBySpeaker.putIfAbsent(c.speaker, () => []);
      ideasBySpeaker[c.speaker]!.add(c.content);
    }

    final theme = Theme.of(context);

    return Padding
    (
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Brainstorming Session Report',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              session.sessionName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text('Session metadata', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Participants: '
                '${participants.isEmpty ? 'N/A' : participants.join(', ')}'),
            if (objective.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Objective: $objective'),
            ],
            const SizedBox(height: 4),
            Text('Selected AI model: $aiModel'),
            if (durationMinutes > 0) ...[
              const SizedBox(height: 4),
              Text('Duration: $durationMinutes minute(s)'),
            ],
            const SizedBox(height: 24),
            Text('Ideas by participant (overview)',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (ideasBySpeaker.isEmpty)
              const Text('No human contributions were recorded.')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ideasBySpeaker.entries.map((entry) {
                  final speaker = entry.key;
                  final ideas = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          speaker,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        ...ideas.map(
                          (idea) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• '),
                                Expanded(child: Text(idea)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            Text('Contributions timeline',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...report.contributions.map((c) {
              final ts = c.timestamp.toLocal().toIso8601String();
              final speakerLabel =
                  c.type.toUpperCase() == 'AI' ? '[AI] ${c.speaker}' : c.speaker;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('[$ts] $speakerLabel: ${c.content}'),
              );
            }),
            const SizedBox(height: 24),
            Text('Refined summary (AI-assisted)',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_buildSummary(session, report)),
          ],
        ),
      ),
    );
  }

  /// Builds a textual summary for the session, falling back to a heuristic
  /// summary when no AI-generated summary is available.
  String _buildSummary(BrainstormingSession session, SessionReport report) {
    final summaryText = (report.summary ?? '').trim();
    if (summaryText.isNotEmpty) {
      return summaryText;
    }

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

  /// Loads the contents of an RTF report at [path] and converts it to text.
  Future<String?> _loadReportFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    try {
      final raw = await file.readAsString();
      return _rtfToPlainText(raw);
    } catch (_) {
      return null;
    }
  }

  /// Performs a very lightweight conversion from RTF markup to plain text.
  String _rtfToPlainText(String input) {
    var text = input;
    // Replace common RTF control words with simple whitespace.
    text = text.replaceAll(RegExp(r'\\par[d]?'), '\n');
    text = text.replaceAll(RegExp(r'\\tab'), '\t');

    // Remove remaining RTF control words like \b, \b0, \ul, \ul0, etc.
    text = text.replaceAll(RegExp(r'\\[a-zA-Z]+-?\d* ?'), '');

    // Remove RTF grouping braces.
    text = text.replaceAll('{', '');
    text = text.replaceAll('}', '');

    return text.trim();
  }
}
