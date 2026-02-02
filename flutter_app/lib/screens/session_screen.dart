import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_colors.dart';

import '../models/session.dart';
import '../models/session_report.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/websocket_service.dart';
import '../widgets/ai_indicator.dart';
import '../services/session_recording_service.dart';


/// Main in-session screen showing live contributions, AI status and controls.
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

/// State driving the brainstorming session experience.
class _SessionScreenState extends State<SessionScreen> {
  BrainstormingSession? _session;
  SessionReport? _report;
  bool _isLoading = true;
  String? _error;
  bool _aiThinking = false;
  bool _isEndingSession = false;
  bool _humanDecideMode = false;
  bool _forceAiNextContribution = false;
  bool _isCalibrating = false;
  bool _isSessionRecording = false;
  String? _currentSessionRecordingPath;
  bool _isStreaming = false;
  bool _isSendingChunk = false;
  Timer? _sessionTimer;
  Duration _timerValue = Duration.zero;
  bool _timerRunning = false;
  bool _isCountdownTimer = false;
  late final ApiService _api;
  late final AudioService _audio;
  late final WebSocketService _ws;
  bool _servicesInitialized = false;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    _loadContributionMode();
  }

  Future<void> _loadContributionMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('aiContributionMode') ?? 'ai-decide';
    if (!mounted) return;
    setState(() {
      _humanDecideMode = mode == 'human-decide';
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_servicesInitialized) {
      _api = context.read<ApiService>();
      _audio = context.read<AudioService>();
      _ws = context.read<WebSocketService>();
      _servicesInitialized = true;
    }

    if (_session == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is BrainstormingSession) {
        _session = args;
        _loadInitial();
        _connectWebSocket();
      }
    }
  }

  /// Loads the initial report and contributions for the current session.
  Future<void> _loadInitial() async {
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

  /// Connects to the backend WebSocket to receive AI notifications.
  void _connectWebSocket() {
    final session = _session;
    if (session == null) return;

    _ws.connect(session.id);
    _wsSub = _ws.aiMessages.listen((message) async {
      final type = (message['type'] as String?) ?? '';
      if (type == 'SIGNAL') {
        if (mounted) {
          setState(() {
            _aiThinking = true;
          });
        }
      } else if (type == 'CONTRIBUTION') {
        if (mounted) {
          setState(() {
            _aiThinking = false;
            _forceAiNextContribution = false; // reset manual trigger after AI speaks
          });
        }
        await _loadInitial();
      }
    });
  }

  /// Toggles audio capture between idle and streaming or calibration mode.
  Future<void> _toggleRecording() async {
    final session = _session;
    if (session == null) return;

    // Calibration keeps the previous single-shot behaviour.
    if (_isCalibrating) {
      await _recordSingleChunkAndSend(isCalibration: true);
      return;
    }

    // Normal behaviour: toggle streaming mode (continuous 15s chunks).
    if (!_isStreaming) {
      final granted = await _audio.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
        return;
      }

      setState(() {
        _isStreaming = true;
      });
      _startStreamingLoop();
    } else {
      // Stop streaming after the current chunk finishes and notify the user.
      setState(() {
        _isStreaming = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone streaming stopped.')),
        );
      }
    }
  }

  /// Records a single audio chunk and sends it either as calibration
  /// or for normal transcription based on [isCalibration].
  Future<void> _recordSingleChunkAndSend({required bool isCalibration}) async {
    final session = _session;
    if (session == null) return;

    try {
      await _audio.startRecording();
      // Short single-shot capture; duration is driven by user tapping again
      // (calibration flow should manage stop elsewhere if needed).
      final bytes = await _audio.stopRecording();
      if (bytes != null && bytes.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('userId') ?? 'local-user';
        if (isCalibration) {
          await _api.calibrateSpeakers(
            session.id,
            userId,
            bytes,
          );
          if (mounted) {
            setState(() {
              _isCalibrating = false;
            });
          }
        } else {
          await _api.transcribeAudio(
            session.id,
            userId,
            bytes,
            forceAi: _humanDecideMode && _forceAiNextContribution,
          );
          await _loadInitial();
        }
      }
    } catch (e) {
      if (!mounted) return;
      String message = 'Failed to record audio.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] is String) {
          message = 'Failed to transcribe audio: ${data['error']}';
        } else {
          message = 'Transcription request failed (HTTP ${e.response?.statusCode ?? 'error'}).';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// Continuously records fixed-length audio chunks and sends them while
  /// streaming is enabled.
  Future<void> _startStreamingLoop() async {
    final session = _session;
    if (session == null) return;

    while (mounted && _isStreaming) {
      try {
        await _audio.startRecording();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
        setState(() {
          _isStreaming = false;
        });
        break;
      }

      // Record a 15 second chunk before sending.
      await Future.delayed(const Duration(seconds: 15));

      List<int>? bytes;
      try {
        bytes = await _audio.stopRecording();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to stop recording.')),
        );
      }

      // If streaming has been toggled off while this chunk was recording,
      // exit after stopping (do not start a new chunk).
      if (!(mounted && _isStreaming)) {
        break;
      }

      if (bytes != null && bytes.isNotEmpty) {
        try {
          if (mounted) {
            setState(() {
              _isSendingChunk = true;
            });
          }
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getString('userId') ?? 'local-user';
          await _api.transcribeAudio(
            session.id,
            userId,
            bytes,
            forceAi: _humanDecideMode && _forceAiNextContribution,
          );
          await _loadInitial();
        } catch (e) {
          if (!mounted) return;
          String message = 'Failed to send audio chunk.';
          if (e is DioException) {
            final data = e.response?.data;
            if (data is Map && data['error'] is String) {
              message = 'Failed to transcribe audio: ${data['error']}';
            } else {
              message = 'Transcription request failed (HTTP ${e.response?.statusCode ?? 'error'}).';
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        } finally {
          if (mounted) {
            setState(() {
              _isSendingChunk = false;
            });
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _isStreaming = false;
      });
    }
  }

  /// Starts or stops a long-running session-level recording stored locally.
  Future<void> _toggleSessionRecording() async {
    final session = _session;
    if (session == null) return;

    if (!_isSessionRecording) {
      final granted = await _audio.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
        return;
      }

      try {
        final recordingService = SessionRecordingService();
        final filePath = await recordingService.createRecordingFilePath(session.id);
        await _audio.startSessionRecording(filePath);
        if (!mounted) return;
        setState(() {
          _isSessionRecording = true;
          _currentSessionRecordingPath = filePath;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session recording: $e')),
        );
      }
    } else {
      await _stopAndPersistSessionRecording(showMessage: true);
    }
  }

  Future<void> _stopAndPersistSessionRecording({bool showMessage = false}) async {
    final session = _session;
    if (session == null) return;
    if (!_isSessionRecording) return;

    try {
      await _audio.stopSessionRecording();
      if (!mounted) return;

      if (_currentSessionRecordingPath != null) {
        final recordingService = SessionRecordingService();
        final recording = SessionRecording(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sessionId: session.id,
          objective: session.objective,
          recordedAt: DateTime.now(),
          filePath: _currentSessionRecordingPath!,
        );
        await recordingService.addRecording(recording);
        _currentSessionRecordingPath = null;
      }

      setState(() {
        _isSessionRecording = false;
      });

      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session recording stopped.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop session recording: $e')),
      );
    }
  }

  /// Confirms and ends the current session, navigating to the report screen.
  Future<void> _onEndSessionPressed() async {
    if (_isEndingSession) return;

    final session = _session;
    if (session == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End session'),
          content: const Text(
            'Are you sure you want to end this session?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.darkGray),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'End session',
                style: TextStyle(color: AppColors.darkGray),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isEndingSession = true;
    });

    // Show a blocking progress indicator while ending the session so the user
    // does not need (or try) to tap the button multiple times.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text('Ending current session...'),
              ),
            ],
          ),
        );
      },
    );

    // Ensure any active session recording is cleanly stopped and saved
    // before ending the session and navigating away.
    await _stopAndPersistSessionRecording(showMessage: false);

    try {
      await _api.endSession(session.id);
    } catch (_) {
      // Even if ending the session fails on the backend,
      // we still proceed with local navigation.
    }

    if (!mounted) return;

    // Dismiss the progress dialog if it is still visible.
    Navigator.of(context, rootNavigator: true).pop();

    // Always navigate to the report screen after ending the session.
    _sessionTimer?.cancel();
    Navigator.of(context).pushReplacementNamed(
      '/report',
      arguments: session,
    );
  }

  /// Opens the configuration dialog for the session timer.
  Future<_TimerDialogResult?> _showTimerDialog() async {
    _TimerType selectedType = _TimerType.elapsed;
    final TextEditingController minutesController =
        TextEditingController(text: '15');
    String? errorText;

    final result = await showDialog<_TimerDialogResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Session timer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<_TimerType>(
                    title: const Text('Show elapsed time'),
                    value: _TimerType.elapsed,
                    groupValue: selectedType,
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() {
                        selectedType = value;
                        errorText = null;
                      });
                    },
                  ),
                  RadioListTile<_TimerType>(
                    title: const Text('Countdown to expected duration'),
                    value: _TimerType.countdown,
                    groupValue: selectedType,
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() {
                        selectedType = value;
                        errorText = null;
                      });
                    },
                  ),
                  if (selectedType == _TimerType.countdown) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                      ),
                    ),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.darkGray),
                    ),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedType == _TimerType.countdown) {
                      final text = minutesController.text.trim();
                      final minutes = int.tryParse(text) ?? 0;
                      if (minutes <= 0) {
                        setStateDialog(() {
                          errorText =
                              'Please enter a positive duration in minutes.';
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(
                        _TimerDialogResult(
                          _TimerType.countdown,
                          countdownDuration: Duration(minutes: minutes),
                        ),
                      );
                    } else {
                      Navigator.of(dialogContext).pop(
                        const _TimerDialogResult(_TimerType.elapsed),
                      );
                    }
                  },
                    child: const Text(
                      'Validate',
                      style: TextStyle(color: AppColors.darkGray),
                    ),
                ),
              ],
            );
          },
        );
      },
    );

    minutesController.dispose();
    return result;
  }

  /// Starts an elapsed or countdown timer based on [config].
  void _startTimer(_TimerDialogResult config) {
    _sessionTimer?.cancel();

    setState(() {
      _timerRunning = true;
      _isCountdownTimer = config.type == _TimerType.countdown;
      _timerValue = config.type == _TimerType.countdown
          ? (config.countdownDuration ?? Duration.zero)
          : Duration.zero;
    });

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_isCountdownTimer) {
          if (_timerValue > Duration.zero) {
            _timerValue -= const Duration(seconds: 1);
          }
          if (_timerValue <= Duration.zero) {
            _timerValue = Duration.zero;
            _timerRunning = false;
            timer.cancel();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session countdown finished.')),
            );
          }
        } else {
          _timerValue += const Duration(seconds: 1);
        }
      });
    });
  }

  /// Stops and resets the session timer.
  void _stopTimer() {
    _sessionTimer?.cancel();
    setState(() {
      _timerRunning = false;
      _isCountdownTimer = false;
      _timerValue = Duration.zero;
    });
  }

  /// Handles taps on the timer button, prompting for configuration.
  Future<void> _onTimerPressed() async {
    final config = await _showTimerDialog();
    if (config == null) return;
    _startTimer(config);
  }

  /// Formats a [Duration] as a human-readable timer string.
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws.disconnect();
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    if (session == null) {
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
        body: const Center(
          child: Text('No session provided.'),
        ),
      );
    }

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Text('Failed to load session: $_error'),
      );
    } else if (_report == null || _report!.contributions.isEmpty) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SessionHeader(
            session: session,
            isSessionRecording: _isSessionRecording,
            onToggleSessionRecording: _toggleSessionRecording,
            isTimerRunning: _timerRunning,
            timerText:
                _timerRunning ? _formatDuration(_timerValue) : null,
            onTimerPressed: _onTimerPressed,
            onStopTimerPressed: _timerRunning ? _stopTimer : null,
            isEndingSession: _isEndingSession,
            onEndSessionPressed: _onEndSessionPressed,
          ),
          if (_aiThinking) const AIIndicator(),
          const Expanded(
            child: Center(
              child: Text(
                'No contributions yet. You can start sharing ideas.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    } else {
      final report = _report!;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SessionHeader(
            session: session,
            isSessionRecording: _isSessionRecording,
            onToggleSessionRecording: _toggleSessionRecording,
            isTimerRunning: _timerRunning,
            timerText:
                _timerRunning ? _formatDuration(_timerValue) : null,
            onTimerPressed: _onTimerPressed,
            onStopTimerPressed: _timerRunning ? _stopTimer : null,
            isEndingSession: _isEndingSession,
            onEndSessionPressed: _onEndSessionPressed,
          ),
          if (_aiThinking) const AIIndicator(),
          Expanded(
            child: ListView.builder(
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
                  title: Text(c.speaker),
                  subtitle: Text(c.content),
                  trailing: Text(
                    TimeOfDay.fromDateTime(c.timestamp).format(context),
                    style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.secondaryTextGray),
                  ),
                );
              },
            ),
          ),
        ],
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
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (_humanDecideMode)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_modelDisplayName(session.aiModel)} contribute',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Switch(
                    value: _forceAiNextContribution,
                    onChanged: (value) {
                      setState(() {
                        _forceAiNextContribution = value;
                      });
                    },
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isSendingChunk
                        ? 'Sending audio chunk... mic is off.'
                        : _isStreaming
                            ? 'Streaming audio... tap to stop.'
                            : 'Tap the mic to start capturing audio.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                FloatingActionButton(
                  onPressed: _toggleRecording,
                  backgroundColor:
                      _isSendingChunk
                          ? Colors.amber
                          : _isStreaming
                              ? Colors.redAccent
                              : Colors.blue,
                  child: Icon(
                    _isSendingChunk
                        ? Icons.cloud_upload
                        : _isStreaming
                            ? Icons.stop
                            : Icons.mic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a user-friendly display name for an [aiModel] identifier.
  String _modelDisplayName(String? aiModel) {
    switch (aiModel?.toLowerCase()) {
      case 'openai':
        return 'GPT';
      case 'claude':
        return 'Claude';
      case 'gemini':
        return 'Gemini';
      default:
        return 'AI model';
    }
  }
}

