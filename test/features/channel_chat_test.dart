import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/repositories/groups_repository.dart';
import '../support/tv3_fakes.dart';
import 'chat_test.dart' as helpers;

ChatMessage message(
  int id, {
  int channel = 1,
  String? content,
  String sender = 'u1',
  int revision = 0,
  bool deleted = false,
  int? replyId,
  List<Map<String, dynamic>> reactions = const [],
  List<Map<String, dynamic>> files = const [],
}) => ChatMessage.fromJson({
  'id': id,
  'groupId': 1,
  'channelId': channel,
  'senderUserId': sender,
  'senderName': sender == 'u1' ? 'Tôi' : 'Bạn học',
  'content': content ?? 'Tin $id',
  'sentAt': '2026-10-22T03:00:00Z',
  'kind': 0,
  'revision': revision,
  'editedAt': revision > 0 ? '2026-10-22T03:01:00Z' : null,
  'deletedAt': deleted ? '2026-10-22T03:02:00Z' : null,
  'reply':
      replyId == null
          ? null
          : {
            'id': replyId,
            'senderName': 'Tôi',
            'content': 'Tin $replyId',
            'isDeleted': false,
          },
  'attachments': files,
  'reactions': reactions,
});

class ChannelGroups extends FakeGroupsRepository {
  @override
  Future<Uint8List> downloadFile(ChatFile file) async => File('web/icons/Icon-192.png').readAsBytesSync();
  final rows = <int, List<ChatMessage>>{
    1: [message(1)],
    2: [message(100, channel: 2)],
  };
  final afterCursors = <int>[];
  int? sentReply;
  @override
  Future<List<ChatChannel>> channels(int id) async => [
    for (final channel in [1, 2])
      ChatChannel.fromJson({
        'id': channel,
        'groupId': id,
        'name': channel == 1 ? 'chung' : 'bài-tập',
        'isDefault': channel == 1,
        'unreadCount': 0,
      }),
  ];
  @override
  Future<List<ChatMessage>> channelMessages(
    int id,
    int channelId, {
    int? beforeId,
    int? afterId,
  }) async {
    if (afterId != null) afterCursors.add(afterId);
    final data =
        rows[channelId]!
            .where(
              (item) =>
                  (beforeId == null || item.id < beforeId) &&
                  (afterId == null || item.id > afterId),
            )
            .toList();
    return afterId != null
        ? data.take(30).toList()
        : data.skip((data.length - 30).clamp(0, data.length)).toList();
  }

  @override
  Future<ChatMessage> sendChannelMessage(
    int id,
    int channelId,
    String content,
    String nonce, {
    int? replyToId,
    List<ChatUpload> files = const [],
  }) async {
    sentReply = replyToId;
    final sent = message(
      200,
      channel: channelId,
      content: content,
      replyId: replyToId,
    );
    rows[channelId]!.add(sent);
    return sent;
  }

  @override
  Future<ChatMessage> editMessage(
    int id,
    int channelId,
    int messageId,
    String content,
  ) async =>
      message(messageId, channel: channelId, content: content, revision: 1);
  @override
  Future<ChatMessage> react(
    int id,
    int channelId,
    int messageId,
    String emoji,
    bool active,
  ) async => message(
    messageId,
    channel: channelId,
    revision: 2,
    reactions:
        active
            ? [
              {'emoji': emoji, 'userId': 'u1'},
            ]
            : [],
  );
}

void main() {
  testWidgets('image attachments open a zoomable preview on phone layout', (tester) async {
    final repo = ChannelGroups();
    repo.rows[1] = [message(1, files: [{'id': 'image-1', 'fileName': 'image.png', 'contentType': 'image/png', 'size': 5000}])];
    await helpers.openRoom(tester, repo);
    await tester.tap(find.byType(Image).last);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Đóng ảnh'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Đóng ảnh'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'deleting an unloaded reply target hides its quote without adding a history gap',
    (tester) async {
      final repo = ChannelGroups();
      repo.rows[1] = [message(50, replyId: 1)];
      await helpers.openRoom(tester, repo);
      expect(find.textContaining('Tin 1'), findsOneWidget);
      repo.connection.onMessageUpdated!(message(1, deleted: true, revision: 2));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tin nhắn đã bị xóa'), findsOneWidget);
      expect(find.textContaining('Tin 1'), findsNothing);
      expect(find.text('Tin 50'), findsOneWidget);
    },
  );

  testWidgets(
    'channels preserve separate drafts and replies include the target id',
    (tester) async {
      final repo = ChannelGroups();
      await helpers.openRoom(tester, repo);
      await tester.enterText(find.byType(TextField), 'Nháp kênh chung');
      await tester.tap(find.byTooltip('Các kênh chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('bài-tập'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(find.text('Tin 100'), findsOneWidget);
      await tester.tap(find.byTooltip('Các kênh chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('chung'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Nháp kênh chung',
      );
      await tester.tap(find.byTooltip('Thao tác tin nhắn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trả lời'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Đã nhận tài liệu');
      await tester.tap(find.byTooltip('Gửi'));
      await tester.pumpAndSettle();
      expect(repo.sentReply, 1);
      expect(find.text('Đã nhận tài liệu'), findsOneWidget);
    },
  );

  testWidgets(
    'reconnect fills more than one page and stale events cannot overwrite edits',
    (tester) async {
      final repo = ChannelGroups();
      await helpers.openRoom(tester, repo);
      repo.connection.onDisconnected!();
      repo.rows[1] = [for (var id = 1; id <= 75; id++) message(id)];
      await repo.connection.onReconnected!();
      await tester.pumpAndSettle();
      expect(repo.afterCursors, [1, 31, 61]);
      expect(find.text('Tin 75'), findsOneWidget);
      repo.connection.onMessageUpdated!(
        message(75, content: 'Đã chỉnh sửa', revision: 4),
      );
      repo.connection.onMessageUpdated!(
        message(75, content: 'Bản cũ', revision: 2),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã chỉnh sửa'), findsOneWidget);
      expect(find.text('Bản cũ'), findsNothing);
      repo.connection.onMessageUpdated!(
        message(75, deleted: true, revision: 5),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tin nhắn đã bị xóa'), findsOneWidget);
    },
  );

  testWidgets(
    'document attachments show safe download actions and reaction counts',
    (tester) async {
      final repo = ChannelGroups();
      repo.rows[1] = [
        message(
          1,
          files: [
            {
              'id': 'file-1',
              'fileName': 'Bài tập.pdf',
              'contentType': 'application/pdf',
              'size': 2048,
            },
          ],
          reactions: [
            {'emoji': '👍', 'userId': 'u2'},
            {'emoji': '👍', 'userId': 'u1'},
          ],
        ),
      ];
      await helpers.openRoom(tester, repo);
      expect(find.text('Bài tập.pdf'), findsOneWidget);
      expect(find.text('2 KB'), findsOneWidget);
      expect(find.byTooltip('Tải file'), findsOneWidget);
      expect(find.text('👍 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
