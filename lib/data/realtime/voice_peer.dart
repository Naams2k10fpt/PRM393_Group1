import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef VoicePeerFactory = VoicePeer Function({
  required String localId,
  required String remoteId,
  required Map<String, dynamic> configuration,
  required Future<void> Function(Map<String, dynamic>) send,
  required void Function(MediaStream) onStream,
  required void Function(String) onState,
  required void Function(Object) onError,
});

abstract class VoicePeer {
  Future<void> setTrack(String kind, MediaStreamTrack? track);
  Future<void> receive(Map<String, dynamic> signal);
  Future<List<StatsReport>> stats();
  Future<void> close();
}

/// Mirrors the web peer's elected initiator and perfect negotiation contract.
class WebRtcVoicePeer implements VoicePeer {
  WebRtcVoicePeer({
    required String localId,
    required String remoteId,
    required Map<String, dynamic> configuration,
    required this.send,
    required this.onStream,
    required this.onState,
    required this.onError,
    Future<RTCPeerConnection> Function(Map<String, dynamic>)? createConnection,
    Future<MediaStream> Function(String)? createStream,
  }) : polite = localId.compareTo(remoteId) > 0 {
    _ready = _start(
      configuration,
      createConnection ?? createPeerConnection,
      createStream ?? createLocalMediaStream,
    );
  }
  final bool polite;
  final Future<void> Function(Map<String, dynamic>) send;
  final void Function(MediaStream) onStream;
  final void Function(String) onState;
  final void Function(Object) onError;
  late final Future<void> _ready;
  Future<void> _queue = Future.value();
  RTCPeerConnection? _pc;
  MediaStream? _stream;
  bool _closed = false, _ignoreOffer = false, _hasRemote = false;
  int _restarts = 0;
  final _senders = <String, RTCRtpSender>{};
  final _tracks = <String, MediaStreamTrack?>{'audio': null, 'video': null};
  final _candidates = <RTCIceCandidate>[];