class _SessionHeader extends StatelessWidget {
  final BrainstormingSession session;
  final bool isSessionRecording;
  final VoidCallback onToggleSessionRecording;
  final bool isTimerRunning;
  final String? timerText;
  final VoidCallback onTimerPressed;
  final VoidCallback? onStopTimerPressed;
  final bool isEndingSession;
  final VoidCallback onEndSessionPressed;

  /// Compact header showing session objective, metadata and controls.
  const _SessionHeader({
    required this.session,
    required this.isSessionRecording,
    required this.onToggleSessionRecording,
    required this.isTimerRunning,
    required this.timerText,
    required this.onTimerPressed,
    required this.onStopTimerPressed,
     required this.isEndingSession,
    required this.onEndSessionPressed,
  });

  @override
  /// Builds the card summarising session details and timer/recording controls.
  Widget build(BuildContext context) {
    final objective = (session.objective ?? '').trim();
    final participantCount = session.participants.length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (objective.isNotEmpty) ...[
                Text(
                  objective,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Number of participants: $participantCount',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: session.participants
                    .map(
                      (p) => Chip(
                        label: Text(p),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              if (isTimerRunning && (timerText != null && timerText!.isNotEmpty)) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    timerText!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 22),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: isSessionRecording
                        ? 'Stop session recording'
                        : 'Record session',
                    icon: Icon(
                      isSessionRecording
                          ? Icons.stop_circle_outlined
                          : Icons.fiber_manual_record,
                    ),
                    color: isSessionRecording
                      ? Colors.redAccent
                      : AppColors.darkGray700,
                    onPressed: onToggleSessionRecording,
                  ),
                  const SizedBox(width: 8),
                  if (!isTimerRunning) ...[
                    IconButton(
                      tooltip: 'Session timer',
                      icon: const Icon(Icons.timer_outlined),
                      onPressed: onTimerPressed,
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: isEndingSession ? null : onEndSessionPressed,
                      child: const Text(
                        'End session',
                        style: TextStyle(color: AppColors.darkGray),
                      ),
                    ),
                  ] else ...[
                    IconButton(
                      tooltip: 'Stop timer',
                      icon: const Icon(Icons.stop),
                      onPressed: onStopTimerPressed,
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: isEndingSession ? null : onEndSessionPressed,
                      child: const Text(
                        'End session',
                        style: TextStyle(color: AppColors.darkGray),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TimerType { elapsed, countdown }

class _TimerDialogResult {
  final _TimerType type;
  final Duration? countdownDuration;

  const _TimerDialogResult(this.type, {this.countdownDuration});
}

