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
