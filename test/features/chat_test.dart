import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/repositories/groups_repository.dart';

import '../support/fakes.dart';
import '../support/tv3_fakes.dart';

Future<void> openGroups(WidgetTester tester, FakeGroupsRepository repo) async {
  await TestApp(token: 'token', groups: repo).start(tester);
  await tester.tap(find.text('Nhóm học'));
  await tester.pumpAndSettle();
}

Future<void> openRoom(WidgetTester tester, FakeGroupsRepository repo) async {
  await openGroups(tester, repo);
  await tester.tap(find.text('Nhóm TV3'));
  // A delayed connection has an animated progress indicator.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (repo.connection.pendingConnect == null) await tester.pumpAndSettle();
}

void main() {
  testWidgets('group list shows unread count, join approval and cancellation', (
    tester,
  ) async {
    final repo = FakeGroupsRepository();
    await openGroups(tester, repo);
    expect(find.widgetWithText(Badge, '3'), findsOneWidget);
    expect(find.textContaining('Môn TV3 · 2 thành viên'), findsWidgets);
    await tester.tap(find.text('Tham gia'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('join:2'));
    expect(find.text('Đã gửi yêu cầu tham gia.'), findsOneWidget);
    await tester.tap(find.text('Hủy yêu cầu'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('cancel:2'));
    expect(find.text('Tham gia'), findsOneWidget);
  });

  testWidgets('new group validates its name before calling the API', (
    tester,
  ) async {
    final repo = FakeGroupsRepository();
    await openGroups(tester, repo);
    await tester.tap(find.byTooltip('Tạo nhóm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên nhóm.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, 'Nhóm mới');
    await tester.tap(find.text('Tạo'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('create:Nhóm mới::0'));
  });

  testWidgets('messages deduplicate hub echoes and reconnect catches up', (
    tester,
  ) async {
    final repo = FakeGroupsRepository();
    await openRoom(tester, repo);
    expect(find.text('Tin nhắn 1'), findsOneWidget);
    repo.connection.onMessage!(chatMessage(1));
    repo.connection.onMessage!(chatMessage(2));
    await tester.pumpAndSettle();
    expect(find.text('Tin nhắn 1'), findsOneWidget);
    expect(find.text('Tin nhắn 2'), findsOneWidget);
    expect(repo.calls, contains('read:1:2'));
    repo.connection.onDisconnected!();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send))
          .onPressed,
      isNull,
    );
    repo.latest = [chatMessage(2), chatMessage(3)];
    await repo.connection.onReconnected!();
    await tester.pumpAndSettle();
    expect(find.text('Tin nhắn 2'), findsOneWidget);
    expect(find.text('Tin nhắn 3'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'sending keeps text typed while waiting and ignores echoed duplicate',
    (tester) async {
      final repo = FakeGroupsRepository();
      repo.connection.pendingSend = Completer<ChatMessage?>();
      await openRoom(tester, repo);
      await tester.enterText(find.byType(TextField), 'Tin gửi đi');
      await tester.tap(find.byTooltip('Gửi'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Bản nháp tiếp theo');
      final sent = chatMessage(100, sender: 'u1', content: 'Tin gửi đi');
      repo.connection.onMessage!(sent);
      repo.connection.pendingSend!.complete(sent);
      await tester.pumpAndSettle();
      expect(repo.connection.sent, ['Tin gửi đi']);
      expect(find.text('Tin gửi đi'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Bản nháp tiếp theo',
      );
    },
  );

  testWidgets(
    'failed connection can be retried and long sender names fit a phone',
    (tester) async {
      final repo = FakeGroupsRepository();
      repo.connection.connectError = offline;
      await openRoom(tester, repo);
      expect(find.text(offline.message), findsOneWidget);
      repo.connection.connectError = null;
      repo.latest = [
        chatMessage(1, name: List.filled(20, 'Tên dài').join(' ')),
      ];
      await tester.tap(find.text('Kết nối lại'));
      await tester.pumpAndSettle();
      expect(repo.connection.connectCount, 2);
      expect(find.text('Tin nhắn 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving during connect closes transport and late completion never loads history',
    (tester) async {
      final repo = FakeGroupsRepository();
      repo.connection.pendingConnect = Completer<void>();
      await openRoom(tester, repo);
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(repo.connection.closeCount, 1);
      repo.connection.pendingConnect!.complete();
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('messages:')), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'access revoked returns to groups and stops the room connection',
    (tester) async {
      final repo = FakeGroupsRepository();
      await openRoom(tester, repo);
      repo.connection.onAccessRevoked!();
      await tester.pumpAndSettle();
      expect(find.text('Nhóm của tôi'), findsOneWidget);
      expect(repo.connection.closeCount, 1);
    },
  );

  testWidgets('older messages merge without duplicates', (tester) async {
    final repo = FakeGroupsRepository();
    repo.latest = [for (var i = 10; i < 40; i++) chatMessage(i)];
    repo.older = [for (var i = 1; i <= 10; i++) chatMessage(i)];
    await openRoom(tester, repo);
    final list = find.byType(ListView).last;
    await tester.drag(list, const Offset(0, 10000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tin nhắn cũ hơn'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('messages:1:10'));
    expect(find.text('Tin nhắn 1'), findsOneWidget);
    expect(find.text('Tin nhắn cũ hơn'), findsNothing);
  });
}
