import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../data/models/voice_room.dart';
import '../../data/realtime/voice_connection.dart';
import '../../data/realtime/voice_peer.dart';

abstract class VoiceDevices {
  Future<void> prepare() async {}
  Future<void> videoReleased() async {}
  Future<MediaStream> capture(String kind);
  Future<void> speaker(bool enabled);
  Future<void> switchCamera(MediaStreamTrack track);
}

class WebRtcVoiceDevices implements VoiceDevices {
  @override
  Future<void> videoReleased() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await const MethodChannel('quizms/voice_permissions')
          .invokeMethod<void>('awaitVideoRelease');
    }
  }

  @override
  Future<void> prepare() => _permission('audio');

  Future<void> _permission(String kind) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final granted = await const MethodChannel('quizms/voice_permissions')
          .invokeMethod<bool>('request', kind);
      if (granted != true) throw StateError('Permission denied');
      final binding = WidgetsBinding.instance;
      if (binding.lifecycleState != AppLifecycleState.resumed) {
        final resumed = Completer<void>();
        final listener = AppLifecycleListener(
          onResume: () {
            if (!resumed.isCompleted) resumed.complete();
          },
        );
        try {
          await resumed.future.timeout(const Duration(seconds: 30));
        } finally {
          listener.dispose();
        }
      }
      // Resume texture consumption before WebRTC takes the shared EGL lock.
      await binding.endOfFrame;
    }
  }

  @override
  Future<MediaStream> capture(String kind) async {
    await _permission(kind);
    return navigator.mediaDevices.getUserMedia({
      'audio': kind == 'audio'
          ? {
              'echoCancellation': true,
              'noiseSuppression': true,
              'autoGainControl': true,
            }
          : false,
      'video': kind == 'video'
          ? {'facingMode': 'user', 'width': 640, 'height': 360, 'frameRate': 24}
          : false,
    });
  }

  @override
  Future<void> speaker(bool enabled) => Helper.setSpeakerphoneOn(enabled);
  @override
  Future<void> switchCamera(MediaStreamTrack track) async {
    await Helper.switchCamera(track);
  }
}

/// Owned by the group screen so switching between text and voice keeps the call.
class VoiceRoomController extends ChangeNotifier {
  VoiceRoomController(
    this.connection, {
    VoiceDevices? devices,
    VoicePeerFactory? peerFactory,
  }) : devices = devices ?? WebRtcVoiceDevices(),
       peerFactory = peerFactory ?? WebRtcVoicePeer.new {
    connection.onRoom = _applyRoom;
    connection.onSignal = (id, signal) {
      if (joining) {
        if (_pendingSignals.length < 200) _pendingSignals.add((id, signal));
      } else {
        _receive(id, signal);
      }
    };
    connection.onDisconnected = () {
      connected = false;
      unawaited(
        leave(
          message:
              'Mất kết nối. Thiết bị đã tắt; hãy vào lại phòng khi có mạng.',
        ),
      );
    };
    connection.onReconnected = () {
      room = null;
      connected = true;
      _changed();
    };
    connection.onAccessRevoked = () {
      connected = false;
      unawaited(leave(message: 'Bạn không còn quyền tham gia phòng voice.'));
    };
    connection.onChannelClosed = (id) {
      if (channelId == id) {
        unawaited(leave(message: 'Kênh voice đã được lưu trữ.'));
      }
    };
    connection.onError = _error;
  }
  final VoiceConnection connection;
  final VoiceDevices devices;
  final VoicePeerFactory peerFactory;
  final peers = <String, VoicePeer>{};
  final streams = <String, MediaStream>{};
  final states = <String, String>{};
  final levels = <String, double>{};
  final _captures = <String, MediaStream>{};
  final _pendingSignals = <(String, Map<String, dynamic>)>[];
  VoiceRoom? room;
  String? participantId, error;
  int? channelId;
  int _epoch = 0;
  bool connected = false,
      connecting = false,
      joining = false,
      mediaBusy = false;
  bool speakerEnabled = true,
      frontCamera = true,
      _disposed = false,
      _sampling = false;
  Future<void> _operations = Future.value(), _cleanup = Future.value();
  Timer? _meter;
  final videoViews = <Future<void> Function()>{};
  bool videoSuspended = false;

  Future<void> _pauseVideo() async {
    videoSuspended = true;
    _changed();
    await Future.wait(videoViews.toList().map((release) => release()));
  }

  void _resumeVideo() {
    videoSuspended = false;
    _changed();
  }

  bool get joined => participantId != null;
  bool get microphone => _captures.containsKey('audio');
  bool get camera => _captures.containsKey('video');
  MediaStream? get localVideo => _captures['video'];
  List<VoiceParticipant> get participants =>
      room?.participants.where((p) => p.channelId == channelId).toList() ?? [];

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _error(Object exception) {
    if (_disposed) return;
    final text = exception.toString();
    error =
        RegExp(
          'permission|NotAllowed|denied',
          caseSensitive: false,
        ).hasMatch(text)
        ? 'Chưa được cấp quyền mic/camera. Hãy cho phép trong cài đặt ứng dụng rồi thử lại.'
        : RegExp(
            'NotFound|NotReadable|devices|camera.*open',
            caseSensitive: false,
          ).hasMatch(text)
        ? 'Không thể mở mic/camera. Hãy kiểm tra thiết bị và thử lại.'
        : exception is PlatformException || text.contains('RTCPeerConnection')
        ? 'Không thể thiết lập kết nối âm thanh/video. Hãy kiểm tra mạng và vào lại phòng.'
        : text.contains('Exception:')
        ? text.substring(text.indexOf('Exception:') + 10).trim()
        : text;
    _changed();
  }

