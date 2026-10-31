import 'package:signalr_netcore/signalr_client.dart';

import '../../core/config/app_config.dart';
import '../api/api_client.dart';
import '../models/voice_room.dart';

abstract class VoiceConnection {
  void Function(VoiceRoom)? onRoom;
  void Function(String, Map<String, dynamic>)? onSignal;
  void Function()? onDisconnected;
  void Function()? onReconnected;
  void Function()? onAccessRevoked;
  void Function(int)? onChannelClosed;
  void Function(Object)? onError;
  Future<VoiceRoom> connect();
  Future<VoiceJoin> join(int channelId);
  Future<void> setMedia(bool microphone, bool camera);
  Future<void> signal(String target, Map<String, dynamic> signal);
  Future<void> leave();
  Future<void> close();
}

class SignalRVoiceConnection extends VoiceConnection {
  SignalRVoiceConnection(ApiClient api, this.groupId)
    : _hub = HubConnectionBuilder()
          .withUrl(
            '${AppConfig.baseUrl}/hubs/voice',
            options: HttpConnectionOptions(
              accessTokenFactory: api.accessToken,
              requestTimeout: 60000,
            ),
          )
          .withAutomaticReconnect()
          .build() {
    _hub.on('VoiceRoomChanged', (args) {
      if (_closed || args?.firstOrNull is! Map) return;
      final room = VoiceRoom.fromJson(
        Map<String, dynamic>.from(args!.first as Map),
      );
      if (room.groupId == groupId) onRoom?.call(room);
    });
    _hub.on('VoiceSignal', (args) {
      if (_closed ||
          args?.length != 3 ||
          args![0] != groupId ||
          args[2] is! Map) {
        return;
      }
      onSignal?.call(
        args[1] as String,
        Map<String, dynamic>.from(args[2] as Map),
      );
    });
    _hub.on('VoiceAccessRevoked', (args) {
      if (!_closed && args?.firstOrNull == groupId) onAccessRevoked?.call();
    });
    _hub.on('VoiceChannelClosed', (args) {
      if (!_closed && args?.length == 2 && args![0] == groupId) {
        onChannelClosed?.call(args[1] as int);
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
        final room = await _watch();
        if (_closed) return;
        onReconnected?.call();
        onRoom?.call(room);
      } catch (error) {
        if (!_closed) onError?.call(error);
      }
    });
  }
  final int groupId;
  final HubConnection _hub;
  bool _closed = false;
  Future<VoiceRoom> _watch() async => VoiceRoom.fromJson(
    Map<String, dynamic>.from(
      await _hub.invoke('Watch', args: [groupId]) as Map,
    ),
  );
  @override
  Future<VoiceRoom> connect() async {
    await _hub.start();
    if (_closed) throw StateError('Kết nối đã đóng.');
    return _watch();
  }

  @override
  Future<VoiceJoin> join(int channelId) async => VoiceJoin.fromJson(
    Map<String, dynamic>.from(
      await _hub.invoke('Join', args: [groupId, channelId]) as Map,
    ),
  );
  @override
  Future<void> setMedia(bool microphone, bool camera) async {
    await _hub.invoke('SetMedia', args: [groupId, microphone, camera]);
  }

  @override
  Future<void> signal(String target, Map<String, dynamic> signal) async {
    await _hub.invoke('Signal', args: [groupId, target, signal]);
  }

  @override
  Future<void> leave() async {
    if (_hub.state == HubConnectionState.Connected) await _hub.invoke('Leave');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await leave();
    } finally {
      await _hub.stop();
    }
  }
}
