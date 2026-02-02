import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/session.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/prompt_voice_service.dart';
import '../utils/app_colors.dart';


/// Landing screen that lets the user start a new session,
/// review previous recordings, or open settings and reports.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// State for [HomeScreen] handling session creation flow.
class _HomeScreenState extends State<HomeScreen> {
  bool _isCreatingSession = false;

  String? _buildNumber;

  @override
  void initState() {
    super.initState();
    _loadBuildInfo();
  }

  Future<void> _loadBuildInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _buildNumber = info.buildNumber;
      });
    } catch (_) {
      // If build info cannot be loaded, we simply leave it null.
    }
  }

  /// Starts the interactive session creation wizard.
  Future<void> _startSession(BuildContext context) async {
    if (_isCreatingSession) return;

    setState(() {
      _isCreatingSession = true;
    });

    try {
      // Ask the user (with both text and voice prompts) for
      // number of participants, their first names, the
      // objective of the brainstorming session, and
      // optionally run a voice calibration step.
      final BrainstormingSession? session = await _showSessionSetupDialog(context);
      if (!mounted || session == null) {
        return;
      }

      Navigator.pushNamed(
        context,
        '/session',
        arguments: session,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start session: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingSession = false;
        });
      }
    }
  }

  /// Shows the multi-step dialog used to configure a new session.
  Future<BrainstormingSession?> _showSessionSetupDialog(BuildContext context) async {
    final voice = context.read<PromptVoiceService>();

    return showDialog<BrainstormingSession>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _SessionSetupDialog(voice: voice);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AiBro - Home',
          style: TextStyle(color: AppColors.darkGray),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AiBro - Home',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: AppColors.darkGray),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isCreatingSession
                        ? null
                        : () => _startSession(context),
                    child: _isCreatingSession
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Start Session',
                            style: TextStyle(color: AppColors.darkGray),
                          ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/recordings'),
                    child: const Text(
                      'Previous sessions',
                      style: TextStyle(color: AppColors.darkGray),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/report'),
                    child: const Text(
                      'View Reports',
                      style: TextStyle(color: AppColors.darkGray),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    child: const Text(
                      'Settings',
                      style: TextStyle(color: AppColors.darkGray),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showAboutDialog(context),
                    child: const Text(
                      'About',
                      style: TextStyle(color: AppColors.darkGray),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('About AiBro'),
          content: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AiBro is an open-source project. You can find the source code on GitHub:',
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _openGitHubRepo,
                    child: const Text(
                      'github.com/askeita/aibro',
                      style: TextStyle(color: AppColors.darkGray),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Build number: ${_buildNumber ?? 'Unknown'}'),
                  const SizedBox(height: 4),
                  Text('Date: $formattedDate'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.darkGray),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openGitHubRepo() async {
    final uri = Uri.parse('https://github.com/askeita/aibro');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SessionSetupDialog extends StatefulWidget {
  final PromptVoiceService voice;

  const _SessionSetupDialog({required this.voice});

  /// Creates the mutable state for the session setup dialog.
  @override
  State<_SessionSetupDialog> createState() => _SessionSetupDialogState();
}

/// State managing the multi-step participant and objective collection dialog.
class _SessionSetupDialogState extends State<_SessionSetupDialog> {
  int _step = 0; // 0: count, 1: names, 2: calibrate (if >= 2 participants), 3: objective
  final TextEditingController _countController = TextEditingController(text: '2');
  final List<TextEditingController> _nameControllers = [];
  final TextEditingController _objectiveController = TextEditingController();
  String? _errorText;
  bool _isCreatingSession = false;
  bool _isRecordingCalibration = false;
  bool _calibrationDone = false;
  List<int>? _calibrationAudio;
  List<String> _participants = [];
  int _currentParticipantIndex = 0;
  BrainstormingSession? _createdSession;

  @override
  void initState() {
    super.initState();
    _speakCurrentStep();
  }

  @override
  void dispose() {
    _countController.dispose();
    for (final c in _nameControllers) {
      c.dispose();
    }
    _objectiveController.dispose();
    super.dispose();
  }

  /// Uses TTS to announce the current step of the wizard.
  void _speakCurrentStep() {
    switch (_step) {
      case 0:
        widget.voice.speak('How many participants will join the brainstorming session?');
        break;
      case 1:
        widget.voice.speak('Please enter the first names of all participants.');
        break;
      case 2:
        widget.voice.speak('Now we will calibrate voices. One by one, in the same order as the list of participants, each person should briefly say their name.');
        break;
      case 3:
        widget.voice.speak('What is the objective of this brainstorming session?');
        break;
    }
  }

  /// Validates the participant count and proceeds to the names step.
  void _goToNamesStep() {
    final count = int.tryParse(_countController.text.trim());
    if (count == null || count < 1 || count > 6) {
      setState(() {
        _errorText = 'Number of participants must be between 1 and 6.';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _nameControllers.clear();
      for (int i = 0; i < count; i++) {
        _nameControllers.add(TextEditingController());
      }
      _step = 1;
    });
    _speakCurrentStep();
  }

  /// Validates entered participant names and advances to calibration
  /// or objective entry.
  void _goToNextAfterNames() {
    final names = _nameControllers.map((c) => c.text.trim()).toList();
    if (names.any((n) => n.isEmpty)) {
      setState(() {
        _errorText = 'Please fill in all participant first names.';
      });
      return;
    }

    final bool hasMultipleParticipants = names.length >= 2;

    setState(() {
      _errorText = null;
      _participants = names;
      _currentParticipantIndex = 0;
      _calibrationDone = false;
      _calibrationAudio = null;
      // If there are at least 2 participants, go to calibration first,
      // otherwise skip directly to the objective step.
      _step = hasMultipleParticipants ? 2 : 3;
    });
    _speakCurrentStep();
  }

  /// Creates the session on the backend and, when available, uploads the
  /// calibration recording.
  Future<void> _createSessionAndMaybeCalibrate() async {
    final objective = _objectiveController.text.trim();
    if (objective.isEmpty) {
      setState(() {
        _errorText = 'Please describe the objective of the session.';
      });
      return;
    }

    final participants = _nameControllers.map((c) => c.text.trim()).toList();
    if (participants.isEmpty) {
      setState(() {
        _errorText = 'Please add at least one participant.';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _isCreatingSession = true;
      _participants = participants;
    });

    try {
      final api = context.read<ApiService>();
      final sessionName = 'Brainstorming: $objective';

      final BrainstormingSession session = await api.createSession(
        sessionName: sessionName,
        participants: participants,
        objective: objective,
      );

      if (!mounted) return;

      _createdSession = session;
      final count = participants.length;

      // If we have recorded calibration audio and at least 2 participants,
      // send the calibration to the backend now that the session exists.
      if (count >= 2 && _calibrationAudio != null && _calibrationAudio!.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('userId') ?? 'local-user';

        try {
          await api.calibrateSpeakers(
            _createdSession!.id,
            userId,
            _calibrationAudio!,
          );

          if (mounted) {
            setState(() {
              _calibrationDone = true;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorText = 'Session created but calibration failed: $e';
            });
          }
        }
      }

      if (mounted) {
        _isCreatingSession = false;
        Navigator.of(context).pop(session);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreatingSession = false;
        _errorText = 'Failed to create session: $e';
      });
    }
  }

  /// Starts or stops the calibration recording, tracking progress across
  /// participants.
  Future<void> _toggleCalibrationRecording() async {
    final audio = context.read<AudioService>();

    if (!_isRecordingCalibration) {
      // Starting (or restarting) a calibration recording
      setState(() {
        _calibrationDone = false;
        _calibrationAudio = null;
        _currentParticipantIndex = 0;
        _errorText = null;
      });

      final granted = await audio.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
        return;
      }

      try {
        await audio.startRecording();
        if (!mounted) return;
        setState(() {
          _isRecordingCalibration = true;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start calibration recording: $e')),
        );
      }
    } else {
      try {
        final bytes = await audio.stopRecording();
        if (!mounted) return;
        setState(() {
          _isRecordingCalibration = false;
        });

        if (bytes != null && bytes.isNotEmpty) {
          final bool allParticipantsAdvanced =
              _participants.isEmpty || _currentParticipantIndex >= _participants.length - 1;
          setState(() {
            _calibrationAudio = bytes;
            _calibrationDone = allParticipantsAdvanced;
            _errorText = allParticipantsAdvanced
                ? null
                : 'Not all participants were advanced during calibration. You can repeat calibration if needed.';
          });

          if (!allParticipantsAdvanced) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Calibration stopped before all participants were advanced. Consider redoing calibration before continuing.',
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete calibration: $e')),
        );
      }
    }
  }

  /// Closes the dialog, returning the created session when available.
  void _finishWithSession() {
    if (_createdSession == null) {
      setState(() {
        _errorText = 'Session was not created. Please go back and try again.';
      });
      return;
    }
    Navigator.of(context).pop(_createdSession);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start a Session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_step == 0) ...[
            const Text('How many participants will join the brainstorming session?'),
            const SizedBox(height: 12),
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of participants',
                helperText: 'Enter an integer between 1 and 6',
                errorText: _errorText,
              ),
            ),
          ] else if (_step == 1) ...[
            const Text('Please enter the first names of the participants.'),
            const SizedBox(height: 12),
            SizedBox(
              width: 300,
              height: 200,
              child: ListView.builder(
                itemCount: _nameControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: TextField(
                      controller: _nameControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Participant ${index + 1}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else if (_step == 2) ...[
            SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Calibrate voices'),
                  const SizedBox(height: 12),
                  Text(
                    'Each participant should briefly introduce themselves by saying: "Hello, my name is <name>".',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'They should speak one after another, in the same order as the list of first names.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_participants.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: List.generate(_participants.length, (index) {
                        final bool isCurrent = index == _currentParticipantIndex;
                        return Chip(
                          label: Text(_participants[index]),
                          backgroundColor: isCurrent
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                              : null,
                          labelStyle: isCurrent
                              ? TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                )
                              : null,
                        );
                      }),
                    ),
                  if (_participants.isNotEmpty) const SizedBox(height: 8),
                  Text(
                    'Tap the button below to start and stop the calibration recording. While recording, tap "Next participant" after each person finishes speaking so the next first name is prompted.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_participants.isNotEmpty)
                    Text(
                      'Current participant: ${_participants[_currentParticipantIndex]}.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (_participants.length > 1 && _currentParticipantIndex < _participants.length - 1)
                    const SizedBox(height: 4),
                  if (_participants.length > 1 && _currentParticipantIndex < _participants.length - 1)
                    Text(
                      'Then: ${_participants[_currentParticipantIndex + 1]}.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (_participants.isNotEmpty)
                    const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isCreatingSession
                        ? null
                        : () {
                            _toggleCalibrationRecording();
                          },
                    icon: Icon(_isRecordingCalibration ? Icons.stop : Icons.mic),
                    label: Text(
                      _isRecordingCalibration
                          ? 'Stop calibration recording'
                          : (_calibrationAudio != null
                              ? 'Restart calibration recording'
                              : 'Start calibration recording'),
                      style: const TextStyle(color: AppColors.darkGray),
                    ),
                  ),
                    if (_isRecordingCalibration &&
                      _participants.length > 1 &&
                      _currentParticipantIndex < _participants.length - 1) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (_currentParticipantIndex < _participants.length - 1) {
                            _currentParticipantIndex++;
                          }
                        });
                      },
                      child: const Text(
                        'Next participant',
                        style: TextStyle(color: AppColors.darkGray),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_calibrationDone)
                    const Text(
                      'Calibration recording captured. If all participants have spoken, tap Next to continue.',
                      style: TextStyle(color: Colors.green),
                    ),
                ],
              ),
            ),
          ] else ...[
            const Text('What is the objective of this brainstorming session?'),
            const SizedBox(height: 12),
            TextField(
              controller: _objectiveController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Objective',
              ),
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<BrainstormingSession?>(null),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF636363)),
          ),
        ),
        if (_step > 0)
          TextButton(
            onPressed: () {
              setState(() {
                _errorText = null;
                _step -= 1;
                _isRecordingCalibration = false;
              });
              _speakCurrentStep();
            },
            child: const Text(
              'Back',
              style: TextStyle(color: Color(0xFF636363)),
            ),
          ),
        TextButton(
          onPressed: _isCreatingSession
              ? null
              : () {
                  if (_step == 0) {
                    _goToNamesStep();
                  } else if (_step == 1) {
                    _goToNextAfterNames();
                  } else if (_step == 2) {
                    final bool needsCalibration = _participants.length >= 2;
                    final bool allParticipantsAdvanced =
                        _participants.isEmpty || _currentParticipantIndex >= _participants.length - 1;

                    if (needsCalibration && (!_calibrationDone || !allParticipantsAdvanced)) {
                      setState(() {
                        _errorText =
                            'Please let all participants speak and advance through them before continuing.';
                      });
                      return;
                    }

                    setState(() {
                      _errorText = null;
                      _step = 3;
                    });
                    _speakCurrentStep();
                  } else {
                    _createSessionAndMaybeCalibrate();
                  }
                },
          child: Text(
            _step == 3 ? 'Start' : 'Next',
            style: const TextStyle(color: AppColors.darkGray),
          ),
        ),
      ],
    );
  }
}

