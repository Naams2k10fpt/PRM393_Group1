import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/study_group.dart';
import '../../data/models/voice_room.dart';
import 'voice_room_controller.dart';

class VoiceRoomPanel extends StatelessWidget {
  const VoiceRoomPanel({
    super.key,
    required this.controller,
    required this.channel,
    required this.onChat,
  });
  final VoiceRoomController controller;
  final ChatChannel channel;
  final VoidCallback onChat;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final call = controller,
          inRoom = call.joined && call.channelId == channel.id;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.volume2),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        inRoom
                            ? '${call.participants.length} người trong cuộc gọi'
                            : 'Phòng thoại của nhóm',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onChat,
                  icon: const Icon(LucideIcons.messageCircle),
                  label: const Text('Về chat'),
                ),
              ],
            ),
          ),
          if (call.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  call.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          Expanded(
            child: inRoom
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          MediaQuery.textScalerOf(context).scale(14) > 21
                          ? 1
                          : constraints.maxWidth >= 800
                          ? 3
                          : call.participants.length == 1
                          ? 1
                          : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: columns == 1 ? 4 / 3 : 3 / 4,
                        ),
                        itemCount: call.participants.length,
                        itemBuilder: (context, index) {
                          final member = call.participants[index],
                              local = member.id == call.participantId;
                          return VoiceParticipantTile(
                            key: ValueKey(member.id),
                            member: member,
                            controller: call,
                            local: local,
                            mirror: local && call.frontCamera,
                            stream: call.videoSuspended
                                ? null
                                : local
                                ? call.localVideo
                                : call.streams[member.id],
                            state: local
                                ? 'connected'
                                : call.states[member.id] ?? 'new',
                            level: call.levels[member.id] ?? 0,
                          );
                        },
                      );
                    },
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.headphones,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Cùng học qua giọng nói',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Mic và camera sẽ tắt khi mới vào. Android cần quyền mic để kết nối phòng; bạn tự bật từng thiết bị sau khi tham gia.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (!call.connected)
                            FilledButton.icon(
                              onPressed: call.connecting ? null : call.connect,
                              icon: const Icon(LucideIcons.refreshCw),
                              label: Text(
                                call.connecting
                                    ? 'Đang kết nối…'
                                    : 'Kết nối lại',
                              ),
                            )
                          else
                            FilledButton.icon(
                              onPressed: call.joining
                                  ? null
                                  : () => call.join(channel.id),
                              icon: const Icon(LucideIcons.headphones),
                              label: Text(
                                call.joining
                                    ? 'Đang vào phòng…'
                                    : call.joined
                                    ? 'Chuyển vào phòng này'
                                    : 'Tham gia phòng',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (inRoom)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _control(
                      call.microphone ? 'Tắt mic' : 'Bật mic',
                      call.microphone ? LucideIcons.mic : LucideIcons.micOff,
                      call.mediaBusy ? null : () => call.toggle('audio'),
                      selected: call.microphone,
                    ),
                    _control(
                      call.camera ? 'Tắt camera' : 'Bật camera',
                      call.camera ? LucideIcons.video : LucideIcons.videoOff,
                      call.mediaBusy ? null : () => call.toggle('video'),
                      selected: call.camera,
                    ),
                    IconButton.filledTonal(
                      tooltip: call.speakerEnabled
                          ? 'Chuyển sang loa thoại'
                          : 'Bật loa ngoài',
                      isSelected: call.speakerEnabled,
                      onPressed: call.mediaBusy ? null : call.toggleSpeaker,
                      icon: Icon(
                        call.speakerEnabled
                            ? LucideIcons.volume2
                            : LucideIcons.volume1,
                      ),
                    ),
                    if (call.camera)
                      IconButton.filledTonal(
                        tooltip: 'Đổi camera',
                        onPressed: call.mediaBusy ? null : call.switchCamera,
                        icon: const Icon(LucideIcons.switchCamera),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      onPressed: call.leave,
                      icon: const Icon(LucideIcons.phoneOff),
                      label: const Text('Rời phòng'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  Widget _control(
    String label,
    IconData icon,
    VoidCallback? action, {
    required bool selected,
  }) => Semantics(
    toggled: selected,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
      onPressed: action,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

class VoiceParticipantTile extends StatefulWidget {
  const VoiceParticipantTile({
    super.key,
    required this.member,
    required this.controller,
    required this.local,
    required this.mirror,
    required this.stream,
    required this.state,
    required this.level,
  });
  final VoiceParticipant member;
  final VoiceRoomController controller;
  final bool local;
  final bool mirror;
  final MediaStream? stream;
  final String state;
  final double level;
  @override
  State<VoiceParticipantTile> createState() => _VoiceParticipantTileState();
}

class _VoiceParticipantTileState extends State<VoiceParticipantTile> {
  RTCVideoRenderer? _renderer;
  Future<void>? _rendererReady;
  Future<void> _renderCleanup = Future.value();
  int _binding = 0;
  bool _videoError = false;
  String? _videoId;
  @override
  void initState() {
    super.initState();
    widget.controller.videoViews.add(_releaseRenderer);
    unawaited(_bind());
  }

  @override
  void didUpdateWidget(covariant VoiceParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream ||
        oldWidget.member.camera != widget.member.camera ||
        _videoId != widget.stream?.getVideoTracks().firstOrNull?.id) {
      unawaited(_bind());
    }
  }

  Future<void> _bind() async {
    final generation = ++_binding;
    await _renderCleanup;
    if (!mounted || generation != _binding) return;
    if (widget.controller.videoSuspended) return;
    final hasVideo =
        widget.member.camera &&
        widget.stream?.getVideoTracks().isNotEmpty == true;
    if (!hasVideo) {
      await _releaseRenderer();
      return;
    }
    try {
      if (_renderer == null) {
        _renderer = RTCVideoRenderer();
        _rendererReady = _renderer!.initialize();
      }
      await _rendererReady;
      if (!mounted ||
          generation != _binding ||
          widget.controller.videoSuspended ||
          _renderer == null) {
        return;
      }
      // Local preview contains video only. Native renderers reject muting remote tracks.
      final stream =
          widget.member.camera &&
              widget.stream?.getVideoTracks().isNotEmpty == true
          ? widget.stream
          : null;
      _renderer!.srcObject = stream;
      _videoId = stream?.getVideoTracks().firstOrNull?.id;
      setState(() => _videoError = false);
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  @override
  void dispose() {
    unawaited(
      _releaseRenderer().whenComplete(
        () => widget.controller.videoViews.remove(_releaseRenderer),
      ),
    );
    super.dispose();
  }

  Future<void> _releaseRenderer() {
    ++_binding;
    final renderer = _renderer;
    _renderer = null;
    if (renderer != null) {
      final ready = _rendererReady;
      _renderCleanup = _renderCleanup.then((_) async {
        try {
          await ready;
          await renderer.dispose();
          await widget.controller.devices.videoReleased();
        } catch (_) {
          /* Capture cleanup must continue if rendering failed. */
        }
      });
    }
    return _renderCleanup;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme, member = widget.member;
    final speaking = member.microphone && widget.level >= .018;
    final level = (widget.level / .12).clamp(0.0, 1.0);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 120),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: speaking ? const Color(0xff34d399) : colors.outlineVariant,
          width: speaking
              ? reduced
                    ? 3
                    : 2 + level * 2
              : 1,
        ),
        boxShadow: speaking && !reduced
            ? [
                BoxShadow(
                  color: const Color(0x5534d399),
                  blurRadius: 4 + level * 10,
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_videoError &&
                member.camera &&
                _renderer?.textureId != null &&
                widget.stream != null)
              RTCVideoView(
                _renderer!,
                mirror: widget.mirror,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Center(
                child: CircleAvatar(
                  radius: 28,
                  child: Text(
                    member.name.characters.firstOrNull?.toUpperCase() ?? '?',
                  ),
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${member.name}${widget.local ? ' (Bạn)' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Icon(
                        member.microphone
                            ? LucideIcons.mic
                            : LucideIcons.micOff,
                        size: 16,
                        color: member.microphone
                            ? Colors.white
                            : Colors.white60,
                        semanticLabel: member.microphone
                            ? 'Mic bật'
                            : 'Mic tắt',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.local && widget.state != 'connected')
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Text(
                  widget.state == 'failed' ? 'Mất kết nối' : 'Đang nối…',
                  style: const TextStyle(
                    color: Colors.white,
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