  Future<void> connect() async {
    if (_disposed || connecting || connected) return;
    connecting = true;
    error = null;
    _changed();
    try {
      final snapshot = await connection.connect();
      if (_disposed) return;
      connected = true;
      _applyRoom(snapshot);
    } catch (exception) {
      _error(exception);
    } finally {
      connecting = false;
      _changed();
    }
  }

  void _applyRoom(VoiceRoom snapshot) {
    if (_disposed || snapshot.version < (room?.version ?? -1)) return;
    room = snapshot;
    if (joined && !participants.any((p) => p.id == participantId)) {
      unawaited(leave(message: 'Bạn đã rời phòng voice. Hãy tham gia lại.'));
      return;
    }
    if (joined) _reconcile();
    _changed();
  }

  Future<void> join(int id) async {
    if (_disposed || !connected || joining || channelId == id) return;
    joining = true;
    error = null;
    final epoch = ++_epoch;
    _changed();
    final operation = _operations.then((_) async {
      try {
        if (joined) {
          await _release();
          await connection.leave();
        }
        await _cleanup;
        if (_disposed || epoch != _epoch) return;
        // Android's shared audio engine must be initialized after permission.
        await devices.prepare();
        if (_disposed || epoch != _epoch) return;
        final result = await connection.join(id);
        if (_disposed || epoch != _epoch) {
          await connection.leave();
          return;
        }
        participantId = result.participantId;
        channelId = result.channelId;
        _configuration = result.configuration;
        if ((room?.version ?? -1) <= result.room.version) room = result.room;
        joining = false;
        if (!participants.any((p) => p.id == participantId)) {
          await _release();
          await connection.leave();
          return;
        }
        _reconcile();
        for (final (sender, signal) in _pendingSignals) {
          _receive(sender, signal);
        }
        _pendingSignals.clear();
        try {
          await devices.speaker(speakerEnabled);
        } catch (_) {
          /* Device may have no speaker route. */
        }
        if (_disposed || epoch != _epoch || !joined) return;
        _meter = Timer.periodic(
          const Duration(milliseconds: 300),
          (_) => _sample(),
        );
      } catch (exception) {
        if (epoch == _epoch) {
          await _release();
          _error(exception);
        }
        try {
          await connection.leave();
        } catch (_) {
          /* Disconnect removes membership. */
        }
      } finally {
        joining = false;
        _changed();
      }
    });
    _operations = operation.catchError(_error);
    await _operations;
  }

  Map<String, dynamic> _configuration = {};
  void _reconcile() {
    final others = participants.where((p) => p.id != participantId).toList();
    for (final id in peers.keys.toList()) {
      if (!others.any((p) => p.id == id)) {
        unawaited(peers.remove(id)!.close().catchError(_error));
        streams.remove(id);
        states.remove(id);
        levels.remove(id);
      }
    }
    final epoch = _epoch;
    for (final member in others) {
      if (peers.containsKey(member.id)) continue;
      final peer = peerFactory(
        localId: participantId!,
        remoteId: member.id,
        configuration: _configuration,
        send: (signal) async {
          if (!_disposed && joined && epoch == _epoch) {
            await connection.signal(member.id, signal);
          }
        },
        onStream: (stream) {
          if (epoch == _epoch && joined) {
            streams[member.id] = stream;
            _changed();
          }
        },
        onState: (state) {
          if (epoch != _epoch || !joined) return;
          states[member.id] = state;
          if (state == 'failed') {
            error =
                'Không thể kết nối với ${member.name}. Hãy kiểm tra mạng và vào lại phòng.';
          }
          _changed();
        },
        onError: (exception) {
          if (epoch == _epoch) _error(exception);
        },
      );
      peers[member.id] = peer;
      for (final kind in ['audio', 'video']) {
        unawaited(
          peer
              .setTrack(kind, _captures[kind]?.getTracks().firstOrNull)
              .catchError(_error),
        );
      }
    }
  }

  void _receive(String id, Map<String, dynamic> signal) {
    if (_disposed ||
        !joined ||
        !participants.any((p) => p.id == id && id != participantId)) {
      return;
    }
    _reconcile();
    unawaited(peers[id]!.receive(signal).catchError(_error));
  }

