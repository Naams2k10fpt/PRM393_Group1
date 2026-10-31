import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/study_group.dart';
export '../models/study_group.dart';
import '../realtime/chat_connection.dart';
import '../realtime/voice_connection.dart';

class GroupsRepository {
  GroupsRepository(this.api);
  final ApiClient api;

  ChatConnection openChat(int groupId) => SignalRChatConnection(api, groupId);
  VoiceConnection openVoice(int groupId) => SignalRVoiceConnection(api, groupId);

  Future<List<StudyGroup>> mine() async =>
      (await api.get('/api/groups') as List)
          .map((e) => StudyGroup.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<List<StudyGroup>> discover() async =>
      (await api.get('/api/groups/discover') as List)
          .map((e) => StudyGroup.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<void> create(
    String name,
    String description,
    int accessMode, {
    int? subjectId,
  }) async {
    await api.post(
      '/api/groups',
      data: {
        'name': name.trim(),
        'description': description.trim(),
        'subjectId': subjectId,
        'accessMode': accessMode,
      },
    );
  }

  Future<void> join(int id) async {
    await api.post('/api/groups/$id/join');
  }

  Future<void> cancelJoinRequest(int id) async {
    await api.delete('/api/groups/$id/join-request');
  }

  Future<List<ChatMessage>> messages(int id, {int? beforeId}) async =>
      (await api.get(
                '/api/groups/$id/messages',
                query: {
                  'limit': 30,
                  if (beforeId != null) 'beforeId': beforeId,
                },
              )
              as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<void> markRead(int id, int messageId) async {
    await api.post('/api/groups/$id/read', data: {'lastMessageId': messageId});
  }

  Future<List<ChatChannel>> channels(int id) async =>
      (await api.get('/api/groups/$id/channels') as List)
          // Text timelines never receive a voice channel ID.
          .where((item) => ((item as Map)['kind'] as int? ?? 0) == 0)
          .map(
            (item) =>
                ChatChannel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

  Future<List<ChatChannel>> voiceChannels(int id) async =>
      (await api.get('/api/groups/$id/channels') as List)
          .where((item) => (item as Map)['kind'] == 1)
          .map((item) => ChatChannel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

  Future<void> saveChannel(
    int id,
    String name,
    String topic, {
    int? channelId,
  }) async {
    final data = {'name': name.trim(), 'topic': topic.trim()};
    if (channelId == null) {
      await api.post('/api/groups/$id/channels', data: data);
    } else {
      await api.put('/api/groups/$id/channels/$channelId', data: data);
    }
  }

  Future<void> archiveChannel(int id, int channelId) async {
    await api.delete('/api/groups/$id/channels/$channelId');
  }

  Future<List<ChatMessage>> channelMessages(
    int id,
    int channelId, {
    int? beforeId,
    int? afterId,
  }) async =>
      (await api.get(
                '/api/groups/$id/channels/$channelId/messages',
                query: {
                  'limit': 30,
                  if (beforeId != null) 'beforeId': beforeId,
                  if (afterId != null) 'afterId': afterId,
                },
              )
              as List)
          .map(
            (item) =>
                ChatMessage.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

  Future<ChatMessage> sendChannelMessage(
    int id,
    int channelId,
    String content,
    String nonce, {
    int? replyToId,
    List<ChatUpload> files = const [],
  }) async => ChatMessage.fromJson(
    Map<String, dynamic>.from(
      await api.postMultipart(
            '/api/groups/$id/channels/$channelId/messages',
            FormData.fromMap({
              'content': content,
              'clientMessageId': nonce,
              if (replyToId != null) 'replyToId': replyToId,
              'files':
                  files
                      .map(
                        (file) => MultipartFile.fromBytes(
                          file.bytes,
                          filename: file.name,
                        ),
                      )
                      .toList(),
            }),
          )
          as Map,
    ),
  );

  Future<ChatMessage> editMessage(
    int id,
    int channelId,
    int messageId,
    String content,
  ) async => ChatMessage.fromJson(
    Map<String, dynamic>.from(
      await api.put(
            '/api/groups/$id/channels/$channelId/messages/$messageId',
            data: {'content': content},
          )
          as Map,
    ),
  );
  Future<ChatMessage> deleteMessage(
    int id,
    int channelId,
    int messageId,
  ) async => ChatMessage.fromJson(
    Map<String, dynamic>.from(
      await api.delete(
            '/api/groups/$id/channels/$channelId/messages/$messageId',
          )
          as Map,
    ),
  );
  Future<ChatMessage> react(
    int id,
    int channelId,
    int messageId,
    String emoji,
    bool active,
  ) async => ChatMessage.fromJson(
    Map<String, dynamic>.from(
      await api.put(
            '/api/groups/$id/channels/$channelId/messages/$messageId/reaction',
            data: {'emoji': emoji, 'active': active},
          )
          as Map,
    ),
  );
  Future<void> readChannel(int id, int channelId, int messageId) async {
    await api.post(
      '/api/groups/$id/channels/$channelId/read',
      data: {'lastMessageId': messageId},
    );
  }

  Future<Uint8List> downloadFile(ChatFile file) =>
      api.download('/api/chat/attachments/${file.id}');

  Future<GroupOptions> options() async => GroupOptions.fromJson(
    await api.get('/api/groups/options') as Map<String, dynamic>,
  );

  Future<GroupDiscovery> discovery({
    String search = '',
    int? accessMode,
    int? subjectId,
    String sort = 'newest',
    int page = 1,
  }) async => GroupDiscovery.fromJson(
    await api.get(
          '/api/groups/discovery',
          query: {
            'search': search,
            'sort': sort,
            'page': page,
            if (accessMode != null) 'accessMode': accessMode,
            if (subjectId != null) 'subjectId': subjectId,
          },
        )
        as Map<String, dynamic>,
  );

  Future<List<GroupInvitation>> invitations() async =>
      (await api.get('/api/groups/invitations') as List)
          .map((e) => GroupInvitation.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<GroupDetails> details(int id) async => GroupDetails.fromJson(
    await api.get('/api/groups/$id') as Map<String, dynamic>,
  );
  Future<GroupManagement> management(int id) async => GroupManagement.fromJson(
    await api.get('/api/groups/$id/management') as Map<String, dynamic>,
  );
  Future<void> respondInvitation(int id, bool accept) async {
    await api.post(
      '/api/groups/$id/invitation-response',
      data: {'accept': accept},
    );
  }

  Future<void> invite(int id, String email) async {
    await api.post(
      '/api/groups/$id/invitations',
      data: {'email': email.trim()},
    );
  }

  Future<void> review(int id, String userId, bool accept) async {
    await api.post(
      '/api/groups/$id/requests/${Uri.encodeComponent(userId)}/review',
      data: {'accept': accept},
    );
  }

  Future<void> changeAccess(int id, int mode) async {
    await api.put('/api/groups/$id/access', data: {'accessMode': mode});
  }

  Future<void> setModerator(int id, String userId, bool moderator) async {
    await api.put(
      '/api/groups/$id/members/${Uri.encodeComponent(userId)}/moderator',
      data: {'moderator': moderator},
    );
  }

  Future<void> transfer(int id, String userId) async {
    await api.post('/api/groups/$id/ownership', data: {'userId': userId});
  }

  Future<void> removeMember(int id, String userId) async {
    await api.delete('/api/groups/$id/members/${Uri.encodeComponent(userId)}');
  }

  Future<void> unban(int id, String userId) async {
    await api.delete('/api/groups/$id/bans/${Uri.encodeComponent(userId)}');
  }

  Future<void> leave(int id) async {
    await api.post('/api/groups/$id/leave');
  }

  Future<void> createLink(int id, int days) async {
    await api.post(
      '/api/groups/$id/invite-links',
      data: {'durationDays': days},
    );
  }

  Future<void> revokeLink(int id, int linkId) async {
    await api.delete('/api/groups/$id/invite-links/$linkId');
  }

  Future<GroupInvitePreview> previewLink(String token) async =>
      GroupInvitePreview.fromJson(
        await api.get('/api/groups/invite/${Uri.encodeComponent(token)}')
            as Map<String, dynamic>,
      );
  Future<int> acceptLink(String token) async =>
      (await api.post('/api/groups/invite/${Uri.encodeComponent(token)}')
              as Map<String, dynamic>)['id']
          as int;
}

class ChatUpload {
  const ChatUpload(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}
