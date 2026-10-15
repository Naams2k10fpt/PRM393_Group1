import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('a signed-in user sees the greeting and the subject grid', (tester) async {
    final app = TestApp(token: 'token');

    await app.start(tester);

    expect(find.text('Chào ${demoUser.username}'), findsOneWidget);
    expect(find.text('Lập trình di động'), findsOneWidget);
    expect(find.text('Lập trình .NET'), findsOneWidget);
    expect(find.text('2 bộ đề'), findsOneWidget);
    expect(app.catalogRepository.calls, contains('subjects'));
  });

  testWidgets('the Kahoot entry stays on the Home screen', (tester) async {
    final app = TestApp(token: 'token');

    await app.start(tester);

    expect(find.text('Kahoot Live'), findsOneWidget);
  });

  testWidgets('a failed load shows the message and retries', (tester) async {
    final catalog = FakeCatalogRepository()..subjectsError = offline;
    final app = TestApp(token: 'token', catalog: catalog);

    await app.start(tester);
    expect(find.text(offline.message), findsOneWidget);

    catalog.subjectsError = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text(offline.message), findsNothing);
    expect(find.text('Lập trình di động'), findsOneWidget);
  });

  testWidgets('no subjects yields an empty state, not a blank page', (tester) async {
    final app = TestApp(token: 'token', catalog: FakeCatalogRepository(subjectList: const []));

    await app.start(tester);

    expect(find.text('Chưa có môn học nào.'), findsOneWidget);
  });

  testWidgets('tapping a subject opens its deck list, titled with the subject', (tester) async {
    final app = TestApp(token: 'token');
    await app.start(tester);

    await tester.tap(find.text('Lập trình di động'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Lập trình di động'), findsOneWidget);
    expect(find.text('Flutter cơ bản'), findsOneWidget);
    expect(find.text('2 thẻ · 2 đến hạn'), findsOneWidget);
    expect(app.catalogRepository.calls, contains('decks:1'));
  });

  testWidgets('a subject with no decks says so', (tester) async {
    final app = TestApp(token: 'token', catalog: FakeCatalogRepository(deckList: const []));
    await app.start(tester);

    await tester.tap(find.text('Lập trình di động'));
    await tester.pumpAndSettle();

    expect(find.text('Môn học này chưa có bộ đề nào.'), findsOneWidget);
  });
}
