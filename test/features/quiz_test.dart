import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/tv3_fakes.dart';
import 'package:quiz_management_mobile/data/repositories/quiz_repository.dart';

Future<void> openQuiz(WidgetTester tester, FakeQuizRepository repo) async {
  await TestApp(token: 'token', quiz: repo).start(tester);
  await tester.tap(find.text('Quiz cá nhân'));
  await tester.pumpAndSettle();
}

Future<void> chooseDeck(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<int>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Môn TV3').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<int>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ôn tập TV3 · 2 câu').last);
  await tester.pumpAndSettle();
}

Future<void> startQuiz(WidgetTester tester, FakeQuizRepository repo) async {
  await openQuiz(tester, repo);
  await chooseDeck(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Bắt đầu'));
  await tester.pumpAndSettle();
}

String savedDraft() => jsonEncode({
  'attemptId': quizAttempt().id,
  'deckId': 7,
  'answers': {
    '21': [210],
  },
});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'result shows pass status, can retry and submits reports with history context',
    (tester) async {
      final repo = FakeQuizRepository()..reportError = offline;
      await openQuiz(tester, repo);
      await tester.tap(find.text('Bài đã làm 1'));
      await tester.pumpAndSettle();
      expect(find.text('Đạt'), findsOneWidget);
      await tester.ensureVisible(find.text('Báo cáo câu hỏi').first);
      await tester.tap(find.text('Báo cáo câu hỏi').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Kiểm tra lại đáp án');
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();
      expect(find.text(offline.message), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Kiểm tra lại đáp án',
      );
      repo.reportError = null;
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();
      expect(
        repo.calls,
        contains('report:1:21:WrongAnswer:Kiểm tra lại đáp án'),
      );
      await tester.ensureVisible(find.text('Làm lại bài quiz'));
      await tester.tap(find.text('Làm lại bài quiz'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('start:7:2'));
      expect(find.text('Làm bài'), findsOneWidget);
    },
  );

  testWidgets('quiz entry coexists with subjects and history opens a result', (
    tester,
  ) async {
    final repo = FakeQuizRepository();
    await openQuiz(tester, repo);
    await tester.tap(find.text('Bài đã làm 1'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('result:1'));
    expect(find.textContaining('5.0/10 điểm'), findsOneWidget);
    expect(find.text('Đúng'), findsOneWidget);
    expect(find.text('Sai'), findsOneWidget);
    await tester.tap(find.text('Về danh sách'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xem thêm'));
    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'history:2'), hasLength(1));
    expect(find.text('Bài đã làm 2'), findsOneWidget);
  });

  testWidgets(
    'single/multiple answers, question navigation and submit persist correctly',
    (tester) async {
      final repo = FakeQuizRepository();
      await startQuiz(tester, repo);
      await tester.tap(find.text('A. Đáp án A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B. Đáp án B'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A. Đáp án A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B. Đáp án B'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài').last);
      await tester.pumpAndSettle();
      expect(repo.submissions.single, {
        21: {211},
        22: {220, 221},
      });
      expect(
        (await SharedPreferences.getInstance()).getString('quiz_draft_u1'),
        isNull,
      );
      expect(find.textContaining('5.0/10 điểm'), findsOneWidget);
    },
  );

  testWidgets(
    'unanswered submission requires confirmation and cannot be sent twice in flight',
    (tester) async {
      final repo =
          FakeQuizRepository()..pendingSubmit = Completer<QuizResult>();
      await startQuiz(tester, repo);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.pumpAndSettle();
      expect(find.text('Còn 2 câu chưa trả lời. Vẫn nộp bài?'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục làm'));
      await tester.pumpAndSettle();
      expect(repo.submissions, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài').last);
      await tester.pumpAndSettle();
      expect(repo.submissions, hasLength(1));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Đang nộp...'),
            )
            .onPressed,
        isNull,
      );
      repo.pendingSubmit!.complete(quizResult());
      await tester.pumpAndSettle();
      expect(find.textContaining('5.0/10 điểm'), findsOneWidget);
    },
  );

  testWidgets(
    'saved attempt restores answers and network failures keep the draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({'quiz_draft_u1': savedDraft()});
      final repo = FakeQuizRepository()..submitError = offline;
      await openQuiz(tester, repo);
      expect(repo.calls, contains('resume:${repo.current.id}:7'));
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isTrue,
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài').last);
      await tester.pumpAndSettle();
      expect(find.text(offline.message), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString('quiz_draft_u1'),
        isNotNull,
      );
    },
  );

  testWidgets(
    'cannot overwrite a draft when resuming is temporarily unavailable',
    (tester) async {
      SharedPreferences.setMockInitialValues({'quiz_draft_u1': savedDraft()});
      final repo = FakeQuizRepository()..resumeError = offline;
      await openQuiz(tester, repo);
      await chooseDeck(tester);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Bắt đầu'))
            .onPressed,
        isNull,
      );
      expect(
        (await SharedPreferences.getInstance()).getString('quiz_draft_u1'),
        savedDraft(),
      );
      repo.resumeError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Câu 1/2:'), findsOneWidget);
    },
  );

  testWidgets(
    'expired timer submits once, locks answers and permits retry after a network failure',
    (tester) async {
      final repo =
          FakeQuizRepository()
            ..current = quizAttempt(
              expiresAt: DateTime.now().toUtc().subtract(
                const Duration(seconds: 1),
              ),
            )
            ..submitError = offline;
      await startQuiz(tester, repo);
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .onChanged,
        isNull,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.submissions, hasLength(1));
      await tester.pump(const Duration(seconds: 3));
      expect(repo.submissions, hasLength(1));
      repo.submitError = null;
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài').last);
      await tester.pumpAndSettle();
      expect(repo.submissions, hasLength(2));
      expect(find.textContaining('5.0/10 điểm'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString('quiz_draft_u1'),
        isNull,
      );
    },
  );
}
