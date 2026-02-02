import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_colors.dart';

import '../services/api_service.dart';


/// Settings screen for configuring API keys, language and AI behaviour.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// State for [SettingsScreen] managing persisted preferences.
class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController(text: 'local-user');
  final _googleKeyController = TextEditingController();
  final _aiModelKeyController = TextEditingController();

  bool _saving = false;
  String _selectedAiModel = 'claude'; // claude, openai (GPT), gemini
  String _selectedLanguageCode = 'en-US';
  String _aiContributionMode = 'ai-decide';

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  /// Loads previously saved settings from [SharedPreferences].
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedUserId = prefs.getString('userId');
    final savedGoogleKey = prefs.getString('googleCloudApiKey');
    final savedClaudeKey = prefs.getString('claudeApiKey');
    final savedAiModel = prefs.getString('aiModel');
    final savedLanguageCode = prefs.getString('speechLanguageCode');
    final savedContributionMode = prefs.getString('aiContributionMode');

    if (!mounted) return;

    setState(() {
      if (savedAiModel != null && savedAiModel.isNotEmpty) {
        _selectedAiModel = savedAiModel;
      }
      if (savedLanguageCode != null && savedLanguageCode.isNotEmpty) {
        _selectedLanguageCode = savedLanguageCode;
      }
      if (savedContributionMode != null && savedContributionMode.isNotEmpty) {
        _aiContributionMode = savedContributionMode;
      }
      if (savedUserId != null && savedUserId.isNotEmpty) {
        _userIdController.text = savedUserId;
      }
      if (savedGoogleKey != null) {
        _googleKeyController.text = savedGoogleKey;
      }
      if (savedClaudeKey != null) {
        _aiModelKeyController.text = savedClaudeKey;
      }
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _googleKeyController.dispose();
    _aiModelKeyController.dispose();
    super.dispose();
  }

  /// Validates and persists the current settings, pushing keys to the backend
  /// and saving them locally.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final api = context.read<ApiService>();

    try {
      final userId = _userIdController.text.trim();
      final aiKey = _aiModelKeyController.text.trim();
      final googleKey = _googleKeyController.text.trim();

      String? claudeKey;
      String? openaiKey;
      String? geminiKey;

      if (aiKey.isNotEmpty) {
        switch (_selectedAiModel) {
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

      await api.saveApiKeys(
        userId: userId,
        claudeApiKey: claudeKey,
        openaiApiKey: openaiKey,
        geminiApiKey: geminiKey,
        googleCloudApiKey: googleKey.isEmpty ? null : googleKey,
      );

      // Persist locally so the settings screen is prefilled next time.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      await prefs.setString('aiModel', _selectedAiModel);
      await prefs.setString('speechLanguageCode', _selectedLanguageCode);
      await prefs.setString('aiContributionMode', _aiContributionMode);

      if (googleKey.isNotEmpty) {
        await prefs.setString('googleCloudApiKey', googleKey);
      } else {
        await prefs.remove('googleCloudApiKey');
      }

      // We keep a single locally stored AI key value for convenience,
      // regardless of which model is selected. This avoids breaking
      // existing saved data while still routing the key to the
      // appropriate backend field based on _selectedAiModel.
      if (aiKey.isNotEmpty) {
        await prefs.setString('claudeApiKey', aiKey);
      } else {
        await prefs.remove('claudeApiKey');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API keys saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save API keys: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String get _aiKeyHintText {
    switch (_selectedAiModel) {
      case 'openai':
        return 'Enter your OpenAI API key (e.g. sk-...)';
      case 'gemini':
        return 'Enter your Google Generative Language (Gemini) API key.';
      case 'claude':
      default:
        return 'Enter your Anthropic Claude API key.';
    }
  }

  String get _languageLabel {
    switch (_selectedLanguageCode) {
      case 'ar':
        return 'Arabic (literal)';
      case 'fr-FR':
        return 'French';
      case 'de-DE':
        return 'German';
      case 'it-IT':
        return 'Italian';
      case 'pt-PT':
        return 'Portuguese';
      case 'es-ES':
        return 'Spanish';
      case 'en-US':
      default:
        return 'English';
    }
  }

  String get _aiContributionDescription {
    switch (_aiContributionMode) {
      case 'ai-always':
        return 'The assistant replies after every human contribution.';
      case 'ai-most':
        return 'The assistant replies frequently but may sometimes stay silent.';
      case 'human-decide':
        return 'The assistant only replies when you enable its switch in a session.';
      case 'ai-decide':
      default:
        return 'The assistant decides when to reply based on the conversation.';
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
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'AI contribution frequency',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _aiContributionMode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ai-always',
                          child: Text('AI always respond'),
                        ),
                        DropdownMenuItem(
                          value: 'ai-most',
                          child: Text(
                            'AI respond most of the time but not always',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ai-decide',
                          child: Text('AI should decide'),
                        ),
                        DropdownMenuItem(
                          value: 'human-decide',
                          child: Text('Human should decide'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _aiContributionMode = value;
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _aiContributionDescription,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mediumGrayText),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Project name (Google Cloud)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Identifier used to store your keys',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Google Cloud API Key (Speech-to-Text & Text-to-Speech)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _googleKeyController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Required for transcription & voice',
                      ),
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Speech Recognition Language',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLanguageCode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ar',
                          child: Text('Arabic (literal)'),
                        ),
                        DropdownMenuItem(
                          value: 'en-US',
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: 'fr-FR',
                          child: Text('French'),
                        ),
                        DropdownMenuItem(
                          value: 'de-DE',
                          child: Text('German'),
                        ),
                        DropdownMenuItem(
                          value: 'it-IT',
                          child: Text('Italian'),
                        ),
                        DropdownMenuItem(
                          value: 'pt-PT',
                          child: Text('Portuguese'),
                        ),
                        DropdownMenuItem(
                          value: 'es-ES',
                          child: Text('Spanish'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedLanguageCode = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'AI Model',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAiModel,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'openai',
                          child: Text('GPT (OpenAI)'),
                        ),
                        DropdownMenuItem(
                          value: 'claude',
                          child: Text('Claude (Anthropic)'),
                        ),
                        DropdownMenuItem(
                          value: 'gemini',
                          child: Text('Gemini (Google)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedAiModel = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'API Key for the AI model',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _aiModelKeyController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Used by Claude/OpenAI/etc.',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _aiKeyHintText,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mediumGrayText),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _saving ? 'Saving...' : 'Save keys',
                          style: const TextStyle(color: AppColors.darkGray),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
