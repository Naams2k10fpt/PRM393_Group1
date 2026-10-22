class StudyGroup {
  StudyGroup.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String,
      description = json['description'] as String?,
      subjectName = json['subjectName'] as String?,
      ownerName = json['ownerName'] as String?,
      unreadCount = json['unreadCount'] as int,
      memberCount = json['memberCount'] as int,
      isMember = json['isMember'] as bool,
      hasPendingRequest = json['hasPendingRequest'] as bool,
      accessMode = json['accessMode'] as int;
  final int id;
  final String name;
  final String? description;
  final String? subjectName;
  final String? ownerName;
  final int unreadCount;
  final int memberCount;
  final bool isMember;
  final bool hasPendingRequest;
  final int accessMode;
}

String groupAccessLabel(int mode) => switch (mode) {
  1 => 'Cần phê duyệt',
  2 => 'Riêng tư · chỉ được mời',
  _ => 'Công khai',
};

class GroupSubject {
  GroupSubject.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String;
  final int id;
  final String name;
}

class GroupOptions {
  GroupOptions.fromJson(Map<String, dynamic> json)
    : publicSubjects =
          (json['publicSubjects'] as List)
              .map((e) => GroupSubject.fromJson(e as Map<String, dynamic>))
              .toList(),
      mySubjects =
          (json['mySubjects'] as List)
              .map((e) => GroupSubject.fromJson(e as Map<String, dynamic>))
              .toList();
  final List<GroupSubject> publicSubjects;
  final List<GroupSubject> mySubjects;
}

class GroupDiscovery {
  GroupDiscovery.fromJson(Map<String, dynamic> json)
    : groups =
          (json['groups'] as List)
              .map((e) => StudyGroup.fromJson(e as Map<String, dynamic>))
              .toList(),
      totalCount = json['totalCount'] as int,
      page = json['page'] as int,
      pageCount = json['pageCount'] as int;
  final List<StudyGroup> groups;
  final int totalCount, page, pageCount;
}

class GroupInvitation {
  GroupInvitation.fromJson(Map<String, dynamic> json)
    : groupId = json['groupId'] as int,
      groupName = json['groupName'] as String,
      expiresAt = DateTime.parse(json['expiresAt'] as String);
  final int groupId;
  final String groupName;
  final DateTime expiresAt;
}

class GroupMember {
  GroupMember.fromJson(Map<String, dynamic> json)
    : userId = json['userId'] as String,
      username = json['username'] as String,
      role = json['role'] as int;
  final String userId, username;
  final int role;
  String get roleLabel => switch (role) {
    2 => 'Chủ phòng',
    1 => 'Người quản lý',
    _ => 'Thành viên',
  };
}

class GroupDetails {
  GroupDetails.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String,
      description = json['description'] as String?,
      accessMode = json['accessMode'] as int,
      myRole = json['myRole'] as int,
      members =
          (json['members'] as List)
              .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
              .toList();
  final int id, accessMode, myRole;
  final String name;
  final String? description;
  final List<GroupMember> members;
  bool get isManager => myRole >= 1;
  bool get isOwner => myRole == 2;
}

class GroupRequest {
  GroupRequest.fromJson(Map<String, dynamic> json)
    : userId = json['userId'] as String,
      username = json['username'] as String;
  final String userId, username;
}

class GroupInviteLink {
  GroupInviteLink.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      token = json['token'] as String?,
      expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      revokedAt = DateTime.tryParse(json['revokedAt'] as String? ?? '');
  final int id;
  final String? token;
  final DateTime? expiresAt, revokedAt;
  bool get isActive =>
      revokedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
}

class GroupManagement {
  GroupManagement.fromJson(Map<String, dynamic> json)
    : requests =
          (json['requests'] as List)
              .map((e) => GroupRequest.fromJson(e as Map<String, dynamic>))
              .toList(),
      banned =
          (json['banned'] as List)
              .map((e) => GroupRequest.fromJson(e as Map<String, dynamic>))
              .toList(),
      links =
          (json['inviteLinks'] as List)
              .map((e) => GroupInviteLink.fromJson(e as Map<String, dynamic>))
              .toList();
  final List<GroupRequest> requests, banned;
  final List<GroupInviteLink> links;
}

