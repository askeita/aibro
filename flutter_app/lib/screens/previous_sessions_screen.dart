import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/session_recording_service.dart';


/// Screen listing locally stored session recordings and related actions.
class PreviousSessionsScreen extends StatefulWidget {
  const PreviousSessionsScreen({super.key});

  @override
  State<PreviousSessionsScreen> createState() => _PreviousSessionsScreenState();
}

/// State for [PreviousSessionsScreen] that manages loading and actions
/// on stored session recordings.
class _PreviousSessionsScreenState extends State<PreviousSessionsScreen> {
  final SessionRecordingService _recordingService = SessionRecordingService();
  List<SessionRecording> _recordings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Loads the list of stored recordings from disk.
  Future<void> _loadRecordings() async {
    final recordings = await _recordingService.listRecordings();
    if (!mounted) return;
    setState(() {
      _recordings = recordings;
      _isLoading = false;
    });
  }

  /// Opens the folder containing the given [recording] or the recording
  /// file itself depending on the platform.
  Future<void> _openLocation(SessionRecording recording) async {
    final file = File(recording.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording file not found on device.')),
      );
      await _loadRecordings();
      return;
    }

    final directory = file.parent;

    // On desktop platforms try to open the containing folder. On mobile,
    // fall back to opening the file itself since folders are not typically
    // browsable by apps.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await OpenFilex.open(directory.path);
    } else {
      await OpenFilex.open(recording.filePath);
    }
  }

  /// Shares the given [recording] via the platform share sheet.
  Future<void> _shareRecording(SessionRecording recording) async {
    final file = File(recording.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording file not found on device.')),
      );
      await _loadRecordings();
      return;
    }

    final xFile = XFile(recording.filePath);
    try {
      await Share.shareXFiles(
        [xFile],
        subject: 'Brainstorming session recording',
        text:
            'Attached is a recorded brainstorming session from AiBro (session #${recording.sessionId}).',
      );
    } catch (e) {
      await _shareRecordingByEmail(recording);
    }
  }

  /// Fallback share path that opens an email draft referencing the
  /// recording file location.
  Future<void> _shareRecordingByEmail(SessionRecording recording) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: <String, String>{
        'subject': 'Brainstorming session recording',
        'body':
            'Please attach the AiBro brainstorming session recording (session #${recording.sessionId}).\n\nFile location on this device: ${recording.filePath}',
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

  /// Deletes the given [recording] from disk after user confirmation.
  Future<void> _deleteRecording(SessionRecording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete recording'),
          content: const Text(
              'Are you sure you want to delete this recorded brainstorming session from this device?'),
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

    await _recordingService.deleteRecording(recording);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording deleted.')),
    );
    await _loadRecordings();
  }

  /// Opens the audio file for the given [recording] using the OS.
  Future<void> _openRecording(SessionRecording recording) async {
    final file = File(recording.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording file not found on device.')),
      );
      await _loadRecordings();
      return;
    }

    await OpenFilex.open(recording.filePath);
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_recordings.isEmpty) {
      content = const Center(
        child: Text('No recorded brainstorming sessions found on this device.'),
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _loadRecordings,
        child: ListView.builder(
          itemCount: _recordings.length,
          itemBuilder: (context, index) {
            final rec = _recordings[index];
            final dateStr = DateFormat.yMMMd().add_Hms().format(rec.recordedAt.toLocal());
            final fileName = rec.filePath.split(Platform.pathSeparator).last;
            return ListTile(
              title: Text('Session ${rec.sessionId}'),
              subtitle: Text(
                [
                  if (rec.objective != null && rec.objective!.trim().isNotEmpty)
                    rec.objective!.trim(),
                  'Recorded on $dateStr',
                  fileName,
                ].join(' • '),
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Play recording',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _openRecording(rec),
                  ),
                  IconButton(
                    tooltip: 'Open location',
                    icon: const Icon(Icons.folder_open),
                    onPressed: () => _openLocation(rec),
                  ),
                  IconButton(
                    tooltip: 'Export by email or share',
                    icon: const Icon(Icons.ios_share),
                    onPressed: () => _shareRecording(rec),
                  ),
                  IconButton(
                    tooltip: 'Delete recording',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteRecording(rec),
                  ),
                ],
              ),
            );
          },
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Previous sessions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
