import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Home -> subject -> deck -> study, the way a user gets there.
Future<void> openStudyScreen(WidgetTester tester, TestApp app) async {
  await app.start(tester);
  await tester.tap(find.text('Lập trình di động'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Flutter cơ bản'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first card shows the question, and flipping reveals the answer', (tester) async {
    final app = TestApp(token: 'token');

    await openStudyScreen(tester, app);

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Widget trong Flutter là gì?'), findsOneWidget);
    expect(find.text('Đơn vị dựng giao diện'), findsNothing);

    await tester.tap(find.text('Widget trong Flutter là gì?'));
    await tester.pumpAndSettle();

    expect(find.text('Đơn vị dựng giao diện'), findsOneWidget);
    expect(find.text('Widget trong Flutter là gì?'), findsNothing);
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

    await tester.tap(find.text('Chưa thuộc'));
    await tester.pumpAndSettle();

    expect(find.text('Hoàn thành!'), findsOneWidget);
    expect(find.text('Bạn đã học hết 2 thẻ.'), findsOneWidget);
    expect(
      app.flashcardRepository.reviews,
      [(questionId: '100', remembered: true), (questionId: '101', remembered: false)],
      reason: 'the backend schedules each card on its own, so one request per answer',
    );
  });

  testWidgets('a review that fails is queued and can be sent again', (tester) async {
    final flashcards = FakeFlashcardRepository()..reviewError = offline;
    final app = TestApp(token: 'token', flashcards: flashcards);
    await openStudyScreen(tester, app);

    await tester.tap(find.text('Đã thuộc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã thuộc'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 thẻ chưa lưu được'), findsOneWidget);
    expect(flashcards.reviews, isEmpty);

    flashcards.reviewError = null;
    await tester.tap(find.text('Gửi lại'));
    await tester.pumpAndSettle();

    expect(find.textContaining('chưa lưu được'), findsNothing);
    expect(flashcards.reviews, hasLength(2));
  });

  testWidgets('a long swipe right marks the card as remembered', (tester) async {
    final app = TestApp(token: 'token');
    await openStudyScreen(tester, app);

    await tester.drag(find.text('Widget trong Flutter là gì?'), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(app.flashcardRepository.reviews.single.remembered, isTrue);
  });

  testWidgets('a short flick springs back and marks nothing', (tester) async {
    final app = TestApp(token: 'token');
    await openStudyScreen(tester, app);

    // Dismissible would have taken this as a fling and marked the card; the
    // swipe has to cross a third of the card's width to count.
    await tester.fling(find.text('Widget trong Flutter là gì?'), const Offset(24, 0), 2000);
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(app.flashcardRepository.reviews, isEmpty);
  });

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

  testWidgets('an empty deck says so rather than showing a blank frame', (tester) async {
    final app = TestApp(token: 'token', flashcards: FakeFlashcardRepository(cards: const []));

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
