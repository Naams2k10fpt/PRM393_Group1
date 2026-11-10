import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/models/flashcard.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

/// Home -> subject -> deck -> study, the way a user gets there.
Future<void> openStudyScreen(WidgetTester tester, TestApp app) async {
  await app.start(tester);
  await tester.tap(find.text('Lập trình di động'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Flutter cơ bản'));
  await tester.pumpAndSettle();
}

Finder visibleFaceText(String text) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is Visibility && widget.visible,
  ),
  matching: find.text(text),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'each choice flips independently while the question stays in place',
    (tester) async {
      final app = TestApp(token: 'token');

      await openStudyScreen(tester, app);

      final question = find.text('Widget trong Flutter là gì?');
      final questionPosition = tester.getTopLeft(question);
      expect(find.text('1/2'), findsOneWidget);
      expect(visibleFaceText('A. Đơn vị dựng giao diện'), findsOneWidget);
      expect(visibleFaceText('B. Một loại biến'), findsOneWidget);
      expect(visibleFaceText('Đáp án đúng'), findsNothing);
      expect(visibleFaceText('Lựa chọn sai'), findsNothing);

      await tester.tapAt(tester.getCenter(visibleFaceText('B. Một loại biến')));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(question), questionPosition);
      expect(visibleFaceText('Lựa chọn sai'), findsOneWidget);
      expect(visibleFaceText('Đáp án đúng'), findsNothing);
      expect(find.text('Giải thích'), findsNothing);
      expect(app.flashcardRepository.reviews, isEmpty);

      await tester.tapAt(
        tester.getCenter(visibleFaceText('A. Đơn vị dựng giao diện')),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(visibleFaceText('C. Thành phần tái sử dụng')),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(question), questionPosition);
      expect(visibleFaceText('Đáp án đúng'), findsNWidgets(2));
      expect(visibleFaceText('Lựa chọn sai'), findsOneWidget);
      expect(find.text('Mọi thứ hiển thị đều là widget.'), findsOneWidget);
    },
  );

  testWidgets(
    'a card without choices reveals its fallback answer on a small phone',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final flashcards = FakeFlashcardRepository(cards: [demoFlashcards.last]);
      await openStudyScreen(
        tester,
        TestApp(token: 'token', flashcards: flashcards),
      );
      await tester.binding.setSurfaceSize(const Size(320, 480));
      await tester.pumpAndSettle();

      expect(
        visibleFaceText('Nạp lại code mà không mất trạng thái'),
        findsNothing,
      );
      await tester.tapAt(tester.getCenter(visibleFaceText('Xem đáp án')));
      await tester.pumpAndSettle();

      expect(find.text('Hot reload làm gì?'), findsOneWidget);
      expect(
        visibleFaceText('Nạp lại code mà không mất trạng thái'),
        findsOneWidget,
      );
      expect(find.text('Đã thuộc').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Đã thuộc'));
      await tester.pumpAndSettle();
      expect(find.text('Hoàn thành!'), findsOneWidget);
    },
  );

  testWidgets('recall buttons stay visible across phone and tablet sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openStudyScreen(tester, TestApp(token: 'token'));
    for (final size in const [
      Size(320, 568),
      Size(390, 780),
      Size(768, 1024),
      Size(844, 390),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      final known = find.widgetWithText(FilledButton, 'Đã thuộc');
      final missed = find.widgetWithText(OutlinedButton, 'Chưa thuộc');
      expect(known.hitTestable(), findsOneWidget, reason: '$size');
      expect(missed.hitTestable(), findsOneWidget, reason: '$size');
      final bottom = tester.getBottomLeft(known).dy;
      expect(bottom, lessThanOrEqualTo(size.height), reason: '$size');
      await tester.drag(find.byType(ListView).last, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(known).dy, bottom, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('the session is loaded in due mode', (tester) async {
    final app = TestApp(token: 'token');

    await openStudyScreen(tester, app);

    expect(app.flashcardRepository.calls, contains('session:10:due'));
  });

  testWidgets('each answer is sent as its own review', (tester) async {
    final app = TestApp(token: 'token');
    await openStudyScreen(tester, app);

    await tester.tap(find.text('Đã thuộc'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    expect(
      find.text('Đã học 1/2  ·  Đã thuộc 1  ·  Chưa thuộc 0'),
      findsOneWidget,
    );

    await tester.tap(find.text('Chưa thuộc'));
    await tester.pumpAndSettle();

    expect(find.text('Hoàn thành!'), findsOneWidget);
    expect(find.text('Bạn đã học hết 2 thẻ.'), findsOneWidget);
    expect(find.text('Tỷ lệ tự đánh giá đã thuộc 50%'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Ôn câu chưa thuộc'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Học thẻ đến hạn'),
      findsOneWidget,
    );
    expect(
      app.flashcardRepository.reviews,
      [
        (questionId: '100', remembered: true),
        (questionId: '101', remembered: false),
      ],
      reason: 'the backend schedules each card on its own, so one request per answer',
    );
    final backButton = find.widgetWithText(TextButton, 'Về danh sách bộ đề');
    await tester.scrollUntilVisible(backButton, 100);
    await tester.tap(backButton);
    await tester.pumpAndSettle();
    expect(find.text('Hoàn thành!'), findsNothing);
    expect(find.text('Flutter cơ bản'), findsOneWidget);
  });

  testWidgets('missed study loads saved reviews even before they are due', (
    tester,
  ) async {
    final flashcards = FakeFlashcardRepository();
    await openStudyScreen(
      tester,
      TestApp(token: 'token', flashcards: flashcards),
    );
    await tester.tap(find.text('Đã thuộc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa thuộc'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Học thẻ đến hạn'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã ôn hết thẻ đến hạn hôm nay.'), findsOneWidget);

    flashcards.cards = [
      ...demoFlashcards,
      const Flashcard(questionId: '102', content: 'Một câu mới'),
    ];
    await tester.tap(find.text('Ôn câu chưa thuộc'));
    await tester.pumpAndSettle();
    expect(flashcards.calls.last, 'session:10:all');
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Hot reload làm gì?'), findsOneWidget);

    await tester.tap(find.text('Đã thuộc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Học thẻ đến hạn'));
    await tester.pumpAndSettle();
    expect(find.text('Một câu mới'), findsOneWidget);

    await tester.tap(find.byTooltip('Ôn câu chưa thuộc'));
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa có câu nào được đánh dấu chưa thuộc.'),
      findsOneWidget,
    );
  });

  testWidgets('a review that fails is queued and can be sent again', (
    tester,
  ) async {
    final gate = Completer<void>();
    final flashcards = FakeFlashcardRepository()
      ..reviewGate = gate.future
      ..reviewError = offline;
    final app = TestApp(token: 'token', flashcards: flashcards);
    await openStudyScreen(tester, app);

    await tester.tap(find.text('Đã thuộc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã thuộc'));
    await tester.pumpAndSettle();

    expect(find.text('Đang lưu tiến độ...'), findsOneWidget);
    await tester.tap(find.text('Ôn câu chưa thuộc'));
    await tester.pumpAndSettle();
    expect(flashcards.calls, isNot(contains('session:10:all')));

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('2 thẻ chưa lưu được'), findsOneWidget);
    expect(flashcards.reviews, isEmpty);
    await tester.tap(find.text('Ôn câu chưa thuộc'));
    await tester.pumpAndSettle();
    expect(flashcards.calls, isNot(contains('session:10:all')));

    flashcards.reviewError = null;
    await tester.tap(find.text('Gửi lại'));
    await tester.pumpAndSettle();

    expect(find.textContaining('chưa lưu được'), findsNothing);
    expect(flashcards.reviews, hasLength(2));
  });

  testWidgets('closing and reopening sends the same queued review', (
    tester,
  ) async {
    final flashcards = FakeFlashcardRepository()..reviewError = offline;
    await openStudyScreen(
      tester,
      TestApp(token: 'token', flashcards: flashcards),
    );

    await tester.tap(find.text('Chưa thuộc'));
    await tester.pumpAndSettle();
    final queuedId = flashcards.reviewIds.single;
    expect(queuedId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(flashcards.reviews, isEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();
    flashcards.reviewError = null;
    await tester.tap(find.text('Flutter cơ bản'));
    await tester.pumpAndSettle();

    expect(flashcards.reviewIds, [queuedId, queuedId]);
    expect(flashcards.reviews.single.remembered, isFalse);
    expect(find.textContaining('chưa lưu được'), findsNothing);
  });

  testWidgets('a long swipe right marks the card as remembered', (
    tester,
  ) async {
    final app = TestApp(token: 'token');
    await openStudyScreen(tester, app);

    await tester.drag(
      find.text('Widget trong Flutter là gì?'),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(app.flashcardRepository.reviews.single.remembered, isTrue);
  });

  testWidgets('a short flick springs back and marks nothing', (tester) async {
    final app = TestApp(token: 'token');
    await openStudyScreen(tester, app);

    // Dismissible would have taken this as a fling and marked the card; the
    // swipe has to cross the distance threshold to count.
    await tester.fling(
      find.text('Widget trong Flutter là gì?'),
      const Offset(24, 0),
      2000,
    );
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(app.flashcardRepository.reviews, isEmpty);
  });

  testWidgets(
    'drag feedback follows the direction and marks only after release',
    (tester) async {
      final app = TestApp(token: 'token');
      await openStudyScreen(tester, app);
      final question = find.text('Widget trong Flutter là gì?');
      final originalPosition = tester.getCenter(question);
      final drag = await tester.startGesture(originalPosition);

      await drag.moveBy(const Offset(132, 0));
      await tester.pump();
      expect(
        tester.getCenter(question).dx,
        greaterThan(originalPosition.dx + 100),
      );
      expect(find.text('Đã thuộc'), findsNWidgets(2));
      expect(find.text('Thả để đánh dấu'), findsOneWidget);
      expect(app.flashcardRepository.reviews, isEmpty);

      await drag.moveBy(const Offset(-264, 0));
      await tester.pump();
      expect(
        tester.getCenter(question).dx,
        lessThan(originalPosition.dx - 100),
      );
      expect(find.text('Chưa thuộc'), findsNWidgets(2));
      expect(app.flashcardRepository.reviews, isEmpty);

      await drag.up();
      await tester.pump();
      expect(question, findsOneWidget);
      await tester.pumpAndSettle();
      expect(app.flashcardRepository.reviews.single.remembered, isFalse);
      expect(find.text('2/2'), findsOneWidget);
    },
  );

  testWidgets('nothing due offers to revise the whole deck', (tester) async {
    final flashcards = FakeFlashcardRepository(cards: const [], totalCards: 20);
    final app = TestApp(token: 'token', flashcards: flashcards);

    await openStudyScreen(tester, app);

    expect(find.text('Bạn đã ôn hết thẻ đến hạn hôm nay.'), findsOneWidget);

    flashcards.cards = demoFlashcards;
    await tester.tap(find.text('Ôn trước cả 20 thẻ'));
    await tester.pumpAndSettle();

    expect(flashcards.calls, contains('session:10:all'));
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('an empty deck says so rather than showing a blank frame', (
    tester,
  ) async {
    final app = TestApp(
      token: 'token',
      flashcards: FakeFlashcardRepository(cards: const []),
    );

    await openStudyScreen(tester, app);

    expect(find.text('Bộ đề này chưa có thẻ nào.'), findsOneWidget);
  });

  testWidgets('a load failure offers a retry', (tester) async {
    final flashcards = FakeFlashcardRepository()..loadError = offline;
    final app = TestApp(token: 'token', flashcards: flashcards);
    await openStudyScreen(tester, app);

    expect(find.text(offline.message), findsOneWidget);

    flashcards.loadError = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Widget trong Flutter là gì?'), findsOneWidget);
  });
}
