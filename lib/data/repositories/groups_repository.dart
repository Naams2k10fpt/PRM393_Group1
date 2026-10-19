import '../api/api_client.dart';
import '../models/study_group.dart';
export '../models/study_group.dart';
import '../realtime/chat_connection.dart';

class GroupsRepository {
  GroupsRepository(this.api);
  final ApiClient api;

  ChatConnection openChat(int groupId) => SignalRChatConnection(api, groupId);

  Future<List<StudyGroup>> mine() async =>
      (await api.get('/api/groups') as List)
          .map((e) => StudyGroup.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<List<StudyGroup>> discover() async =>
      (await api.get('/api/groups/discover') as List)
          .map((e) => StudyGroup.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<void> create(String name, String description, int accessMode) async {
    await api.post(
      '/api/groups',
      data: {
        'name': name.trim(),
        'description': description.trim(),
        'subjectId': null,
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
}
