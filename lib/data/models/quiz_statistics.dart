class QuizStatistics {
  QuizStatistics.fromJson(Map<String, dynamic> json)
    : totalAttempts = json['totalAttempts'] as int,
      averagePercentage = (json['averagePercentage'] as num).toDouble(),
      bestPercentage = (json['bestPercentage'] as num).toDouble(),
      passRate = (json['passRate'] as num).toDouble(),
      recentScores = (json['recentScores'] as List)
          .cast<Map<String, dynamic>>()
          .map(QuizScorePoint.fromJson)
          .toList(),
      subjectStats = (json['subjectStats'] as List)
          .cast<Map<String, dynamic>>()
          .map(QuizPerformanceGroup.fromJson)
          .toList(),
      deckStats = (json['deckStats'] as List)
          .cast<Map<String, dynamic>>()
          .map(QuizPerformanceGroup.fromJson)
          .toList();

  final int totalAttempts;
  final double averagePercentage;
  final double bestPercentage;
  final double passRate;
  final List<QuizScorePoint> recentScores;
  final List<QuizPerformanceGroup> subjectStats;
  final List<QuizPerformanceGroup> deckStats;
}

class QuizScorePoint {
  QuizScorePoint.fromJson(Map<String, dynamic> json)
    : label = json['label'] as String,
      percentage = (json['percentage'] as num).toDouble();

  final String label;
  final double percentage;
}

class QuizPerformanceGroup {
  QuizPerformanceGroup.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      attempts = json['attempts'] as int,
      averagePercentage = (json['averagePercentage'] as num).toDouble(),
      bestPercentage = (json['bestPercentage'] as num).toDouble(),
      lastAttemptAt = DateTime.parse(json['lastAttemptAt'] as String);

  final String name;
  final int attempts;
  final double averagePercentage;
  final double bestPercentage;
  final DateTime lastAttemptAt;
}
