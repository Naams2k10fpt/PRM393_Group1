class VoiceParticipant {
  VoiceParticipant.fromJson(Map<String, dynamic> json)
    : id = json['connectionId'] as String,
      userId = json['userId'] as String,
      name = json['displayName'] as String,
      channelId = json['channelId'] as int,
      microphone = json['microphoneEnabled'] == true,
      camera = json['cameraEnabled'] == true;
  final String id, userId, name;
  final int channelId;
  final bool microphone, camera;
}

class VoiceRoom {
  VoiceRoom.fromJson(Map<String, dynamic> json)
    : groupId = json['groupId'] as int,
      version = json['version'] as int,
      capacity = json['maxParticipants'] as int,
      participants = (json['participants'] as List)
          .map(
            (item) => VoiceParticipant.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
  final int groupId, version, capacity;
  final List<VoiceParticipant> participants;
}

class VoiceJoin {
  VoiceJoin.fromJson(Map<String, dynamic> json)
    : participantId = json['participantId'] as String,
      channelId = json['channelId'] as int,
      room = VoiceRoom.fromJson(Map<String, dynamic>.from(json['room'] as Map)),
      configuration = {
        // Native WebRTC rejects null credentials even for a STUN-only server.
        'iceServers': (json['iceServers'] as List)
            .map(
              (server) => Map<String, dynamic>.fromEntries(
                Map<String, dynamic>.from(server as Map).entries
                    .where((entry) => entry.value != null),
              ),
            )
            .toList(),
        'iceTransportPolicy': json['relayOnly'] == true ? 'relay' : 'all',
        'bundlePolicy': 'max-bundle',
        'sdpSemantics': 'unified-plan',
      };
  final String participantId;
  final int channelId;
  final VoiceRoom room;
  final Map<String, dynamic> configuration;
}
