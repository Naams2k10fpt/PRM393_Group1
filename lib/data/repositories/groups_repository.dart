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
