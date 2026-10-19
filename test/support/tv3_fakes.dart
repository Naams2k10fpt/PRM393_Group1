import 'dart:async';

import 'package:quiz_management_mobile/data/api/api_client.dart';
import 'package:quiz_management_mobile/data/api/api_exception.dart';
import 'package:quiz_management_mobile/data/api/token_storage.dart';
import 'package:quiz_management_mobile/data/realtime/chat_connection.dart';
import 'package:quiz_management_mobile/data/repositories/groups_repository.dart';
import 'package:quiz_management_mobile/data/repositories/quiz_repository.dart';

QuizAttempt quizAttempt({DateTime? expiresAt}) => QuizAttempt.fromJson({
  'attemptId': '11111111-1111-1111-1111-111111111111',
  'deckId': 7,
  'deckName': 'Ôn tập TV3',
  'expiresAtUtc': expiresAt?.toIso8601String(),
  'questions': [
    for (final id in [21, 22])
      {
        'questionId': id,
        'content': 'Nội dung $id',
        'questionType': id == 21 ? 1 : 2,
        'answers': [
          {'answerId': id * 10, 'content': 'Đáp án A'},
          {'answerId': id * 10 + 1, 'content': 'Đáp án B'},
        ],
      },
  ],
});

QuizResult quizResult() => QuizResult.fromJson({
  'deckName': 'Ôn tập TV3',
  'subjectName': 'Môn TV3',
  'score': 5,
  'percentage': 50,
  'correctCount': 1,
  'totalCount': 2,
  'questions': [
    {
      'content': 'Nội dung 21',
      'explanation': 'Giải thích mẫu',
      'isCorrect': true,
      'answers': [
        {'content': 'Đáp án A', 'isCorrectAnswer': true, 'wasSelected': true},
        {'content': 'Đáp án B', 'isCorrectAnswer': false, 'wasSelected': false},
      ],
    },
    {
      'content': 'Nội dung 22',
      'explanation': null,
      'isCorrect': false,
      'answers': [
        {'content': 'Đáp án A', 'isCorrectAnswer': true, 'wasSelected': false},
        {'content': 'Đáp án B', 'isCorrectAnswer': false, 'wasSelected': true},
      ],
    },
  ],
});

class FakeQuizRepository extends QuizRepository {
  FakeQuizRepository() : super(ApiClient(tokens: InMemoryTokenStorage()));

  QuizAttempt current = quizAttempt();
  ApiException? resumeError;
  ApiException? submitError;
  Completer<QuizResult>? pendingSubmit;
  final submissions = <Map<int, Set<int>>>[];
  final calls = <String>[];

  @override
  Future<List<QuizSubject>> subjects() async => [
    QuizSubject.fromJson({'id': 1, 'name': 'Môn TV3'}),
  ];

  @override
  Future<List<QuizDeck>> decks(int subjectId) async => [
    QuizDeck.fromJson({
      'id': 7,
      'name': 'Ôn tập TV3',
      'questionCount': 2,
      'timeLimitMinutes': 1,
    }),
  ];

  @override
  Future<QuizAttempt> start(int deckId, int count) async {
    calls.add('start:$deckId:$count');
    return current;
  }

  @override
  Future<QuizAttempt> resume(String attemptId, int deckId) async {
    calls.add('resume:$attemptId:$deckId');
    if (resumeError != null) throw resumeError!;
    return current;
  }

  @override
  Future<QuizResult> submit(
    QuizAttempt attempt,
    Map<int, Set<int>> selected,
  ) async {
    submissions.add(
      selected.map((key, value) => MapEntry(key, Set<int>.of(value))),
    );
    if (submitError != null) throw submitError!;
    return pendingSubmit != null ? pendingSubmit!.future : quizResult();
  }

  @override
  Future<QuizHistoryPage> history(int page) async {
    calls.add('history:$page');
    return QuizHistoryPage.fromJson({
      'totalCount': 2,
      'pageSize': 1,
      'items': [
        {
          'id': page,
          'deckName': 'Bài đã làm $page',
          'subjectName': 'Môn TV3',
          'percentage': 50,
          'createdAt': '2026-10-19T01:00:00Z',
        },
      ],
    });
  }

  @override
  Future<QuizResult> result(int id) async {
    calls.add('result:$id');
    return quizResult();
  }
}

StudyGroup studyGroup({int id = 1, bool member = true, bool pending = false}) =>
    StudyGroup.fromJson({
      'id': id,
      'name': member ? 'Nhóm TV3' : 'Nhóm cần duyệt',
      'description': 'Ôn tập cùng nhau',
      'subjectName': 'Môn TV3',
      'unreadCount': 3,
      'memberCount': 2,
      'isMember': member,
      'hasPendingRequest': pending,
      'accessMode': member ? 0 : 1,
    });

ChatMessage chatMessage(
  int id, {
  String sender = 'u2',
  String? content,
  String? name,
  int kind = 0,
}) => ChatMessage.fromJson({
  'id': id,
  'groupId': 1,
  'senderUserId': sender,
  'senderName': name ?? 'Bạn học',
  'senderAvatarUrl': null,
  'content': content ?? 'Tin nhắn $id',
  'sentAt': '2026-10-19T01:00:00Z',
  'kind': kind,
});

class FakeChatConnection extends ChatConnection {
  ApiException? connectError;
  Completer<void>? pendingConnect;
  Completer<ChatMessage?>? pendingSend;
  int connectCount = 0;
  int closeCount = 0;
  final sent = <String>[];

  @override
  Future<void> connect() async {
    connectCount++;
    if (connectError != null) throw connectError!;
    if (pendingConnect != null) await pendingConnect!.future;
  }

  @override
  Future<ChatMessage?> send(String content) async {
    sent.add(content);
    return pendingSend != null
        ? pendingSend!.future
        : chatMessage(100, sender: 'u1', content: content);
  }

  @override
  Future<void> close() async {
    closeCount++;
    onMessage = null;
    onReconnected = null;
    onDisconnected = null;
    onAccessRevoked = null;
    onError = null;
  }
}

class FakeGroupsRepository extends GroupsRepository {
  FakeGroupsRepository() : super(ApiClient(tokens: InMemoryTokenStorage()));

  final connection = FakeChatConnection();
  ApiException? loadError;
  bool pending = false;
  List<ChatMessage> latest = [chatMessage(1)];
  List<ChatMessage> older = [];
  final calls = <String>[];

  @override
  ChatConnection openChat(int groupId) => connection;

  @override
  Future<List<StudyGroup>> mine() async {
    if (loadError != null) throw loadError!;
    return [studyGroup()];
  }

  @override
  Future<List<StudyGroup>> discover() async => [
    studyGroup(id: 2, member: false, pending: pending),
  ];

  @override
  Future<void> create(String name, String description, int accessMode) async {
    calls.add('create:$name:$description:$accessMode');
  }

  @override
  Future<void> join(int id) async {
    calls.add('join:$id');
    pending = true;
  }

  @override
  Future<void> cancelJoinRequest(int id) async {
    calls.add('cancel:$id');
    pending = false;
  }

  @override
  Future<List<ChatMessage>> messages(int id, {int? beforeId}) async {
    calls.add('messages:$id:$beforeId');
    return beforeId == null ? latest : older;
  }

  @override
  Future<void> markRead(int id, int messageId) async {
    calls.add('read:$id:$messageId');
  }
}
