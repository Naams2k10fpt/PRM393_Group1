import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/features/kahoot/kahoot_signalr_service.dart';

void main() {
  group('Kahoot Models & Parsing Tests', () {
    test('KahootQuestionModel parses valid JSON payload correctly', () {
      final map = {
        'questionIndex': 1,
        'totalQuestions': 5,
        'questionId': 101,
        'content': 'Lợi ích chính của Sound Null Safety trong Dart là gì?',
        'timeLimit': 20,
        'answers': [
          {'id': 1, 'text': 'Tăng tốc độ mạng', 'colorIndex': 0},
          {'id': 2, 'text': 'Loại bỏ hoàn toàn lỗi null pointer runtime', 'colorIndex': 1},
          {'id': 3, 'text': 'Tự động tạo layout UI', 'colorIndex': 2},
          {'id': 4, 'text': 'Tăng dung lượng file APK', 'colorIndex': 3},
        ]
      };

      final model = KahootQuestionModel.fromMap(map);
      expect(model.questionIndex, 1);
      expect(model.totalQuestions, 5);
      expect(model.questionId, 101);
      expect(model.content, contains('Sound Null Safety'));
      expect(model.timeLimit, 20);
      expect(model.answers.length, 4);
      expect(model.answers[1].id, 2);
      expect(model.answers[1].text, contains('null pointer'));
    });

    test('KahootResultModel correctly reflects score and correctness', () {
      final map = {
        'isCorrect': true,
        'scoreEarned': 950,
        'totalScore': 1950,
      };

      final result = KahootResultModel.fromMap(map);
      expect(result.isCorrect, isTrue);
      expect(result.scoreEarned, 950);
      expect(result.totalScore, 1950);
    });

    test('KahootLeaderboardItem parses rank, nickname, and scores reliably', () {
      final map = {
        'rank': 1,
        'nickname': 'ChampionPlayer',
        'score': 2850,
        'participantId': 12,
      };

      final item = KahootLeaderboardItem.fromMap(map);
      expect(item.rank, 1);
      expect(item.nickname, 'ChampionPlayer');
      expect(item.score, 2850);
      expect(item.participantId, 12);
    });

    test('KahootLeaderboardItem fallbacks to totalScore if score key is absent', () {
      final map = {
        'rank': 2,
        'nickname': 'RunnerUp',
        'totalScore': 2100,
        'participantId': 15,
      };

      final item = KahootLeaderboardItem.fromMap(map);
      expect(item.rank, 2);
      expect(item.score, 2100);
    });
  });

  group('KahootSignalRService Logic & Timing Tests', () {
    test('Default initial state is clean and unconnected', () {
      final service = KahootSignalRService();
      expect(service.isConnected, isFalse);
      expect(service.isAnswerSubmitted, isFalse);
      expect(service.isGameOver, isFalse);
      expect(service.isLeaderboardRevealed, isFalse);
      expect(service.pendingAnswerResult, isNull);
      expect(service.currentQuestion, isNull);
      expect(service.lastAnswerResult, isNull);
      expect(service.participantId, 0);
      expect(service.totalScore, 0);
      expect(service.podium, isEmpty);
      expect(service.currentLeaderboard, isEmpty);
      expect(service.questionEndedCorrectAnswerId, isNull);
      expect(service.lastErrorMessage, isNull);
      service.dispose();
    });
  });
}
