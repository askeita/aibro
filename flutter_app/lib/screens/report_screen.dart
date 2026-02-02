import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_colors.dart';

import '../models/session.dart';
import '../models/session_report.dart';
import '../services/api_service.dart';
import '../services/report_file_service.dart';
import '../services/session_recording_service.dart';


/// Screen for viewing a live session report or browsing stored reports.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

/// State backing [ReportScreen], handling loading and file operations.
class _ReportScreenState extends State<ReportScreen> {
  BrainstormingSession? _session;
  SessionReport? _report;
  bool _isLoading = true;
  String? _error;
  bool _isGenerating = false;
  bool _hasRecordingForSession = false;
  bool _hasCheckedRecording = false;

  // When no specific session is provided (e.g. from the Home "View Reports"
  // button), this holds a list of all locally generated reports across
  // previous sessions.
  List<StoredReport> _storedReports = [];

  late final ApiService _api;
  late final ReportFileService _reportFileService;
  bool _servicesInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_servicesInitialized) {
      _api = context.read<ApiService>();
      _reportFileService = ReportFileService();
      _servicesInitialized = true;
    }

    if (_session == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is BrainstormingSession) {
        _session = args;
        _loadReport();
        _checkIfSessionRecorded();
      } else if (args is int) {
        // Fallback: only an id was passed.
        _session = BrainstormingSession(
          id: args,
          sessionName: 'Session $args',
          startTime: null,
          endTime: null,
          status: 'UNKNOWN',
          participants: const [],
          aiModel: 'claude',
          aiContributionFrequency: 0,
          aiVoiceGender: 'female',
          summary: null,
          objective: null,
        );
        _loadReport();
        _checkIfSessionRecorded();
      } else {
        // No specific session provided: show list of previously
        // generated reports on this device.
        _loadStoredReports();
      }
    }
  }

  /// Checks whether the current session has an associated local recording.
  Future<void> _checkIfSessionRecorded() async {
    final session = _session;
    if (session == null) return;

    final recordingService = SessionRecordingService();
    final recordings = await recordingService.listRecordings();
    final hasRecording =
        recordings.any((r) => r.sessionId == session.id);

    if (!mounted) return;
    setState(() {
      _hasRecordingForSession = hasRecording;
      _hasCheckedRecording = true;
    });
  }

  /// Loads the detailed report for the current [_session] from the backend.
  Future<void> _loadReport() async {
    final session = _session;
    if (session == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final report = await _api.getSessionReport(session.id);
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Generates a local Word-compatible report file for the current session.
  Future<void> _generateWordReport() async {
    final session = _session;
    final report = _report;
    if (session == null || report == null) return;

    // Enforce: a session must be recorded to have a local report file.
    final recordingService = SessionRecordingService();
    final recordings = await recordingService.listRecordings();
    final hasRecording =
        recordings.any((r) => r.sessionId == session.id);
    if (!hasRecording) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This session has not been recorded. Record the session to generate a report on this device.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final file = await _reportFileService.generateReport(
        session: session,
        report: report,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report generated at: ${file.path}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => _openFile(file),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  /// Asks the OS to open the given report [file].
  Future<void> _openFile(File file) async {
    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    // If a specific session is loaded, show its detailed report. Otherwise,
    // show the list of all previously generated reports.
    final session = _session;
    final isListMode = session == null;

    if (isListMode) {
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
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reports',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            Expanded(child: _buildReportsList()),
                          ],
                        ),
            ),
          ),
        ),
      );
    }

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
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Exports the current report for a session that has not been recorded
  /// by generating an RTF document and opening the platform share sheet.
  Future<void> _exportReport() async {
    final session = _session;
    final report = _report;
    if (session == null || report == null) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final file = await _reportFileService.generateReport(
        session: session,
        report: report,
      );
      if (!mounted) return;

      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        subject: 'Brainstorming session report',
        text:
            'Session "${session.sessionName}" report exported from AiBro.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  /// Loads all stored reports on this device, filtered to those that
  /// correspond to locally available report files.
  Future<void> _loadStoredReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all reports from the per-device documents folder
      // (e.g. <Documents>/aibro/reports) without requiring a matching
      // recording entry. This ensures any locally generated report
      // file is visible in the list.
      final filteredReports = await _reportFileService.listStoredReports();
      if (!mounted) return;
      setState(() {
        _storedReports = filteredReports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reports: $e';
        _isLoading = false;
      });
    }
  }

  /// Opens the folder containing the given [report] or the report itself
  /// when folders are not browsable (mobile).
  Future<void> _openReportLocation(StoredReport report) async {
    final file = File(report.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report file not found on device.')),
      );
      await _loadStoredReports();
      return;
    }

    final directory = file.parent;

    // On desktop platforms try to open the containing folder. On mobile,
    // fall back to opening the file itself since folders are not typically
    // browsable by apps.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await OpenFilex.open(directory.path);
    } else {
      await OpenFilex.open(report.filePath);
    }
  }

  /// Shares the given [report] via the platform share sheet when possible.
  Future<void> _shareReport(StoredReport report) async {
    final file = File(report.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report file not found on device.')),
      );
      await _loadStoredReports();
      return;
    }

    final xFile = XFile(report.filePath);
    try {
      await Share.shareXFiles(
        [xFile],
        subject: 'Brainstorming session report',
        text:
            'Attached is a brainstorming session report generated by AiBro${report.sessionId != null ? ' (session #${report.sessionId})' : ''}.',
      );
    } catch (_) {
      await _shareReportByEmail(report);
    }
  }

  /// Fallback share mechanism that opens an email draft referencing
  /// the given [report].
  Future<void> _shareReportByEmail(StoredReport report) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: <String, String>{
        'subject': 'Brainstorming session report',
        'body':
            "Please attach the AiBro brainstorming session report${report.sessionId != null ? ' (session #${report.sessionId})' : ''}.\n\nFile location on this device: ${report.filePath}",
      },
    );

    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email is not available on this device.')),
      );
      return;
    }

    await launchUrl(uri);
  }

  /// Deletes the given [report] file from disk after confirmation.
  Future<void> _deleteReport(StoredReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete report'),
          content: const Text(
              'Are you sure you want to delete this session report from this device?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.darkGray),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: AppColors.darkGray),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final file = File(report.filePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete report file.')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report deleted.')),
    );
    await _loadStoredReports();
  }

  /// Builds the list view of all locally stored reports.
  Widget _buildReportsList() {
    if (_storedReports.isEmpty) {
      return const Center(
        child: Text('No reports have been generated on this device yet.'),
      );
    }

    final dateFormat = DateFormat.yMMMd().add_Hm();

    return RefreshIndicator(
      onRefresh: _loadStoredReports,
      child: ListView.builder(
        itemCount: _storedReports.length,
        itemBuilder: (context, index) {
          final report = _storedReports[index];
          final sessionIdText =
              report.sessionId != null ? 'Session ${report.sessionId}' : 'Unknown session';
          final dateStr = dateFormat.format(report.createdAt.toLocal());

          return ListTile(
            title: Text(sessionIdText),
            subtitle: Text('${report.fileName} • $dateStr'),
            trailing: Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'Open report',
                  icon: const Icon(Icons.description_outlined),
                  onPressed: () => _openFile(File(report.filePath)),
                ),
                IconButton(
                  tooltip: 'Open location',
                  icon: const Icon(Icons.folder_open),
                  onPressed: () => _openReportLocation(report),
                ),
                IconButton(
                  tooltip: 'Export by email or share',
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => _shareReport(report),
                ),
                IconButton(
                  tooltip: 'Delete report',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteReport(report),
                ),
              ],
            ),
            onTap: () {
              if (report.sessionId != null) {
                Navigator.of(context).pushNamed(
                  '/reportDetail',
                  arguments: {
                    'sessionId': report.sessionId,
                    'filePath': report.filePath,
                  },
                );
              } else {
                // Fallback: if we cannot infer the session id from the
                // filename, open the file directly so the report remains
                // accessible.
                _openFile(File(report.filePath));
              }
            },
          );
        },
      ),
    );
  }

  /// Builds the detailed body when a specific [session] and [report]
  /// are available.
  Widget _buildReportBody(
    BrainstormingSession session,
    SessionReport report,
  ) {
    final objective = (session.objective ?? '').trim();
    final participants = session.participants;
    final durationMinutes = report.statistics.durationMinutes;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  report.sessionName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_hasCheckedRecording && !_isGenerating && !_hasRecordingForSession)
                IconButton(
                  tooltip: 'Export report',
                  icon: const Icon(Icons.ios_share),
                  onPressed: _exportReport,
                ),
              if (_hasCheckedRecording && !_isGenerating && _hasRecordingForSession)
                IconButton(
                  tooltip: 'Generate Word report',
                  icon: const Icon(Icons.description_outlined),
                  onPressed: _generateWordReport,
                ),
              if (_isGenerating)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (objective.isNotEmpty)
            Text(
              'Objective: $objective',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 8),
          Text(
            'Participants: ${participants.isEmpty
                    ? 'N/A'
                    : participants.join(', ')}',
          ),
          const SizedBox(height: 4),
          Text('Selected AI model: ${session.aiModel}'),
          if (durationMinutes > 0) ...[
            const SizedBox(height: 4),
            Text('Duration: $durationMinutes minute(s)'),
          ],
          const SizedBox(height: 16),
          if (report.summary != null && report.summary!.trim().isNotEmpty) ...[
            Text(
              'AI summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(report.summary!.trim()),
            const SizedBox(height: 16),
          ],
          Text(
            'Contributions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.contributions.length,
            itemBuilder: (context, index) {
              final c = report.contributions[index];
              final isAi = c.type.toUpperCase() == 'AI';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isAi ? Colors.blueAccent : AppColors.darkGray700,
                  child: Text(
                    c.speaker.isNotEmpty
                        ? c.speaker[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(isAi ? '[AI] ${c.speaker}' : c.speaker),
                subtitle: Text(c.content),
              );
            },
          ),
        ],
      ),
    );
  }
}
