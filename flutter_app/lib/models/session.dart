/// Immutable model representing a brainstorming session as returned by the
/// backend API.
class BrainstormingSession {
  final int id;
  final String sessionName;
  final DateTime? startTime;
  final DateTime? endTime;
  final String status;
  final List<String> participants;
  final String aiModel;
  final int aiContributionFrequency;
  final String aiVoiceGender;
  final String? summary;
    final String? objective;

  /// Creates a new [BrainstormingSession] instance.
  BrainstormingSession({
    required this.id,
    required this.sessionName,
    this.startTime,
    this.endTime,
    required this.status,
    required this.participants,
    required this.aiModel,
    required this.aiContributionFrequency,
    required this.aiVoiceGender,
    this.summary,
    this.objective,
  });

  /// Builds a [BrainstormingSession] from a JSON map.
  factory BrainstormingSession.fromJson(Map<String, dynamic> json) {
    return BrainstormingSession(
      id: json['id'] as int,
      sessionName: json['sessionName'] as String,
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      status: json['status'] as String,
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      aiModel: json['aiModel'] as String,
      aiContributionFrequency:
          (json['aiContributionFrequency'] as num?)?.toInt() ?? 0,
      aiVoiceGender: json['aiVoiceGender'] as String,
      summary: json['summary'] as String?,
      objective: json['objective'] as String?,
    );
  }
}
