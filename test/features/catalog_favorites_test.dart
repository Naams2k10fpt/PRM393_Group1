import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/core/config/app_config.dart';
import 'package:quiz_management_mobile/data/repositories/catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('starred subjects and decks move first and survive reopening', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final catalog = FakeCatalogRepository();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    await TestApp(token: 'token', catalog: catalog).start(tester);

    final subject = find.text('Lập trình .NET');
    final otherSubject = find.text('Lập trình di động');
    final deck = find.text('State management');
    final otherDeck = find.text('Flutter cơ bản');
    final subjectStar = find.byTooltip('Yêu thích: Lập trình .NET');
    final subjectUnstar = find.byTooltip('Bỏ yêu thích: Lập trình .NET');
    final deckStar = find.byTooltip('Yêu thích: State management');
    final deckUnstar = find.byTooltip('Bỏ yêu thích: State management');

    await tester.tapAt(tester.getCenter(subjectStar) - const Offset(15, 0));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Lập trình .NET'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(subjectStar, findsOneWidget);

    await tester.tap(subjectStar);
    await tester.pumpAndSettle();
    expect(subjectUnstar, findsOneWidget);
    expect(
      tester.getTopLeft(subject).dx,
      lessThan(tester.getTopLeft(otherSubject).dx),
    );
    expect(find.text('Môn học'), findsOneWidget);

    await tester.tap(otherSubject);
    await tester.pumpAndSettle();
    await tester.ensureVisible(deckStar);
    await tester.tapAt(tester.getCenter(deckStar) - const Offset(15, 0));
    await tester.pumpAndSettle();
    expect(deckUnstar, findsNothing);

    await tester.tap(deckStar);
    await tester.pumpAndSettle();
    expect(deckUnstar, findsOneWidget);
    expect(
      tester.getTopLeft(deck).dy,
      lessThan(tester.getTopLeft(otherDeck).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    SharedPreferences.setMockInitialValues({});
    await TestApp(token: 'token', catalog: catalog).start(tester);
    expect(subjectUnstar, findsOneWidget);
    await tester.tap(otherSubject);
    await tester.pumpAndSettle();
    expect(deckUnstar, findsOneWidget);
    await tester.tap(deckUnstar);
    await tester.pumpAndSettle();
    expect(deckStar, findsOneWidget);
    expect(
      tester.getTopLeft(deck).dy,
      greaterThan(tester.getTopLeft(otherDeck).dy),
    );
  });

  testWidgets('opening Home retries unsynced legacy stars for both kinds', (
    tester,
  ) async {
    String legacyKey(FavoriteKind kind) =>
        'catalog.favorites.v1.${jsonEncode([AppConfig.baseUrl, demoUser.id, kind.name])}';
    final subjectsKey = legacyKey(FavoriteKind.subject);
    final decksKey = legacyKey(FavoriteKind.deck);
    SharedPreferences.setMockInitialValues({
      subjectsKey: ['2'],
      decksKey: ['11'],
    });
    final catalog = FakeCatalogRepository()..favoriteWriteError = offline;
    await TestApp(token: 'token', catalog: catalog).start(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(subjectsKey), ['2']);
    expect(prefs.getStringList(decksKey), ['11']);
    expect(await catalog.favoriteIds(FavoriteKind.deck), isEmpty);

    catalog.favoriteWriteError = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await TestApp(token: 'token', catalog: catalog).start(tester);

    expect(await catalog.favoriteIds(FavoriteKind.subject), {'2'});
    expect(await catalog.favoriteIds(FavoriteKind.deck), {'11'});
    expect(prefs.containsKey(subjectsKey), isFalse);
    expect(prefs.containsKey(decksKey), isFalse);
    expect(find.byTooltip('Bỏ yêu thích: Lập trình .NET'), findsOneWidget);
  });
}