class GroupInvitePreview {
  GroupInvitePreview.fromJson(Map<String, dynamic> json)
    : groupId = json['groupId'] as int,
      groupName = json['groupName'] as String;
  final int groupId;
  final String groupName;
}

class ChatMessage {
  ChatMessage._withReply(ChatMessage source, this.reply)
    : id = source.id,
      groupId = source.groupId,
      senderUserId = source.senderUserId,
      senderName = source.senderName,
      senderAvatarUrl = source.senderAvatarUrl,
      content = source.content,
      sentAt = source.sentAt,
      kind = source.kind,
      channelId = source.channelId,
      revision = source.revision,
      editedAt = source.editedAt,
      deletedAt = source.deletedAt,
      attachments = source.attachments,
      reactions = source.reactions;
  ChatMessage withReply(ChatReply reply) => ChatMessage._withReply(this, reply);
  ChatMessage.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      groupId = json['groupId'] as int,
      senderUserId = json['senderUserId'] as String,
      senderName = json['senderName'] as String,
      senderAvatarUrl = json['senderAvatarUrl'] as String?,
      content = json['content'] as String,
      sentAt = DateTime.parse(json['sentAt'] as String),
      channelId = json['channelId'] as int? ?? 0,
      revision = json['revision'] as int? ?? 0,
      editedAt = DateTime.tryParse(json['editedAt'] as String? ?? ''),
      deletedAt = DateTime.tryParse(json['deletedAt'] as String? ?? ''),
      reply =
          json['reply'] is Map
              ? ChatReply.fromJson(
                Map<String, dynamic>.from(json['reply'] as Map),
              )
              : null,
      attachments =
          ((json['attachments'] as List?) ?? [])
              .map(
                (item) =>
                    ChatFile.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList(),
      reactions =
          ((json['reactions'] as List?) ?? [])
              .map(
                (item) => ChatReaction.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
      kind = json['kind'] as int;
  final int id;
  final int groupId;
  final String senderUserId;
  final String senderName;
  final String? senderAvatarUrl;
  final String content;
  final DateTime sentAt;
  final int kind;
  final int channelId, revision;
  final DateTime? editedAt, deletedAt;
  final ChatReply? reply;
  final List<ChatFile> attachments;
  final List<ChatReaction> reactions;
  bool get isDeleted => deletedAt != null;
}

class ChatChannel {
  ChatChannel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      groupId = json['groupId'] as int,
      name = json['name'] as String,
      topic = json['topic'] as String?,
      isDefault = json['isDefault'] as bool,
      unreadCount = json['unreadCount'] as int? ?? 0;
  final int id, groupId;
  final String name;
  final String? topic;
  final bool isDefault;
  int unreadCount;
}

class ChatReply {
  ChatReply.fromMessage(ChatMessage message)
    : id = message.id,
      senderName = message.senderName,
      content = message.isDeleted ? 'Tin nhắn đã bị xóa' : message.content,
      isDeleted = message.isDeleted,
      revision = message.revision;
  ChatReply.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      senderName = json['senderName'] as String,
      content = json['content'] as String,
      isDeleted = json['isDeleted'] as bool,
      revision = json['revision'] as int? ?? 0;
  final int id;
  final int revision;
  final String senderName, content;
  final bool isDeleted;
}

class ChatFile {
  ChatFile.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      fileName = json['fileName'] as String,
      contentType = json['contentType'] as String,
      size = json['size'] as int;
  final String id, fileName, contentType;
  final int size;
  bool get isImage => contentType.startsWith('image/');
  String get sizeLabel =>
      size >= 1024 * 1024
          ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
          : '${(size / 1024).ceil()} KB';
}

class ChatReaction {
  ChatReaction.fromJson(Map<String, dynamic> json)
    : emoji = json['emoji'] as String,
      userId = json['userId'] as String;
  final String emoji, userId;
}
