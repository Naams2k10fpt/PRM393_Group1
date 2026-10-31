import 'package:signalr_netcore/signalr_client.dart';

import '../../core/config/app_config.dart';
import '../api/api_client.dart';
import '../models/study_group.dart';

/// One room connection, owned by the room screen and replaceable in tests.
abstract class ChatConnection {
  void Function(ChatMessage)? onMessage;
  void Function(ChatMessage)? onMessageUpdated;
  Future<void> Function()? onChannelsChanged;
  Future<void> Function()? onReconnected;
  void Function()? onDisconnected;
  void Function()? onAccessRevoked;
  void Function(Object)? onError;
  void Function(List<GroupMember>)? onRoster;
  void Function(Set<String>)? onPresence;
  void Function(Set<String>)? onWebsitePresence;

  Future<void> connect();
  Future<ChatMessage?> send(String content);
  Future<void> close();
}

class SignalRChatConnection extends ChatConnection {
  SignalRChatConnection(ApiClient api, this.groupId)
    : _hub =
          HubConnectionBuilder()
              .withUrl(
                '${AppConfig.baseUrl}/hubs/chat',
                options: HttpConnectionOptions(
                  accessTokenFactory: api.accessToken,
                  requestTimeout: 60000,
                ),
              )
              .withAutomaticReconnect()
              .build() {
    _hub.on('ReceiveMessage', (args) {
      if (_closed || args == null || args.isEmpty || args.first is! Map) return;
      final message = ChatMessage.fromJson(
        Map<String, dynamic>.from(args.first as Map),
      );
      if (message.groupId == groupId) onMessage?.call(message);
    });
    _hub.on('MessageUpdated', (args) {
      final data = _payload(args);
      if (data != null && data['groupId'] == groupId) {
        onMessageUpdated?.call(ChatMessage.fromJson(data));
      }
    });
    _hub.on('ChannelsChanged', (args) async {
      if (!_closed && args?.firstOrNull == groupId) {
        try {
          await onChannelsChanged?.call();
        } catch (error) {
          if (!_closed) onError?.call(error);
        }
      }
    });
    _hub.on('GroupAccessRevoked', (args) {
      if (!_closed && args?.isNotEmpty == true && args!.first == groupId) {
        onAccessRevoked?.call();
      }
    });
    _hub.on('RoomRosterChanged', (args) async {
      if (!_closed && args?.firstOrNull == groupId) {
        try {
          await _refreshRoster();
        } catch (error) {
          if (!_closed) onError?.call(error);
        }
      }
    });
    _hub.on('RoomPresenceChanged', (args) {
      final data = _payload(args);
      if (data != null) _presence(data);
    });
    _hub.on('WebsitePresenceDelta', (args) {
      final data = _payload(args);
      if (data == null || data['groupId'] != groupId) return;
      final id = data['userId'] as String;
      final version = data['version'] as int;
      if (version < (_websiteVersions[id] ?? -1)) return;
      _websiteVersions[id] = version;
      if (data['connected'] == true) {
        _website.add(id);
      } else {
        _website.remove(id);
      }
      onWebsitePresence?.call(Set.of(_website));
    });
    _hub.onreconnecting(({error}) {
      if (!_closed) onDisconnected?.call();
    });
    _hub.onclose(({error}) {
      if (!_closed) onDisconnected?.call();
    });
    _hub.onreconnected(({connectionId}) async {
      if (_closed) return;
      try {
        await _hub.invoke('JoinGroup', args: [groupId]);
        _presenceVersion = -1;
        _websiteVersions.clear();
        _website.clear();
        await _refreshRoster();
        if (!_closed) await onReconnected?.call();
      } catch (error) {
        if (!_closed) {
          onDisconnected?.call();
          onError?.call(error);
        }
      }
    });
  }

  final int groupId;
  final HubConnection _hub;
  bool _closed = false;
  int _presenceVersion = -1, _rosterRequest = 0;
  final _websiteVersions = <String, int>{};
  final _website = <String>{};

  Map<String, dynamic>? _payload(List<Object?>? args) {
    if (_closed || args == null || args.isEmpty || args.first is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(args.first as Map);
  }

  void _presence(Map<String, dynamic> data) {
    if (_closed ||
        data['groupId'] != groupId ||
        (data['version'] as int) < _presenceVersion) {
      return;
    }
    _presenceVersion = data['version'] as int;
    onPresence?.call((data['onlineUserIds'] as List).cast<String>().toSet());
  }

  Future<void> _refreshRoster() async {
    final request = ++_rosterRequest;
    final response = await _hub.invoke('GetRoomRoster', args: [groupId]);
    if (_closed || request != _rosterRequest || response is! Map) return;
    final members =
        (response['members'] as List)
            .map(
              (e) => GroupMember.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
    onRoster?.call(members);
    _presence(Map<String, dynamic>.from(response['presence'] as Map));
    final website = Map<String, dynamic>.from(response['website'] as Map);
    final version = website['version'] as int;
    final ids = (website['connectedUserIds'] as List).cast<String>().toSet();
    for (final member in members) {
      if (version < (_websiteVersions[member.userId] ?? -1)) continue;
      _websiteVersions[member.userId] = version;
      if (ids.contains(member.userId)) {
        _website.add(member.userId);
      } else {
        _website.remove(member.userId);
      }
    }
    onWebsitePresence?.call(Set.of(_website));
  }

  @override
  Future<void> connect() async {
    await _hub.start();
    if (_closed) {
      await _hub.stop();
      return;
    }
    await _hub.invoke('JoinGroup', args: [groupId]);
    await _refreshRoster();
  }

  @override
  Future<ChatMessage?> send(String content) async {
    final response = await _hub.invoke('SendMessage', args: [groupId, content]);
    return response is Map
        ? ChatMessage.fromJson(Map<String, dynamic>.from(response))
        : null;
  }

  @override
  Future<void> close() async {
    _closed = true;
    onMessage = null;
    onMessageUpdated = null;
    onChannelsChanged = null;
    onReconnected = null;
    onDisconnected = null;
    onAccessRevoked = null;
    onError = null;
    onRoster = null;
    onPresence = null;
    onWebsitePresence = null;
    try {
      if (_hub.state == HubConnectionState.Connected) {
        await _hub.invoke('LeaveGroup', args: [groupId]);
      }
    } finally {
      await _hub.stop();
    }
  }
}