  Future<void> toggle(String kind) async {
    if (!joined || mediaBusy || _disposed) return;
    final epoch = _epoch;
    mediaBusy = true;
    error = null;
    _changed();
    MediaStream? capture;
    bool mediaChanged = false;
    try {
      if (kind == 'video') await _pauseVideo();
      if (_disposed || epoch != _epoch || !joined) return;
      final previous = _captures.remove(kind);
      if (previous != null) {
        mediaChanged = true;
        // Stop capture immediately even if a network update fails.
        for (final track in previous.getTracks()) {
          await track.stop();
        }
        try {
          await Future.wait(peers.values.map((p) => p.setTrack(kind, null)));
        } finally {
          await previous.dispose();
        }
      } else {
        capture = await devices.capture(kind);
        if (_disposed || epoch != _epoch || !joined) {
          await _stop(capture);
          return;
        }
        final track = capture.getTracks().firstOrNull;
        if (track == null) throw StateError('Không tìm thấy mic/camera.');
        _captures[kind] = capture;
        if (kind == 'video') frontCamera = true;
        mediaChanged = true;
        await Future.wait(peers.values.map((p) => p.setTrack(kind, track)));
      }
      if (epoch == _epoch && joined) {
        await connection.setMedia(microphone, camera);
      }
    } catch (exception) {
      if (capture != null) {
        if (_captures[kind] == capture) _captures.remove(kind);
        await _stop(capture);
        if (epoch == _epoch) {
          await Future.wait(
            peers.values.map(
              (p) => p.setTrack(kind, null).catchError((Object _) {}),
            ),
          );
        }
      }
      if (epoch == _epoch) {
        _error(exception);
        // A lost acknowledgement may leave the server's media flags stale.
        if (mediaChanged) unawaited(leave(message: error));
      }
    } finally {
      if (kind == 'video') _resumeVideo();
      mediaBusy = false;
      _changed();
    }
  }

  Future<void> toggleSpeaker() async {
    if (!joined || mediaBusy) return;
    mediaBusy = true;
    _changed();
    try {
      await devices.speaker(!speakerEnabled);
      speakerEnabled = !speakerEnabled;
      _changed();
    } catch (exception) {
      _error(exception);
    } finally {
      mediaBusy = false;
      _changed();
    }
  }

  Future<void> switchCamera() async {
    final track = localVideo?.getVideoTracks().firstOrNull;
    if (track == null || mediaBusy) return;
    mediaBusy = true;
    final epoch = _epoch;
    _changed();
    try {
      await _pauseVideo();
      if (_disposed || epoch != _epoch || !joined) return;
      await devices.switchCamera(track);
      if (epoch == _epoch) frontCamera = !frontCamera;
    } catch (exception) {
      _error(exception);
    } finally {
      _resumeVideo();
      mediaBusy = false;
      _changed();
    }
  }

  Future<void> _sample() async {
    if (_sampling || !joined) return;
    _sampling = true;
    final epoch = _epoch;
    final sampled = <String, double>{};
    try {
      for (final entry in peers.entries.toList()) {
        for (final stat in await entry.value.stats()) {
          final value = stat.values['audioLevel'];
          if (value is! num) continue;
          final id = stat.type == 'inbound-rtp'
              ? entry.key
              : stat.type == 'media-source'
              ? participantId
              : null;
          if (id != null) {
            sampled[id] = math.max(sampled[id] ?? 0, value.toDouble());
          }
        }
      }
      if (epoch == _epoch && joined) {
        final nextLevels = <String, double>{};
        for (final member in participants) {
          nextLevels[member.id] = member.microphone
              ? (sampled[member.id] ?? 0)
              : 0;
        }
        if (!mapEquals(levels, nextLevels)) {
          levels
            ..clear()
            ..addAll(nextLevels);
          _changed();
        }
      }
    } catch (_) {
      /* Metering must not interrupt a call. */
    } finally {
      _sampling = false;
    }
  }

  Future<void> _stop(MediaStream stream) async {
    try {
      await Future.wait(stream.getTracks().map((track) => track.stop()));
    } finally {
      await stream.dispose();
    }
  }

  Future<void> _release() {
    _meter?.cancel();
    _meter = null;
    participantId = null;
    channelId = null;
    final calls = peers.values.toList(), captures = _captures.values.toList();
    peers.clear();
    _captures.clear();
    streams.clear();
    states.clear();
    levels.clear();
    _pendingSignals.clear();
    _changed();
    _cleanup = _cleanup
        .then((_) async {
          try {
            await _pauseVideo();
            await Future.wait(calls.map((peer) => peer.close()));
          } finally {
            try {
              await Future.wait(captures.map(_stop));
            } finally {
              _resumeVideo();
            }
          }
        })
        .catchError((Object _) {});
    return _cleanup;
  }

  Future<void> leave({String? message}) async {
    ++_epoch;
    error = message;
    final release = _release();
    final operation = _operations.then((_) async {
      await release;
      try {
        await connection.leave();
      } catch (_) {
        /* Disconnect removes membership. */
      }
    });
    _operations = operation;
    await operation;
  }

  /// shortcut: foreground calls only; add platform call services before supporting background capture.
  void background() {
    if (joined || joining) {
      unawaited(
        leave(
          message: 'Cuộc gọi đã kết thúc khi ứng dụng xuống nền. Bạn có thể tham gia lại.',
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(leave().whenComplete(connection.close).catchError((Object _) {}));
    super.dispose();
  }
}
