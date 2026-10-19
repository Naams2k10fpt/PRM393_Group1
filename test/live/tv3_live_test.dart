// Mutates only an explicitly enabled, isolated local demo database.
// LIVE_API_BASE_URL=http://127.0.0.1:5049 TV3_LIVE_MUTATIONS=1 flutter test test/live/tv3_live_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/core/config/app_config.dart';
import 'package:quiz_management_mobile/data/api/api_client.dart';
import 'package:quiz_management_mobile/data/api/token_storage.dart';
import 'package:quiz_management_mobile/data/realtime/chat_connection.dart';
import 'package:quiz_management_mobile/data/repositories/auth_repository.dart';
import 'package:quiz_management_mobile/data/repositories/groups_repository.dart';
import 'package:quiz_management_mobile/data/repositories/quiz_repository.dart';

void main() {
  final baseUrl = Platform.environment['LIVE_API_BASE_URL'];
  final uri = Uri.tryParse(baseUrl ?? '');
  final enabled =
      Platform.environment['TV3_LIVE_MUTATIONS'] == '1' &&
      uri != null &&
      ['localhost', '127.0.0.1', '::1'].contains(uri.host);
  final skip =
      enabled
          ? false
          : 'Requires an isolated localhost backend and TV3_LIVE_MUTATIONS=1';

  Future<ApiClient> signIn(String email) async {
    AppConfig.baseUrl = baseUrl!;
    final tokens = InMemoryTokenStorage();
    final api = ApiClient(tokens: tokens);
    await AuthRepository(api, tokens).login(email, 'Test@123456');
    addTearDown(() => api.dio.close(force: true));
    return api;
  }

  test(
    'real quiz start/resume/submit/history use the mobile contract and repeat submit is idempotent',
    () async {
      final api = await signIn('user.demo@quiz.local');
      final quiz = QuizRepository(api);
      final subjects = await quiz.subjects();
      expect(subjects, isNotEmpty);
      final decks = await quiz.decks(subjects.first.id);
      final deck = decks.firstWhere((item) => item.questionCount >= 2);
      final before = await quiz.history(1);
      final attempt = await quiz.start(deck.id, 2);
      final resumed = await quiz.resume(attempt.id, deck.id);
      expect(
        resumed.questions.map((q) => q.id),
        attempt.questions.map((q) => q.id),
      );
      final selected = {
        for (final question in attempt.questions)
          question.id: {question.answers.first.id},
      };
      final result = await quiz.submit(attempt, selected);
      expect(result.totalCount, 2);
      expect(result.questions, hasLength(2));
      expect(
        result.questions.first.answers.where((answer) => answer.wasSelected),
        hasLength(1),
      );
      final repeated = await quiz.submit(attempt, selected);
      expect(repeated.score, result.score);
      final history = await quiz.history(1);
      expect(history.totalCount, before.totalCount + 1);
      final detail = await quiz.result(history.items.first.id);
      expect(detail.score, result.score);
      expect(detail.questions.first.content, result.questions.first.content);
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'two real SignalR clients exchange a message, persist history and clear unread',
    () async {
      final authorApi = await signIn('user.demo@quiz.local');
      final readerApi = await signIn('mentor.demo@quiz.local');
      final author = GroupsRepository(authorApi);
      final reader = GroupsRepository(readerApi);
      final name = 'TV3 verification ${DateTime.now().microsecondsSinceEpoch}';
      await author.create(name, 'Isolated local verification', 0);
      final group = (await author.mine()).singleWhere(
        (item) => item.name == name,
      );
      await reader.join(group.id);
      final authorConnection = author.openChat(group.id);
      final readerConnection = reader.openChat(group.id);
      final connections = <ChatConnection>[authorConnection, readerConnection];
      addTearDown(() async {
        for (final connection in connections) {
          await connection.close();
        }
      });
      final received = Completer<ChatMessage>();
      readerConnection.onMessage = (message) {
        if (message.content == 'Tin nhắn kiểm thử TV3' && !received.isCompleted) {
          received.complete(message);
        }
      };
      await authorConnection.connect();
      await readerConnection.connect();
      final sent = await authorConnection.send('Tin nhắn kiểm thử TV3');
      final delivered = await received.future.timeout(
        const Duration(seconds: 10),
      );
      expect(delivered.id, sent!.id);
      expect(delivered.groupId, group.id);
      expect(
        (await reader.mine())
            .singleWhere((item) => item.id == group.id)
            .unreadCount,
        1,
      );
      await reader.markRead(group.id, delivered.id);
      expect(
        (await reader.mine())
            .singleWhere((item) => item.id == group.id)
            .unreadCount,
        0,
      );
      await readerConnection.close();
      connections.remove(readerConnection);
      final reopened = reader.openChat(group.id);
      connections.add(reopened);
      await reopened.connect();
      expect(
        (await reader.messages(
          group.id,
        )).where((message) => message.id == sent.id),
        hasLength(1),
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
