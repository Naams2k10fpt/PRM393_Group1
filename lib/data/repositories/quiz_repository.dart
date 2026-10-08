import '../api/api_client.dart';

class QuizRepository {
  QuizRepository(this.api);

  final ApiClient api;

  Future<List<QuizSubject>> subjects() async {
    final data =
        await api.get('/api/subjects', query: {'pageSize': 100})
            as Map<String, dynamic>;
    return (data['items'] as List)
        .map((e) => QuizSubject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<QuizDeck>> decks(int subjectId) async =>
      (await api.get('/api/subjects/$subjectId/decks') as List)
          .map((e) => QuizDeck.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<QuizAttempt> start(int deckId, int count) async =>
      QuizAttempt.fromJson(
        await api.post(
              '/api/quiz/start',
              data: {'deckId': deckId, 'questionCount': count},
            )
            as Map<String, dynamic>,
      );

  Future<QuizAttempt> resume(String attemptId, int deckId) async =>
      QuizAttempt.fromJson(
        await api.get(
              '/api/quiz/attempts/$attemptId',
              query: {'deckId': deckId},
            )
            as Map<String, dynamic>,
      );

  Future<QuizResult> submit(
    QuizAttempt attempt,
    Map<int, Set<int>> selected,
  ) async => QuizResult.fromJson(
    await api.post(
          '/api/quiz/submit',
          data: {
            'attemptId': attempt.id,
            'deckId': attempt.deckId,
            'answers':
                attempt.questions
                    .map(
                      (q) => {
                        'questionId': q.id,
                        'selectedAnswerIds':
                            selected[q.id]?.toList() ?? <int>[],
                      },
                    )
                    .toList(),
          },
        )
        as Map<String, dynamic>,
  );

  Future<QuizHistoryPage> history(int page) async => QuizHistoryPage.fromJson(
    await api.get('/api/history/user', query: {'page': page})
        as Map<String, dynamic>,
  );

  Future<QuizResult> result(int id) async => QuizResult.fromJson(
    await api.get('/api/history/$id') as Map<String, dynamic>,
  );
}

class QuizSubject {
  QuizSubject.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String;
  final int id;
  final String name;
}

class QuizDeck {
  QuizDeck.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String,
      questionCount = json['questionCount'] as int,
      timeLimitMinutes = json['timeLimitMinutes'] as int?;
  final int id;
  final String name;
  final int questionCount;
  final int? timeLimitMinutes;
}

class QuizAttempt {
  QuizAttempt.fromJson(Map<String, dynamic> json)
    : id = json['attemptId'] as String,
      deckId = json['deckId'] as int,
      deckName = json['deckName'] as String,
      expiresAt =
          DateTime.tryParse(json['expiresAtUtc'] as String? ?? '')?.toUtc(),
      questions =
          (json['questions'] as List)
              .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
              .toList();
  final String id;
  final int deckId;
  final String deckName;
  final DateTime? expiresAt;
  final List<QuizQuestion> questions;
}

class QuizQuestion {
  QuizQuestion.fromJson(Map<String, dynamic> json)
    : id = json['questionId'] as int,
      content = json['content'] as String,
      multiple = json['questionType'] == 2,
      answers =
          (json['answers'] as List)
              .map((e) => QuizAnswer.fromJson(e as Map<String, dynamic>))
              .toList();
  final int id;
  final String content;
  final bool multiple;
  final List<QuizAnswer> answers;
}

class QuizAnswer {
  QuizAnswer.fromJson(Map<String, dynamic> json)
    : id = json['answerId'] as int,
      content = json['content'] as String;
  final int id;
  final String content;
}

class QuizHistoryPage {
  QuizHistoryPage.fromJson(Map<String, dynamic> json)
    : totalCount = json['totalCount'] as int,
      pageSize = json['pageSize'] as int,
      items =
          (json['items'] as List)
              .map((e) => QuizHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList();
  final int totalCount;
  final int pageSize;
  final List<QuizHistoryItem> items;
}

class QuizHistoryItem {
  QuizHistoryItem.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      deckName = json['deckName'] as String,
      subjectName = json['subjectName'] as String,
      percentage = (json['percentage'] as num).toDouble(),
      createdAt = DateTime.parse(json['createdAt'] as String);
  final int id;
  final String deckName;
  final String subjectName;
  final double percentage;
  final DateTime createdAt;
}

class QuizResult {
  QuizResult.fromJson(Map<String, dynamic> json)
    : deckName = json['deckName'] as String,
      subjectName = json['subjectName'] as String,
      score = (json['score'] as num).toDouble(),
      percentage = (json['percentage'] as num).toDouble(),
      correctCount = json['correctCount'] as int,
      totalCount = json['totalCount'] as int,
      questions =
          (json['questions'] as List)
              .map(
                (e) => QuizResultQuestion.fromJson(e as Map<String, dynamic>),
              )
              .toList();
  final String deckName;
  final String subjectName;
  final double score;
  final double percentage;
  final int correctCount;
  final int totalCount;
  final List<QuizResultQuestion> questions;
}

class QuizResultQuestion {
  QuizResultQuestion.fromJson(Map<String, dynamic> json)
    : content = json['content'] as String,
      explanation = json['explanation'] as String?,
      isCorrect = json['isCorrect'] as bool,
      answers =
          (json['answers'] as List)
              .map((e) => QuizResultAnswer.fromJson(e as Map<String, dynamic>))
              .toList();
  final String content;
  final String? explanation;
  final bool isCorrect;
  final List<QuizResultAnswer> answers;
}

class QuizResultAnswer {
  QuizResultAnswer.fromJson(Map<String, dynamic> json)
    : content = json['content'] as String,
      isCorrect = json['isCorrectAnswer'] as bool,
      wasSelected = json['wasSelected'] as bool;
  final String content;
  final bool isCorrect;
  final bool wasSelected;
}
