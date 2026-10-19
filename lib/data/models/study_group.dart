class StudyGroup {
  StudyGroup.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String,
      description = json['description'] as String?,
      subjectName = json['subjectName'] as String?,
      unreadCount = json['unreadCount'] as int,
      memberCount = json['memberCount'] as int,
      isMember = json['isMember'] as bool,
      hasPendingRequest = json['hasPendingRequest'] as bool,
      accessMode = json['accessMode'] as int;
  final int id;
  final String name;
  final String? description;
  final String? subjectName;
  final int unreadCount;
  final int memberCount;
  final bool isMember;
  final bool hasPendingRequest;
  final int accessMode;
}

class ChatMessage {
  ChatMessage.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      groupId = json['groupId'] as int,
      senderUserId = json['senderUserId'] as String,
      senderName = json['senderName'] as String,
      senderAvatarUrl = json['senderAvatarUrl'] as String?,
      content = json['content'] as String,
      sentAt = DateTime.parse(json['sentAt'] as String),
      kind = json['kind'] as int;
  final int id;
  final int groupId;
  final String senderUserId;
  final String senderName;
  final String? senderAvatarUrl;
  final String content;
  final DateTime sentAt;
  final int kind;
}
