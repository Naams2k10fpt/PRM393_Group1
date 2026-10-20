import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/repositories/groups_repository.dart';
import 'package:quiz_management_mobile/features/chat/join_invite_dialog.dart';
import '../support/fakes.dart';
import '../support/tv3_fakes.dart';

Future<void> groups(WidgetTester tester, FakeGroupsRepository repo) async {
  await TestApp(token: 'token', groups: repo).start(tester);
  await tester.tap(find.text('Nhóm học'));
  await tester.pumpAndSettle();
}

Future<void> details(WidgetTester tester, FakeGroupsRepository repo) async {
  await groups(tester, repo);
  await tester.tap(find.text('Nhóm TV3'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Thông tin và quản lý nhóm'));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  await tester.pumpAndSettle();
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  final scrollable =
      find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: scrollable,
    maxScrolls: 30,
  );
}

void main() {
  test(
    'invite parser accepts web links and tokens and rejects unrelated paths',
    () {
      final token = 'a' * 64;
      expect(inviteToken('https://example.com/groups/invite/$token'), token);
      expect(inviteToken(token), token);
      expect(inviteToken('https://example.com/other/$token'), isNull);
      expect(inviteToken('/groups/invite/invalid'), isNull);
    },
  );

  testWidgets('search and access filter are sent to discovery', (tester) async {
    final repo = FakeGroupsRepository();
    await groups(tester, repo);
    await tapVisible(tester, find.byTooltip('Tìm kiếm'));
    await tester.enterText(find.byType(TextField), 'ôn thi');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('search:ôn thi:null:null:newest:1'));
    await tapVisible(tester, find.byType(DropdownButtonFormField<int>).first);
    await tester.tap(find.text('Cần phê duyệt').last);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('search:ôn thi:1:null:newest:1'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('create supports private groups and owned subjects', (
    tester,
  ) async {
    final repo = FakeGroupsRepository();
    await groups(tester, repo);
    await tester.tap(find.byTooltip('Tạo nhóm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Nhóm riêng');
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Môn TV3').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byType(DropdownButtonFormField<int>).last);
    await tester.tap(find.text('Riêng tư · chỉ được mời').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('create:Nhóm riêng::2'));
    expect(repo.calls, contains('subject:1'));
  });

  testWidgets('invitation can be accepted and disappears after refresh', (
    tester,
  ) async {
    final repo = FakeGroupsRepository()..invited = true;
    await groups(tester, repo);
    expect(find.text('Nhóm mời riêng'), findsOneWidget);
    await tester.tap(find.text('Chấp nhận'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('invitation:3:true'));
    expect(find.text('Nhóm mời riêng'), findsNothing);
  });

  testWidgets('member sees roster and leave but no management controls', (
    tester,
  ) async {
    final repo = FakeGroupsRepository()..role = 0;
    await details(tester, repo);
    expect(find.text('Thành viên (2)'), findsOneWidget);
    expect(find.text('Mời thành viên'), findsNothing);
    expect(find.text('Link mời vào nhóm'), findsNothing);
    await tapVisible(tester, find.text('Rời nhóm'));
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('leave:1'));
    expect(find.text('Nhóm của tôi'), findsOneWidget);
  });

  testWidgets(
    'owner can approve, invite and grant a moderator on phone layout',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeGroupsRepository();
      await details(tester, repo);
      await tapVisible(tester, find.text('Duyệt'));
      expect(repo.calls, contains('review:1:u3:true'));
      await scrollTo(tester, find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'friend@example.com');
      await tapVisible(tester, find.text('Gửi lời mời'));
      expect(repo.calls, contains('invite:1:friend@example.com'));
      await tapVisible(tester, find.byTooltip('Thao tác với Bạn học'));
      await tester.tap(find.text('Cho quyền quản lý'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('moderator:1:u2:true'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ownership transfer refreshes permissions instead of keeping owner actions',
    (tester) async {
      final repo = FakeGroupsRepository();
      await details(tester, repo);
      await tapVisible(tester, find.byTooltip('Thao tác với Bạn học'));
      await tester.tap(find.text('Chuyển chủ phòng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('transfer:1:u2'));
      expect(find.text('Mời thành viên'), findsNothing);
      expect(find.text('Link mời vào nhóm'), findsNothing);
      expect(find.text('Rời nhóm'), findsOneWidget);
    },
  );

  testWidgets(
    'room displays live member presence and revocation closes nested details',
    (tester) async {
      final repo = FakeGroupsRepository();
      await groups(tester, repo);
      await tester.tap(find.text('Nhóm TV3'));
      await tester.pumpAndSettle();
      repo.connection.onRoster!([
        GroupMember.fromJson({
          'userId': 'u2',
          'username': 'Bạn học',
          'role': 0,
        }),
      ]);
      repo.connection.onPresence!({'u2'});
      await tester.tap(find.byTooltip('Thành viên'));
      await tester.pumpAndSettle();
      expect(find.text('Thành viên · Online'), findsOneWidget);
      repo.connection.onPresence!({});
      await tester.pumpAndSettle();
      expect(find.text('Thành viên · Ngoại tuyến'), findsOneWidget);
      repo.connection.onDisconnected!();
      await tester.pumpAndSettle();
      expect(
        find.text('Đang mất kết nối · trạng thái chưa cập nhật'),
        findsOneWidget,
      );
      await repo.connection.onReconnected!();
      await tester.pumpAndSettle();
      expect(find.text('0 đang trong phòng chat'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thông tin và quản lý nhóm'));
      await tester.pumpAndSettle();
      repo.connection.onAccessRevoked!();
      await tester.pumpAndSettle();
      expect(find.text('Nhóm của tôi'), findsOneWidget);
      expect(repo.connection.closeCount, 1);
    },
  );

  testWidgets('pasted invitation previews before accepting', (tester) async {
    final repo = FakeGroupsRepository();
    await groups(tester, repo);
    await tester.tap(find.byTooltip('Tham gia bằng link mời'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Dán link mời'),
      'a' * 64,
    );
    await tester.tap(find.text('Kiểm tra link'));
    await tester.pumpAndSettle();
    expect(find.text('Tham gia nhóm “Nhóm TV3”?'), findsOneWidget);
    expect(repo.calls.where((c) => c.startsWith('accept-link:')), isEmpty);
    await tester.tap(find.text('Xác nhận tham gia'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('accept-link:${'a' * 64}'));
    expect(find.byTooltip('Thông tin và quản lý nhóm'), findsOneWidget);
  });
}
