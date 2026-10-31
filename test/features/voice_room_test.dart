import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:quiz_management_mobile/data/models/voice_room.dart';
import 'package:quiz_management_mobile/data/realtime/voice_connection.dart';
import 'package:quiz_management_mobile/data/realtime/voice_peer.dart';
import 'package:quiz_management_mobile/features/chat/voice_room_controller.dart';

Map<String, dynamic> member(String id, {int channel = 2, bool mic = false}) => {
  'connectionId': id,
  'userId': id,
  'displayName': id,
  'channelId': channel,
  'microphoneEnabled': mic,
  'cameraEnabled': false,
};
VoiceRoom room(int version, List<Map<String, dynamic>> people) =>
    VoiceRoom.fromJson({
      'groupId': 1,
      'participants': people,
      'maxParticipants': 6,
      'version': version,
    });
VoiceJoin joined(int channel, {String id = 'self', int version = 1}) =>
    VoiceJoin.fromJson({
      'participantId': id,
      'channelId': channel,
      'room': {
        'groupId': 1,
        'participants': [
          member(id, channel: channel),
          member('other', channel: channel),
        ],
        'maxParticipants': 6,
        'version': version,
      },
      'iceServers': [
        {
          'urls': ['stun:example.test'],
        },
      ],
      'relayOnly': false,
    });

class FakeVoiceConnection extends VoiceConnection {
  final calls = <String>[];
  Completer<VoiceJoin>? pendingJoin;
  bool failMedia = false;
  int version = 0;
  @override
  Future<VoiceRoom> connect() async => room(version, []);
  @override
  Future<VoiceJoin> join(int channelId) async {
    calls.add('join:$channelId');
    return pendingJoin?.future ??
        Future.value(joined(channelId, version: ++version));
  }

  @override
  Future<void> leave() async {
    calls.add('leave');
  }

  @override
  Future<void> setMedia(bool microphone, bool camera) async {
    calls.add('media:$microphone:$camera');
    if (failMedia) throw StateError('Lost acknowledgement');
  }

  @override
  Future<void> signal(String target, Map<String, dynamic> signal) async {
    calls.add('signal:$target');
  }

  @override
  Future<void> close() async {
    calls.add('close');
  }
}