  Future<void> _start(
    Map<String, dynamic> configuration,
    Future<RTCPeerConnection> Function(Map<String, dynamic>) createConnection,
    Future<MediaStream> Function(String) createStream,
  ) async {
    final pc = _pc = await createConnection(configuration);
    if (_closed) {
      await pc.close();
      return;
    }
    _stream = await createStream('voice-remote');
    if (_closed) {
      await _stream?.dispose();
      await pc.close();
      return;
    }
    pc.onIceCandidate = (candidate) {
      if (!_closed && candidate.candidate?.isNotEmpty == true) {
        unawaited(
          send({'type': 'ice', 'candidate': candidate.toMap()})
              .catchError(_fail),
        );
      }
    };
    pc.onTrack = (event) {
      unawaited(_addRemoteTrack(event.track).catchError(_fail));
    };
    pc.onConnectionState = (state) {
      if (_closed) return;
      final name = state.name
          .replaceFirst('RTCPeerConnectionState', '')
          .toLowerCase();
      onState(name);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed &&
          _restarts++ == 0) {
        unawaited(pc.restartIce().catchError(_fail));
      }
    };
    if (!polite) {
      for (final kind in ['audio', 'video']) {
        final transceiver = await pc.addTransceiver(
          kind: kind == 'audio'
              ? RTCRtpMediaType.RTCRtpMediaTypeAudio
              : RTCRtpMediaType.RTCRtpMediaTypeVideo,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
        );
        _senders[kind] = transceiver.sender;
      }
    }
    pc.onRenegotiationNeeded = () {
      unawaited(_enqueue(_offer).catchError(_fail));
    };
    if (!polite) scheduleMicrotask(() => _enqueue(_offer).catchError(_fail));
  }

  Future<void> _addRemoteTrack(MediaStreamTrack track) async {
    final stream = _stream;
    if (_closed || stream == null) return;
    if (stream.getTrackById(track.id!) == null) await stream.addTrack(track);
    if (!_closed) onStream(stream);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _queue.then((_) async {
      await _ready;
      if (!_closed) await action();
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _offer() async {
    final pc = _pc!;
    if ((polite && !_hasRemote) ||
        await pc.getSignalingState() !=
            RTCSignalingState.RTCSignalingStateStable) {
      return;
    }
    final offer = await pc.createOffer();
    if (_closed) return;
    await pc.setLocalDescription(offer);
    if (!_closed) await send({'type': offer.type, 'sdp': offer.sdp});
  }

  @override
  Future<void> setTrack(String kind, MediaStreamTrack? track) =>
      _enqueue(() async {
        _tracks[kind] = track;
        final sender = _senders[kind];
        if (sender != null) await _replace(sender, kind, track);
      });
  Future<void> _replace(
    RTCRtpSender sender,
    String kind,
    MediaStreamTrack? track,
  ) async {
    await sender.replaceTrack(track);
    if (kind == 'video' && track != null && !_closed) {
      final parameters = sender.parameters;
      for (final encoding in parameters.encodings ?? <RTCRtpEncoding>[]) {
        encoding.maxBitrate = 750000;
        encoding.maxFramerate = 24;
      }
      try {
        await sender.setParameters(parameters);
      } catch (_) {
        /* Optional encoder cap. */
      }
    }
  }

  @override
  Future<void> receive(Map<String, dynamic> signal) => _enqueue(() async {
    final pc = _pc!, type = signal['type'];
    if (type == 'offer' || type == 'answer') {
      final collision =
          type == 'offer' &&
          await pc.getSignalingState() !=
              RTCSignalingState.RTCSignalingStateStable;
      _ignoreOffer = !polite && collision;
      if (_ignoreOffer) {
        _candidates.clear();
        return;
      }
      if (collision) {
        await pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
      }
      await pc.setRemoteDescription(
        RTCSessionDescription(signal['sdp'] as String, type as String),
      );
      _hasRemote = true;
      if (_closed) return;
      for (final candidate in _candidates) {
        await pc.addCandidate(candidate);
      }
      _candidates.clear();
      if (type == 'offer') {
        for (final transceiver in await pc.getTransceivers()) {
          final kind = transceiver.receiver.track?.kind;
          if (kind != null && !_senders.containsKey(kind)) {
            _senders[kind] = transceiver.sender;
            await transceiver.setDirection(TransceiverDirection.SendRecv);
            await _replace(transceiver.sender, kind, _tracks[kind]);
          }
        }
        final answer = await pc.createAnswer();
        if (_closed) return;
        await pc.setLocalDescription(answer);
        if (!_closed) await send({'type': answer.type, 'sdp': answer.sdp});
      }
    } else if (type == 'ice' && !_ignoreOffer) {
      final data = Map<String, dynamic>.from(signal['candidate'] as Map);
      final candidate = RTCIceCandidate(
        data['candidate'] as String?,
        data['sdpMid'] as String?,
        data['sdpMLineIndex'] as int?,
      );
      if (!_hasRemote) {
        if (_candidates.length >= 128) {
          throw StateError('Quá nhiều tín hiệu kết nối.');
        }
        _candidates.add(candidate);
      } else {
        try {
          await pc.addCandidate(candidate);
        } catch (_) {
          /* Expired or duplicate ICE. */
        }
      }
    }
  });
  void _fail(Object error) {
    if (!_closed) onError(error);
  }

  @override
  Future<List<StatsReport>> stats() async {
    await _ready;
    return _closed ? [] : _pc!.getStats();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _candidates.clear();
    try {
      await _ready;
    } catch (_) {
      return;
    }
    final pc = _pc;
    if (pc != null) {
      pc.onTrack = null;
      pc.onIceCandidate = null;
      pc.onRenegotiationNeeded = null;
      pc.onConnectionState = null;
      try {
        await pc.close();
      } finally {
        try {
          await pc.dispose();
        } finally {
          await _stream?.dispose();
        }
      }
    } else {
      await _stream?.dispose();
    }
  }
}
