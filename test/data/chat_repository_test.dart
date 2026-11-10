import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/api/api_client.dart';
import 'package:quiz_management_mobile/data/api/token_storage.dart';
import 'package:quiz_management_mobile/data/repositories/groups_repository.dart';

class ChatRecordingApi extends ApiClient {
  ChatRecordingApi() : super(tokens: InMemoryTokenStorage());
  FormData? form;
  String? path;
  int getCount = 0;
  List<Map<String, dynamic>> channelResponse = [];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    getCount++;
    return channelResponse;
  }

  @override
  Future<dynamic> postMultipart(String path, FormData data) async {
    this.path = path;
    form = data;
    return {
      'id': 1,
      'groupId': 7,
      'channelId': 9,
      'senderUserId': 'u1',
      'senderName': 'Demo',
      'content': 'Tài liệu',
      'sentAt': '2026-10-22T00:00:00Z',
      'kind': 0,
    };
  }
}

void main() {
  test(
    'one response preserves text, voice and legacy channel kinds',
    () async {
      final api = ChatRecordingApi();
      Map<String, dynamic> channel(int id, String name, [int? kind]) => {
        'id': id,
        'groupId': 7,
        'name': name,
        'isDefault': id == 1,
        if (kind != null) 'kind': kind,
      };
      api.channelResponse = [
        channel(1, 'chung', 0),
        channel(2, 'phong-hoc', 1),
        channel(3, 'legacy'),
        channel(4, 'bai-tap', 0),
      ];

      final channels = await GroupsRepository(api).channels(7);

      expect(api.path, '/api/groups/7/channels');
      expect(api.getCount, 1);
      expect(channels.map((channel) => channel.id), [1, 2, 3, 4]);
      expect(channels.map((channel) => channel.kind), [0, 1, 0, 0]);
      expect(channels.first.isDefault, isTrue);
    },
  );

  test(
    'multipart sends channel, reply, retry identity and file bytes without exposing credentials in URLs',
    () async {
      final api = ChatRecordingApi();
      final result = await GroupsRepository(api).sendChannelMessage(
        7,
        9,
        'Tài liệu',
        '11111111-1111-1111-1111-111111111111',
        replyToId: 23,
        files: [
          ChatUpload('notes.txt', Uint8List.fromList([1, 2, 3])),
        ],
      );
      expect(api.path, '/api/groups/7/channels/9/messages');
      expect(Map.fromEntries(api.form!.fields), {
        'content': 'Tài liệu',
        'clientMessageId': '11111111-1111-1111-1111-111111111111',
        'replyToId': '23',
      });
      expect(api.form!.files.single.value.filename, 'notes.txt');
      expect(api.form!.files.single.value.length, 3);
      expect(result.channelId, 9);
    },
  );
}