class FakeTrack extends MediaStreamTrack {
  FakeTrack(this.kind);
  @override
  final String kind;
  bool stopped = false;
  @override
  String get id => 'test-$kind';
  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStream extends MediaStream {
  FakeStream(String kind)
    : tracks = [FakeTrack(kind)],
      super('capture-$kind', 'local');
  final List<FakeTrack> tracks;
  bool disposed = false;
  @override
  List<MediaStreamTrack> getTracks() => tracks;
  @override
  List<MediaStreamTrack> getAudioTracks() =>
      tracks.where((t) => t.kind == 'audio').toList();
  @override
  List<MediaStreamTrack> getVideoTracks() =>
      tracks.where((t) => t.kind == 'video').toList();
  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDevices extends VoiceDevices {
  final captured = <FakeStream>[];
  Completer<MediaStream>? pending;
  Object? failure;
  Object? prepareFailure;
  Completer<void>? pendingPrepare;
  Completer<void>? pendingSpeaker;
  int speakerCalls = 0;
  @override
  Future<void> prepare() async {
    if (prepareFailure != null) throw prepareFailure!;
    await pendingPrepare?.future;
  }

  @override
  Future<MediaStream> capture(String kind) async {
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    final stream = FakeStream(kind);
    captured.add(stream);
    return stream;
  }

  @override
  Future<void> speaker(bool enabled) async {
    speakerCalls++;
    await pendingSpeaker?.future;
  }

  @override
  Future<void> switchCamera(MediaStreamTrack track) async {}
}

class FakePeer implements VoicePeer {
  final signals = <Map<String, dynamic>>[];
  final tracks = <String, MediaStreamTrack?>{};
  bool closed = false;
  bool failClose = false;
  @override
  Future<void> receive(Map<String, dynamic> signal) async {
    signals.add(signal);
  }

  @override
  Future<void> setTrack(String kind, MediaStreamTrack? track) async {
    tracks[kind] = track;
  }

  @override
  Future<List<StatsReport>> stats() async => [];
  @override
  Future<void> close() async {
    closed = true;
    if (failClose) throw StateError('Peer close failed');
  }
}

Future<
  ({
    VoiceRoomController call,
    FakeVoiceConnection hub,
    FakeDevices devices,
    List<FakePeer> peers,
  })
>
fixture() async {
  final hub = FakeVoiceConnection(),
      devices = FakeDevices(),
      peers = <FakePeer>[];
  final call = VoiceRoomController(
    hub,
    devices: devices,
    peerFactory:
        ({
          required localId,
          required remoteId,
          required configuration,
          required send,
          required onStream,
          required onState,
          required onError,
        }) {
          final peer = FakePeer();
          peers.add(peer);
          return peer;
        },
  );
  addTearDown(() async {
    await call.leave();
    call.dispose();
  });
  await call.connect();
  return (call: call, hub: hub, devices: devices, peers: peers);
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test('rapid speaker taps only change the output route once', () async {
    final f = await fixture();
    await f.call.join(2);
    f.devices.pendingSpeaker = Completer<void>();
    final first = f.call.toggleSpeaker();
    await f.call.toggleSpeaker();
    expect(f.devices.speakerCalls, 2); // Initial room route plus one toggle.
    f.devices.pendingSpeaker!.complete();
    await first;
    expect(f.call.speakerEnabled, isFalse);
    expect(f.call.mediaBusy, isFalse);
  });
  test('camera operations await video release and leave stops capture even if a peer fails to close', () async {
    final f = await fixture();
    await f.call.join(2);
    final released = Completer<void>();
    f.call.videoViews.add(() => released.future);
    final toggle = f.call.toggle('video');
    await flush();
    expect(f.call.videoSuspended, isTrue);
    expect(f.devices.captured, isEmpty);
    released.complete();
    await toggle;
    expect(f.call.videoSuspended, isFalse);
    f.peers.first.failClose = true;
    await f.call.leave();
    expect(f.devices.captured.single.tracks.single.stopped, isTrue);
    expect(f.devices.captured.single.disposed, isTrue);
  });
  test('denied join permission creates no native peers or capture', () async {
    final f = await fixture();
    f.devices.prepareFailure = StateError('Permission denied');
    await f.call.join(2);
    expect(f.call.joined, isFalse);
    expect(f.peers, isEmpty);
    expect(f.devices.captured, isEmpty);
    expect(f.hub.calls, isNot(contains('join:2')));
    expect(f.call.error, contains('cấp quyền'));
  });
  test('leaving during permission request prevents a late join', () async {
    final f = await fixture();
    f.devices.pendingPrepare = Completer<void>();
    final join = f.call.join(2);
    await flush();
    final leave = f.call.leave();
    f.devices.pendingPrepare!.complete();
    await Future.wait([join, leave]);
    expect(f.call.joined, isFalse);
    expect(f.hub.calls, isNot(contains('join:2')));
    expect(f.peers, isEmpty);
  });
  test(
    'rear camera is not mirrored and a new camera starts facing front',
    () async {
      final f = await fixture();
      await f.call.join(2);
      await f.call.toggle('video');
      expect(f.call.frontCamera, isTrue);
      await f.call.switchCamera();
      expect(f.call.frontCamera, isFalse);
      await f.call.toggle('video');
      await f.call.toggle('video');
      expect(f.call.frontCamera, isTrue);
    },
  );
  test('native ICE configuration removes null STUN credentials and preserves TURN settings', () {
    final payload = {
      'participantId': 'self',
      'channelId': 2,
      'room': {
        'groupId': 1,
        'participants': [],
        'maxParticipants': 6,
        'version': 0,
      },
      'iceServers': [
        {
          'urls': ['stun:example.test'],
          'username': null,
          'credential': null,
        },
        {
          'urls': ['turn:relay.test'],
          'username': 'temporary-user',
          'credential': 'temporary-credential',
        },
      ],
      'relayOnly': true,
    };
    final configuration = VoiceJoin.fromJson(payload).configuration;
    final servers = configuration['iceServers'] as List;
    expect(servers.first, {
      'urls': ['stun:example.test'],
    });
    expect(servers.last['username'], 'temporary-user');
    expect(servers.last['credential'], 'temporary-credential');
    expect(configuration['iceTransportPolicy'], 'relay');
  });
  test('joins as listener without asking for devices; toggles publish flags and release capture', () async {
    final f = await fixture();
    await f.call.join(2);
    expect(f.call.joined, isTrue);
    expect(f.devices.captured, isEmpty);
    await f.call.toggle('audio');
    expect(f.call.microphone, isTrue);
    expect(f.hub.calls, contains('media:true:false'));
    expect(
      f.peers.single.tracks['audio'],
      f.devices.captured.single.tracks.single,
    );
    await f.call.toggle('audio');
    expect(f.call.microphone, isFalse);
    expect(f.devices.captured.single.tracks.single.stopped, isTrue);
    expect(f.devices.captured.single.disposed, isTrue);
  });
  test(
    'permission denial keeps listener connected with a readable error',
    () async {
      final f = await fixture();
      await f.call.join(2);
      f.devices.failure = StateError('Permission denied');
      await f.call.toggle('audio');
      expect(f.call.joined, isTrue);
      expect(f.call.microphone, isFalse);
      expect(f.call.error, contains('Chưa được cấp quyền'));
    },
  );
  test('a device granted after leaving is stopped and cannot publish into the next call', () async {
    final f = await fixture();
    await f.call.join(2);
    f.devices.pending = Completer<MediaStream>();
    final enabling = f.call.toggle('video');
    await flush();
    await f.call.leave();
    final late = FakeStream('video');
    f.devices.pending!.complete(late);
    await enabling;
    expect(late.tracks.single.stopped, isTrue);
    expect(late.disposed, isTrue);
    expect(f.hub.calls.where((c) => c.startsWith('media:')), isEmpty);
  });
  test('leaving during Join cancels its acknowledgement and clears server membership', () async {
    final f = await fixture();
    f.hub.pendingJoin = Completer<VoiceJoin>();
    final joining = f.call.join(2);
    await flush();
    final leaving = f.call.leave();
    f.hub.pendingJoin!.complete(joined(2));
    await joining;
    await leaving;
    expect(f.call.joined, isFalse);
    expect(f.peers, isEmpty);
    expect(f.hub.calls, contains('leave'));
  });
  test(
    'double join and channel switches serialize membership changes',
    () async {
      final f = await fixture();
      f.hub.pendingJoin = Completer<VoiceJoin>();
      final first = f.call.join(2);
      await flush();
      await f.call.join(3);
      expect(f.hub.calls, ['join:2']);
      f.hub.pendingJoin!.complete(joined(2));
      await first;
      f.hub.pendingJoin = null;
      await f.call.join(3);
      expect(f.hub.calls, ['join:2', 'leave', 'join:3']);
      expect(f.call.channelId, 3);
    },
  );
  test('signals arriving before Join acknowledgement are delivered only to current room peers', () async {
    final f = await fixture();
    f.hub.pendingJoin = Completer<VoiceJoin>();
    final joining = f.call.join(2);
    await flush();
    f.hub.onSignal!('other', {'type': 'offer', 'sdp': 'v=0'});
    f.hub.onSignal!('intruder', {'type': 'offer', 'sdp': 'v=0'});
    f.hub.pendingJoin!.complete(joined(2));
    await joining;
    await flush();
    expect(f.peers.single.signals.length, 1);
  });
  test('stale snapshots cannot remove the current participant', () async {
    final f = await fixture();
    await f.call.join(2);
    f.hub.onRoom!(room(0, []));
    await flush();
    expect(f.call.joined, isTrue);
    f.hub.onRoom!(room(2, []));
    await flush();
    expect(f.call.joined, isFalse);
  });
  test('reconnecting after a server restart accepts its new snapshot version with devices off', () async {
    final f = await fixture();
    f.hub.version = 20;
    await f.call.join(2);
    await f.call.toggle('audio');
    f.hub.onDisconnected!();
    await flush();
    f.hub.onReconnected!();
    f.hub.version = 0;
    f.hub.onRoom!(room(0, []));
    await f.call.join(2);
    expect(f.call.joined, isTrue);
    expect(f.call.microphone, isFalse);
    expect(f.call.room!.version, 1);
  });
  test(
    'disconnect, revocation and backgrounding stop tracks and close all peers',
    () async {
      for (final action in ['disconnect', 'revoke', 'background']) {
        final f = await fixture();
        await f.call.join(2);
        await f.call.toggle('audio');
        if (action == 'disconnect') {
          f.hub.onDisconnected!();
        } else if (action == 'revoke') {
          f.hub.onAccessRevoked!();
        } else {
          f.call.background();
        }
        await flush();
        expect(f.call.joined, isFalse, reason: action);
        expect(
          f.devices.captured.single.tracks.single.stopped,
          isTrue,
          reason: action,
        );
        expect(f.peers.single.closed, isTrue, reason: action);
      }
    },
  );
  test('a failed media acknowledgement releases devices and leaves the uncertain server session', () async {
    final f = await fixture();
    await f.call.join(2);
    f.hub.failMedia = true;
    await f.call.toggle('video');
    await flush();
    expect(f.call.joined, isFalse);
    expect(f.devices.captured.single.tracks.single.stopped, isTrue);
    expect(f.hub.calls, contains('leave'));
  });
}
