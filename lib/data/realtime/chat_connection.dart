import 'package:signalr_netcore/signalr_client.dart';

import '../../core/config/app_config.dart';
import '../api/api_client.dart';
import '../models/study_group.dart';

/// One room connection, owned by the room screen and replaceable in tests.
abstract class ChatConnection {
  void Function(ChatMessage)? onMessage;
  Future<void> Function()? onReconnected;
  void Function()? onDisconnected;
  void Function()? onAccessRevoked;
  void Function(Object)? onError;

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
    _hub.on('GroupAccessRevoked', (args) {
      if (!_closed && args?.isNotEmpty == true && args!.first == groupId) {
        onAccessRevoked?.call();
      }
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

  @override
  Future<void> connect() async {
    await _hub.start();
    if (_closed) {
      await _hub.stop();
      return;
    }
    await _hub.invoke('JoinGroup', args: [groupId]);
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
    onReconnected = null;
    onDisconnected = null;
    onAccessRevoked = null;
    onError = null;
    try {
      if (_hub.state == HubConnectionState.Connected) {
        await _hub.invoke('LeaveGroup', args: [groupId]);
      }
    } finally {
      await _hub.stop();
    }
  }
}
