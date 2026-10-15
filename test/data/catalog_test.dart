import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/api/api_client.dart';
import 'package:quiz_management_mobile/data/api/api_exception.dart';
import 'package:quiz_management_mobile/data/api/token_storage.dart';
import 'package:quiz_management_mobile/data/models/flashcard.dart';
import 'package:quiz_management_mobile/data/models/subject.dart';
import 'package:quiz_management_mobile/data/repositories/catalog_repository.dart';
import 'package:quiz_management_mobile/data/repositories/flashcard_repository.dart';

import '../support/fake_adapter.dart';

void main() {
  late FakeAdapter adapter;
  late ApiClient api;

  setUp(() {
    adapter = FakeAdapter(200, const []);
    api = ApiClient(tokens: InMemoryTokenStorage(), dio: Dio()..httpClientAdapter = adapter);
  });

  group('Subject.fromJson', () {
    test('reads the documented field names', () {
      final subject = Subject.fromJson(const {
        'id': 7,
        'name': 'Lập trình di động',
        'description': 'PRM393',
        'deckCount': 4,
      });

      expect(subject.id, '7');
      expect(subject.name, 'Lập trình di động');
      expect(subject.deckCount, 4);
    });

    test('accepts the alternative spellings the backend may use', () {
      final subject = Subject.fromJson(const {
        'subjectId': 'a1',
        'title': 'Lập trình .NET',
        'totalDecks': '3',
      });

      expect(subject.id, 'a1');
      expect(subject.name, 'Lập trình .NET');
      expect(subject.deckCount, 3);
    });

    test('a missing description is null, not an empty string', () {
      final subject = Subject.fromJson(const {'id': 1, 'name': 'X', 'description': '  '});

      expect(subject.description, isNull);
    });
  });

  group('Flashcard.fromJson', () {
    test('reads the question shape the backend sends', () {
      final card = Flashcard.fromJson(const {
        'questionId': 100,
        'content': 'Widget là gì?',
        'questionType': 1,
        'explanation': 'Mọi thứ đều là widget.',
        'correctAnswers': ['Đơn vị dựng giao diện'],
        'options': [
          {'id': 1, 'content': 'Đơn vị dựng giao diện', 'isCorrect': true},
          {'id': 2, 'content': 'Một loại biến', 'isCorrect': false},
        ],
        'progress': {'repetition': 3, 'nextReviewAtUtc': '2026-10-20T08:00:00Z'},
      });

      expect(card.questionId, '100');
      expect(card.content, 'Widget là gì?');
      expect(card.answerText, 'Đơn vị dựng giao diện');
      expect(card.options, hasLength(2));
      expect(card.options.first.isCorrect, isTrue);
      expect(card.progress!.repetition, 3);
    });

    test('a card never reviewed has no progress', () {
      final card = Flashcard.fromJson(const {'questionId': 1, 'content': 'X', 'progress': null});

      expect(card.progress, isNull);
      expect(card.answerText, isEmpty);
    });
  });

  group('CatalogRepository', () {
    test('parses a bare array of subjects', () async {
      adapter.body = const [
        {'id': 1, 'name': 'A', 'deckCount': 2},
        {'id': 2, 'name': 'B', 'deckCount': 0},
      ];

      final subjects = await CatalogRepository(api).subjects();

      expect(subjects, hasLength(2));
      expect(subjects.first.name, 'A');
      expect(adapter.requests.single.uri.path, '/api/subjects');
    });

    test('parses the ApiPage envelope the backend actually returns', () async {
      adapter.body = const {
        'items': [
          {'id': 1, 'name': 'Lập trình di động', 'ownerName': 'Giảng viên', 'deckCount': 2, 'questionCount': 12},
        ],
        'page': 1,
        'pageSize': 20,
        'totalCount': 1,
      };

      final subjects = await CatalogRepository(api).subjects();

      expect(subjects, hasLength(1));
      expect(subjects.single.deckCount, 2);
      expect(subjects.single.questionCount, 12);
    });

    test('a deck keeps the user progress counters', () async {
      adapter.body = const {
        'items': [
          {
            'id': 10,
            'subjectId': 1,
            'subjectName': 'Lập trình di động',
            'name': 'Flutter cơ bản',
            'timeLimitMinutes': 15,
            'questionCount': 20,
            'dueCount': 6,
            'learnedCount': 14,
            'nextReviewAtUtc': '2026-10-20T08:00:00Z',
          },
        ],
      };

      final decks = await CatalogRepository(api).decksOfSubject('1');

      expect(adapter.requests.single.uri.path, '/api/subjects/1/decks');
      // `name` on the wire, `title` in the app.
      expect(decks.single.title, 'Flutter cơ bản');
      expect(decks.single.cardCount, 20);
      expect(decks.single.dueCount, 6);
      expect(decks.single.learnedCount, 14);
    });

    test('an unexpected body yields an empty list instead of throwing', () async {
      adapter.body = const {'unexpected': true};

      expect(await CatalogRepository(api).subjects(), isEmpty);
    });

    test('a backend error surfaces as ApiException', () async {
      adapter
        ..status = 404
        ..body = {'code': 'deck_not_found', 'message': 'Không tìm thấy bộ đề.'};

      await expectLater(
        CatalogRepository(api).deck('99'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'deck_not_found')),
      );
    });
  });

  group('FlashcardRepository', () {
    test('a session asks for due cards and reads them from `cards`', () async {
      adapter.body = const {
        'deckId': 10,
        'deckName': 'Flutter cơ bản',
        'subjectName': 'Lập trình di động',
        'totalCards': 20,
        'dueCards': 2,
        'studyingAll': false,
        'cards': [
          {'questionId': 100, 'content': 'A', 'correctAnswers': ['a']},
          {'questionId': 101, 'content': 'B', 'correctAnswers': ['b']},
        ],
      };

      final session = await FlashcardRepository(api).session('10');

      final request = adapter.requests.single;
      expect(request.uri.path, '/api/decks/10/flashcards');
      expect(request.uri.queryParameters['mode'], 'due');
      expect(session.totalCards, 20);
      expect(session.cards, hasLength(2));
      expect(session.cards.first.content, 'A');
    });

    test('studyAll switches the mode', () async {
      adapter.body = const {'deckId': 10, 'deckName': 'X', 'cards': []};

      await FlashcardRepository(api).session('10', studyAll: true);

      expect(adapter.requests.single.uri.queryParameters['mode'], 'all');
    });

    test('a review sends one card, with numeric ids', () async {
      adapter.body = const {
        'questionId': 100,
        'repetition': 2,
        'intervalMinutes': 600,
        'nextReviewAtUtc': '2026-10-20T08:00:00Z',
      };

      final result = await FlashcardRepository(api)
          .review(deckId: '10', questionId: '100', remembered: true);

      final request = adapter.requests.single;
      final sent = jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>;
      expect(request.uri.path, '/api/flashcards/progress');
      expect(sent, {'deckId': 10, 'questionId': 100, 'remembered': true});
      expect(result.repetition, 2);
      expect(result.intervalMinutes, 600);
    });
  });
}
