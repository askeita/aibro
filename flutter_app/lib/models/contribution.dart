/// Immutable model representing a single contribution within a session.
class Contribution {
  final int id;
  final String speaker;
  final String content;
  final DateTime timestamp;
  final String type;
  final double? confidence;

  /// Creates a new [Contribution] instance.
  Contribution({
    required this.id,
    required this.speaker,
    required this.content,
    required this.timestamp,
    required this.type,
    this.confidence,
  });

  /// Builds a [Contribution] from a JSON map.
  factory Contribution.fromJson(Map<String, dynamic> json) {
    return Contribution(
      id: json['id'] as int,
      speaker: json['speaker'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: json['type'] as String,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}
