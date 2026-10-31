import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:quiz_management_mobile/data/realtime/voice_peer.dart';

import '../features/voice_room_test.dart' show FakeTrack, FakeStream;

class Sender extends RTCRtpSender {
  MediaStreamTrack? published;
  bool fail = false;
  @override
  Future<void> replaceTrack(MediaStreamTrack? track) async {
    if (fail) throw StateError('Cannot replace');
    published = track;
  }

  @override
  RTCRtpParameters get parameters => RTCRtpParameters(encodings: []);
  @override
  Future<bool> setParameters(RTCRtpParameters parameters) async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Receiver extends RTCRtpReceiver {
  Receiver(this.track);
  @override
  final MediaStreamTrack track;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Transceiver extends RTCRtpTransceiver {
  Transceiver(String kind) : receiver = Receiver(FakeTrack(kind));
  @override
  final Sender sender = Sender();
  @override
  final Receiver receiver;
  @override
  Future<void> setDirection(TransceiverDirection direction) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PeerConnection extends RTCPeerConnection {
  final sections = <Transceiver>[];
  final candidates = <RTCIceCandidate>[];
  final localTypes = <String?>[];
  int closes = 0, restarts = 0;
  RTCSignalingState state = RTCSignalingState.RTCSignalingStateStable;
  @override
  Future<RTCSignalingState?> getSignalingState() async => state;
  @override
  Future<RTCRtpTransceiver> addTransceiver({
    MediaStreamTrack? track,
    RTCRtpMediaType? kind,
    RTCRtpTransceiverInit? init,
  }) async {
    final transceiver = Transceiver(
      kind == RTCRtpMediaType.RTCRtpMediaTypeAudio ? 'audio' : 'video',
    );
    sections.add(transceiver);
    return transceiver;
  }

  @override
  Future<List<RTCRtpTransceiver>> getTransceivers() async => sections;
  @override
  Future<RTCSessionDescription> createOffer([
    Map<String, dynamic>? constraints,
  ]) async => RTCSessionDescription('v=0', 'offer');
  @override
  Future<RTCSessionDescription> createAnswer([
    Map<String, dynamic>? constraints,
  ]) async => RTCSessionDescription('v=0', 'answer');
  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {
    localTypes.add(description.type);
    state = description.type == 'offer'
        ? RTCSignalingState.RTCSignalingStateHaveLocalOffer
        : RTCSignalingState.RTCSignalingStateStable;
  }

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (description.type == 'offer' && sections.isEmpty) {
      sections.addAll([Transceiver('audio'), Transceiver('video')]);
    }
    state = description.type == 'offer'
        ? RTCSignalingState.RTCSignalingStateHaveRemoteOffer
        : RTCSignalingState.RTCSignalingStateStable;
  }

  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {
    candidates.add(candidate);
  }

  @override
  Future<void> restartIce() async {
    restarts++;
  }

  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<
    ({
      WebRtcVoicePeer peer,
      PeerConnection pc,
      List<Map<String, dynamic>> signals,
      List<Object> errors,
    })
  >
  fixture(bool polite) async {
    final pc = PeerConnection(),
        signals = <Map<String, dynamic>>[],
        errors = <Object>[];
    final peer = WebRtcVoicePeer(
      localId: polite ? 'z' : 'a',
      remoteId: polite ? 'a' : 'z',
      configuration: {},
      send: (signal) async {
        signals.add(signal);
      },
      onStream: (_) {},
      onState: (_) {},
      onError: errors.add,
      createConnection: (_) async => pc,
      createStream: (_) async => FakeStream('video'),
    );
    addTearDown(peer.close);
    await Future<void>.delayed(Duration.zero);
    return (peer: peer, pc: pc, signals: signals, errors: errors);
  }

  test('only elected initiator reserves two sections and offers; answerer reuses remote sections', () async {
    final caller = await fixture(false), answerer = await fixture(true);
    expect(caller.pc.sections.length, 2);
    expect(caller.signals.first['type'], 'offer');
    expect(answerer.pc.sections, isEmpty);
    expect(answerer.signals, isEmpty);
    final mic = FakeTrack('audio');
    await answerer.peer.setTrack('audio', mic);
    await answerer.peer.receive({'type': 'offer', 'sdp': 'v=0'});
    expect(answerer.pc.sections.length, 2);
    expect(answerer.pc.sections.first.sender.published, mic);
    expect(answerer.signals.single['type'], 'answer');
  });
  test('early ICE waits for SDP and excessive candidates are bounded without poisoning the queue', () async {
    final f = await fixture(true);
    for (var i = 0; i < 128; i++) {
      await f.peer.receive({
        'type': 'ice',
        'candidate': {
          'candidate': 'candidate:$i',
          'sdpMid': '0',
          'sdpMLineIndex': 0,
        },
      });
    }
    expect(f.pc.candidates, isEmpty);
    await expectLater(
      f.peer.receive({
        'type': 'ice',
        'candidate': {'candidate': 'overflow'},
      }),
      throwsStateError,
    );
    await f.peer.receive({'type': 'offer', 'sdp': 'v=0'});
    expect(f.pc.candidates.length, 128);
    expect(f.signals.single['type'], 'answer');
  });
  test('polite collision rolls back, while the initiator ignores a colliding offer', () async {
    final polite = await fixture(true), impolite = await fixture(false);
    polite.pc.state = RTCSignalingState.RTCSignalingStateHaveLocalOffer;
    await polite.peer.receive({'type': 'offer', 'sdp': 'v=0'});
    expect(polite.pc.localTypes, ['rollback', 'answer']);
    await impolite.peer.receive({'type': 'offer', 'sdp': 'v=0'});
    expect(impolite.signals.length, 1);
    expect(impolite.pc.localTypes, ['offer']);
  });
  test('failed track publication propagates and closing a peer never stops shared capture tracks', () async {
    final f = await fixture(false), mic = FakeTrack('audio');
    await f.peer.setTrack('audio', mic);
    f.pc.sections.first.sender.fail = true;
    await expectLater(f.peer.setTrack('audio', null), throwsStateError);
    await f.peer.close();
    await f.peer.close();
    expect(mic.stopped, isFalse);
    expect(f.pc.closes, 1);
  });
}
