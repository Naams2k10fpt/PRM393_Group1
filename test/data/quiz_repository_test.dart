import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/api/api_client.dart';
import 'package:quiz_management_mobile/data/api/token_storage.dart';
import 'package:quiz_management_mobile/data/repositories/quiz_repository.dart';

class RecordingApi extends ApiClient {
  RecordingApi() : super(tokens: InMemoryTokenStorage());

  String? path;
  Object? body;

  @override
  Future<dynamic> post(String path, {Object? data, bool auth = true}) async {
    this.path = path;
    body = data;
    return {
      'deckName': 'Toán',
      'subjectName': 'Lớp 10',
      'score': 5,
      'percentage': 50,
      'correctCount': 1,
      'totalCount': 2,
      'questions': [],
    };
  }
}

void main() {
  test(
    'submits selected and unanswered questions with the backend contract',
    () async {
      final api = RecordingApi();
      final attempt = QuizAttempt.fromJson({
        'attemptId': '11111111-1111-1111-1111-111111111111',
        'deckId': 7,
        'deckName': 'Toán',
        'expiresAtUtc': null,
        'questions': [
          {
            'questionId': 21,
            'content': 'Một đáp án',
            'questionType': 1,
            'answers': [
              {'answerId': 84, 'content': 'A'},
            ],
          },
          {
            'questionId': 22,
            'content': 'Nhiều đáp án',
            'questionType': 2,
            'answers': [
              {'answerId': 89, 'content': 'B'},
              {'answerId': 90, 'content': 'C'},
            ],
          },
        ],
      });

      final result = await QuizRepository(api).submit(attempt, {
        21: {84},
      });

      expect(api.path, '/api/quiz/submit');
      expect(api.body, {
        'attemptId': attempt.id,
        'deckId': 7,
        'answers': [
          {
            'questionId': 21,
            'selectedAnswerIds': [84],
          },
          {'questionId': 22, 'selectedAnswerIds': <int>[]},
        ],
      });
      expect(result.percentage, 50);
    },
  );
}
