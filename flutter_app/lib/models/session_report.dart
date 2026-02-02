import 'contribution.dart';


/// Aggregate statistics for a single brainstorming session report.
class SessionStatistics {
  final int totalContributions;
  final int humanContributions;
  final int aiContributions;
  final int durationMinutes;

  /// Creates a new [SessionStatistics] instance.
  SessionStatistics({
    required this.totalContributions,
    required this.humanContributions,
    required this.aiContributions,
    required this.durationMinutes,
  });

  /// Builds [SessionStatistics] from a JSON map.
  factory SessionStatistics.fromJson(Map<String, dynamic> json) {
    return SessionStatistics(
      totalContributions: (json['totalContributions'] as num?)?.toInt() ?? 0,
      humanContributions: (json['humanContributions'] as num?)?.toInt() ?? 0,
      aiContributions: (json['aiContributions'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Full report data for a single brainstorming session, including
/// contributions, transcript, and statistics.
class SessionReport {
  final int sessionId;
  final String sessionName;
  final String? summary;
  final List<Contribution> contributions;
  final String? fullTranscript;
  final SessionStatistics statistics;

  /// Creates a new [SessionReport] instance.
  SessionReport({
    required this.sessionId,
    required this.sessionName,
    this.summary,
    required this.contributions,
    this.fullTranscript,
    required this.statistics,
  });

  /// Builds a [SessionReport] from a JSON map.
  factory SessionReport.fromJson(Map<String, dynamic> json) {
    return SessionReport(
      sessionId: json['sessionId'] as int,
      sessionName: json['sessionName'] as String,
      summary: json['summary'] as String?,
      contributions: (json['contributions'] as List<dynamic>? ?? [])
          .map((e) => Contribution.fromJson(e as Map<String, dynamic>))
          .toList(),
      fullTranscript: json['fullTranscript'] as String?,
      statistics: SessionStatistics.fromJson(
        json['statistics'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
