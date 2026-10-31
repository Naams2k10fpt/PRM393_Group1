import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../data/api/api_exception.dart';
import '../../data/realtime/chat_connection.dart';
import '../../data/repositories/groups_repository.dart';
import '../auth/auth_controller.dart';
import 'group_details_screen.dart';
import 'chat_message_tile.dart';
import 'voice_room_controller.dart';
import 'voice_room_panel.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key, required this.group});
  final StudyGroup group;
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  late final repo = context.read<GroupsRepository>();
  late final userId = context.read<AuthController>().user!.id;
  final input = TextEditingController();
  final scroll = ScrollController();
  ChatConnection? hub;
  List<ChatChannel> channels = [];
  ChatChannel? channel;
  List<ChatChannel> voiceChannels = [];
  ChatChannel? voiceChannel;
  late final voice = VoiceRoomController(repo.openVoice(widget.group.id));
  final messages = <ChatMessage>[];
  List<ChatUpload> files = [];
  ChatMessage? reply;
  String? nonce, error;
  bool loading = true, loadingOlder = false, hasOlder = true;
  bool connecting = false, sending = false, foreground = true;
  int timelineVersion = 0, newMessages = 0, role = 0, lastReadSent = 0;
  final connected = ValueNotifier(false);
  final roster = ValueNotifier<List<GroupMember>>([]);
  final online = ValueNotifier<Set<String>>({});
  final website = ValueNotifier<Set<String>>({});
  final drafts =
      <
        int,
        ({
          String text,
          List<ChatUpload> files,
          ChatMessage? reply,
          String? nonce,
        })
      >{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scroll.addListener(_onScroll);
    _open();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached) {
      voice.background();
    }
    if (foreground && connected.value) {
      unawaited(_refresh().catchError(_showError));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(hub?.close().catchError((Object _) {}));
    voice.dispose();
    input.dispose();
    scroll.dispose();
    roster.dispose();
    online.dispose();
    website.dispose();
    connected.dispose();
    super.dispose();
  }

  bool get nearBottom =>
      !scroll.hasClients ||
      scroll.position.maxScrollExtent - scroll.offset < 120;
  void _onScroll() {
    if (nearBottom) _markRead();
  }

  Future<void> _open() async {
    if (connecting) return;
    setState(() {
      connecting = true;
      connected.value = false;
      error = null;
    });
    try {
      await hub?.close();
      if (!mounted) return;
      final connection = repo.openChat(widget.group.id);
      hub = connection;
      connection.onMessage = _receive;
      connection.onMessageUpdated = (message) {
        _merge([message], updatesOnly: true);
      };
      connection.onChannelsChanged = _loadChannels;
      connection.onAccessRevoked = () {
        if (!mounted) return;
        unawaited(voice.leave());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn không còn quyền vào nhóm.')),
        );
        final room = ModalRoute.of(context);
        final navigator = Navigator.of(context);
        navigator.popUntil((route) => route == room);
        navigator.pop();
      };
      connection.onRoster = (members) {
        if (!mounted) return;
        roster.value = members;
        setState(
          () =>
              role =
                  members
                      .where((member) => member.userId == userId)
                      .firstOrNull
                      ?.role ??
                  role,
        );
      };
      connection.onPresence = (ids) {
        if (mounted) online.value = ids;
      };
      connection.onWebsitePresence = (ids) {
        if (mounted) website.value = ids;
      };
      connection.onDisconnected = () {
        if (!mounted) return;
        online.value = {};
        website.value = {};
        setState(() => connected.value = false);
      };
      connection.onError = _showError;
      connection.onReconnected = () async {
        await _loadChannels();
        await _refresh();
        if (mounted) {
          setState(() {
            connected.value = true;
            error = null;
          });
        }
      };
      await connection.connect();
      if (!mounted) return;
      final details = await repo.details(widget.group.id);
      if (!mounted) return;
      role = details.myRole;
      await _loadChannels();
      if (mounted) setState(() => connected.value = true);
    } catch (exception) {
      _showError(exception);
    } finally {
      if (mounted) {
        setState(() {
          connecting = false;
          loading = false;
        });
      }
    }
  }

  Future<void> _loadChannels() async {
    final loaded = await repo.channels(widget.group.id);
    final loadedVoice = await repo.voiceChannels(widget.group.id);
    if (!mounted) return;
    setState(() {
      voiceChannels = loadedVoice;
      voiceChannel = loadedVoice
          .where((item) => item.id == voiceChannel?.id)
          .firstOrNull;
    });
    if (voice.channelId != null &&
        !loadedVoice.any((item) => item.id == voice.channelId)) {
      unawaited(voice.leave(message: 'Kênh voice đã được lưu trữ.'));
    }
    if (loadedVoice.isNotEmpty) unawaited(voice.connect());
    final current = loaded.where((item) => item.id == channel?.id).firstOrNull;
    setState(() => channels = loaded);
    if (current == null && loaded.isNotEmpty) {
      await _selectChannel(loaded.first, force: true);
    } else if (current != null) {
      setState(() => channel = current);
    }
  }

  Future<void> _selectChannel(
    ChatChannel selected, {
    bool force = false,
  }) async {
    if ((!force && sending) || selected.id == channel?.id) return;
    if (channel != null) {
      drafts[channel!.id] = (
        text: input.text,
        files: List.of(files),
        reply: reply,
        nonce: nonce,
      );
    }
    final draft = drafts[selected.id];
    input.text = draft?.text ?? '';
    final version = ++timelineVersion;
    setState(() {
      channel = selected;
      messages.clear();
      loading = true;
      error = null;
      files = List.of(draft?.files ?? []);
      reply = draft?.reply;
      nonce = draft?.nonce;
      hasOlder = true;
      newMessages = 0;
      lastReadSent = 0;
    });
    try {
      final loaded = await repo.channelMessages(widget.group.id, selected.id);
      if (!mounted || version != timelineVersion) return;
      _merge(loaded);
      setState(() => hasOlder = loaded.length == 30);
      _scrollBottom();
    } catch (exception) {
      if (version == timelineVersion) _showError(exception);
    } finally {
      if (mounted && version == timelineVersion) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    final active = channel;
    if (active == null) return;
    final version = timelineVersion, stick = nearBottom;
    int? cursor = messages.isEmpty ? null : messages.last.id;
    // Forward paging fills every missed page instead of only the newest 30 messages.
    while (mounted && version == timelineVersion) {
      final page = await repo.channelMessages(
        widget.group.id,
        active.id,
        afterId: cursor,
      );
      if (!mounted || version != timelineVersion) return;
      _merge(page);
      if (cursor == null) setState(() => hasOlder = page.length == 30);
      if (cursor == null || page.length < 30) break;
      final next = page.last.id;
      if (next <= cursor) break;
      cursor = next;
    }
    final firstLoaded = messages.isEmpty ? null : messages.first.id;
    int? before;
    while (mounted && version == timelineVersion) {
      final latest = await repo.channelMessages(
        widget.group.id,
        active.id,
        beforeId: before,
      );
      if (!mounted || version != timelineVersion) return;
      _merge(latest);
      if (latest.isEmpty ||
          firstLoaded == null ||
          latest.first.id <= firstLoaded ||
          (before != null && latest.first.id >= before)) {
        break;
      }
      before = latest.first.id;
    }
    if (stick) _scrollBottom();
  }

  void _merge(Iterable<ChatMessage> incoming, {bool updatesOnly = false}) {
    if (!mounted) return;
    setState(() {
      for (final message in incoming) {
        if (message.channelId != 0 && message.channelId != channel?.id) {
          continue;
        }
        final index = messages.indexWhere((item) => item.id == message.id);
        if (index < 0 && !updatesOnly) {
          messages.add(message);
        } else if (index >= 0 && message.revision >= messages[index].revision) {
          messages[index] = message;
        }
        for (var replyIndex = 0; replyIndex < messages.length; replyIndex++) {
          final child = messages[replyIndex];
          if (child.reply?.id == message.id &&
              child.reply!.revision <= message.revision) {
            messages[replyIndex] = child.withReply(
              ChatReply.fromMessage(message),
            );
          }
        }
      }
      messages.sort((a, b) => a.id.compareTo(b.id));
    });
  }

  void _receive(ChatMessage message) {
    if (!mounted) return;
    if (message.channelId != 0 && message.channelId != channel?.id) {
      if (message.senderUserId != userId && message.kind == 0) {
        setState(() {
          for (final item in channels) {
            if (item.id == message.channelId) item.unreadCount++;
          }
        });
      }
      return;
    }
    final duplicate = messages.any((item) => item.id == message.id),
        stick = nearBottom;
    _merge([message]);
    if (stick) {
      _scrollBottom();
    } else if (!duplicate) {
      setState(() => newMessages++);
    }
  }

  void _markRead() {
    if (!mounted ||
        !foreground ||
        !nearBottom ||
        ModalRoute.of(context)?.isCurrent != true ||
        messages.isEmpty ||
        channel == null) {
      return;
    }
    final last = messages.last.id;
    if (lastReadSent == last) return;
    lastReadSent = last;
    final active = channel!;
    repo
        .readChannel(widget.group.id, active.id, last)
        .then((_) {
          if (mounted && channel?.id == active.id) {
            setState(() {
              active.unreadCount = 0;
              newMessages = 0;
            });
          }
        })
        .catchError((Object _) {
          if (lastReadSent == last) lastReadSent = 0;
        });
  }

  void _scrollBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    _markRead();
  });

  Future<void> _older() async {
    if (loadingOlder || messages.isEmpty || channel == null) return;
    final version = timelineVersion;
    final oldExtent = scroll.hasClients ? scroll.position.maxScrollExtent : 0.0;
    final oldOffset = scroll.hasClients ? scroll.offset : 0.0;
    setState(() => loadingOlder = true);
    try {
      final old = await repo.channelMessages(
        widget.group.id,
        channel!.id,
        beforeId: messages.first.id,
      );
      if (!mounted || version != timelineVersion) return;
      _merge(old);
      setState(() => hasOlder = old.length == 30);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients && version == timelineVersion) {
          scroll.jumpTo(
            (oldOffset + scroll.position.maxScrollExtent - oldExtent).clamp(
              0.0,
              scroll.position.maxScrollExtent,
            ),
          );
        }
      });
    } catch (exception) {
      _showError(exception);
    } finally {
      if (mounted) setState(() => loadingOlder = false);
    }
  }

  static String _newNonce() {
    final random = Random.secure();
    final hex =
        List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _send() async {
    if (channel == null ||
        sending ||
        !connected.value ||
        (input.text.trim().isEmpty && files.isEmpty)) {
      return;
    }
    final active = channel!, text = input.text.trim();
    if (text.length > 2000) return;
    nonce ??= _newNonce();
    setState(() => sending = true);
    try {
      final sent = await repo.sendChannelMessage(
        widget.group.id,
        active.id,
        text,
        nonce!,
        replyToId: reply?.id,
        files: files,
      );
      if (!mounted) return;
      _receive(sent);
      if (input.text.trim() == text) input.clear();
      setState(() {
        files = [];
        reply = null;
        nonce = null;
        drafts.remove(active.id);
        error = null;
      });
      _scrollBottom();
    } catch (exception) {
      _showError(exception);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _pickFiles() async {
    if (sending) return;
    try {
      final picked = await FilePicker.pickFiles(
        allowMultiple: true,
        withReadStream: true,
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'pdf',
          'txt',
          'csv',
          'zip',
          'docx',
          'xlsx',
          'pptx',
        ],
      );
      if (picked == null || !mounted) return;
      if (picked.files.length + files.length > 3) {
        throw const ApiException(
          code: 'file_limit',
          message: 'Tối đa 3 file mỗi tin nhắn.',
        );
      }
      final loaded = <ChatUpload>[];
      for (final file in picked.files) {
        if (file.size < 1 || file.size > 5 * 1024 * 1024) {
          throw const ApiException(
            code: 'file_size',
            message: 'Mỗi file cần từ 1 byte đến 5 MB.',
          );
        }
        final builder = BytesBuilder(copy: false);
        if (file.readStream != null) {
          await for (final part in file.readStream!) {
            if (builder.length + part.length > 5 * 1024 * 1024) {
              throw const ApiException(
                code: 'file_size',
                message: 'File vượt quá 5 MB.',
              );
            }
            builder.add(part);
          }
        } else {
          builder.add(file.bytes ?? await file.xFile.readAsBytes());
        }
        loaded.add(ChatUpload(file.name, builder.takeBytes()));
      }
      if (mounted) {
        setState(() {
          files.addAll(loaded);
          nonce = null;
        });
      }
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<String?> _textDialog(
    String title,
    String initial, {
    int maxLength = 2000,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: maxLength,
              minLines: 1,
              maxLines: 5,
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          Navigator.pop(context, controller.text.trim());
                        }
                      },
                      child: const Text('Lưu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    return value;
  }

  Future<void> _messageAction(ChatMessage message, String action) async {
    if (action == 'reply') {
      setState(() {
        reply = message;
        nonce = null;
      });
      return;
    }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.content));
      return;
    }
    final active = channel;
    if (active == null) return;
    try {
      ChatMessage? updated;
      if (action == 'edit') {
        final text = await _textDialog('Sửa tin nhắn', message.content);
        if (text != null) {
          updated = await repo.editMessage(
            widget.group.id,
            active.id,
            message.id,
            text,
          );
        }
      } else if (action == 'delete') {
        final yes = await _confirm(
          'Xóa tin nhắn?',
          'Nội dung và file đính kèm sẽ bị xóa.',
        );
        if (yes) {
          updated = await repo.deleteMessage(
            widget.group.id,
            active.id,
            message.id,
          );
        }
      } else {
        updated = await repo.react(
          widget.group.id,
          active.id,
          message.id,
          action,
          !message.reactions.any(
            (reaction) => reaction.emoji == action && reaction.userId == userId,
          ),
        );
      }
      if (updated != null) _merge([updated]);
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(title),
              content: Text(text),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Xác nhận'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      ) ==
      true;
  Future<void> _channelAction(String action) async {
    final active = channel;
    try {
      if (action == 'archive' && active != null) {
        if (!await _confirm(
          'Lưu trữ #${active.name}?',
          'Kênh sẽ đóng và lịch sử vẫn được giữ trên hệ thống.',
        )) {
          return;
        }
        await repo.archiveChannel(widget.group.id, active.id);
      } else {
        final name = await _textDialog(
          action == 'create' ? 'Tạo kênh chat' : 'Đổi tên kênh',
          action == 'create' ? '' : active?.name ?? '',
          maxLength: 40,
        );
        if (name == null) return;
        await repo.saveChannel(
          widget.group.id,
          name,
          active?.topic ?? '',
          channelId: action == 'create' ? null : active?.id,
        );
      }
      await _loadChannels();
    } catch (exception) {
      _showError(exception);
    }
  }

  void _showError(Object exception) {
    if (mounted) {
      setState(
        () =>
            error =
                exception is ApiException
                    ? exception.message
                    : 'Không thể thực hiện thao tác. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _details() async {
    final left = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailsScreen(groupId: widget.group.id),
      ),
    );
    if (mounted && left == true) {
      Navigator.pop(context);
    } else if (mounted) {
      _markRead();
    }
  }

  Widget _channelList(BuildContext panelContext) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.name,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              widget.group.description ?? 'Không gian học tập của nhóm',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'KÊNH TRÒ CHUYỆN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (role >= 1)
              IconButton(
                tooltip: 'Tạo kênh',
                onPressed: () => _channelAction('create'),
                icon: const Icon(LucideIcons.plus, size: 20),
              ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (final item in channels)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                selected: voiceChannel == null && item.id == channel?.id,
                selectedTileColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: .5),
                leading: const Icon(LucideIcons.hash),
                title: Text(item.name, overflow: TextOverflow.ellipsis),
                trailing: item.unreadCount > 0
                    ? Badge(label: Text('${item.unreadCount}'))
                    : null,
                onTap: sending
                    ? null
                    : () {
                        if (Scaffold.of(panelContext).isDrawerOpen) {
                          Navigator.pop(panelContext);
                        }
                        _selectChannel(item);
                        setState(() => voiceChannel = null);
                      },
              ),
            if (voiceChannels.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 20, 8, 8),
                child: Text(
                  'KÊNH THOẠI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              for (final item in voiceChannels)
                ListTile(
                  leading: const Icon(LucideIcons.volume2),
                  title: Text(item.name),
                  selected: voiceChannel?.id == item.id,
                  onTap: () {
                    if (Scaffold.of(panelContext).isDrawerOpen) {
                      Navigator.pop(panelContext);
                    }
                    setState(() => voiceChannel = item);
                  },
                ),
            ],
          ],
        ),
      ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(LucideIcons.settings),
        title: const Text('Thông tin nhóm'),
        onTap: _details,
      ),
    ],
  );

  Widget _memberList() => ListenableBuilder(
    listenable: Listenable.merge([roster, online, website, connected]),
    builder:
        (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'THÀNH VIÊN · ${roster.value.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            if (!connected.value)
              const Text('Đang mất kết nối · trạng thái chưa cập nhật'),
            for (final member in roster.value)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 17,
                  backgroundColor:
                      online.value.contains(member.userId)
                          ? Colors.green.withValues(alpha: .2)
                          : null,
                  child: Text(
                    member.username.characters.firstOrNull?.toUpperCase() ??
                        '?',
                  ),
                ),
                title: Text(member.username, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${member.roleLabel} · ${online.value.contains(member.userId)
                      ? 'Trong phòng'
                      : website.value.contains(member.userId)
                      ? 'Chờ trên web'
                      : 'Ngoại tuyến'}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
  );
  void _members() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (_) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: _memberList(),
          ),
        ),
  );

  Widget _timeline() => Column(
    children: [
      if (error != null)
        MaterialBanner(
          content: Text(error!),
          actions: [
            TextButton(
              onPressed: () => setState(() => error = null),
              child: const Text('Đóng'),
            ),
          ],
        ),
      if (!connected.value)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  connecting ? 'Đang kết nối phòng chat...' : 'Đã mất kết nối.',
                ),
              ),
              if (!connecting)
                TextButton(onPressed: _open, child: const Text('Kết nối lại')),
            ],
          ),
        ),
      Expanded(
        child:
            loading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                  children: [
                    ListView(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        if (hasOlder && messages.isNotEmpty)
                          Center(
                            child: TextButton(
                              onPressed: loadingOlder ? null : _older,
                              child: Text(
                                loadingOlder
                                    ? 'Đang tải...'
                                    : 'Tin nhắn cũ hơn',
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                LucideIcons.hash,
                                size: 38,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '#${channel?.name ?? 'chung'}',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              Text(
                                channel?.topic ??
                                    'Bắt đầu cuộc trò chuyện, chia sẻ tài liệu và cùng nhau học tập.',
                              ),
                              if (messages.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text('Chưa có tin nhắn.'),
                                ),
                            ],
                          ),
                        ),
                        for (var i = 0; i < messages.length; i++) ...[
                          if (i == 0 ||
                              DateUtils.dateOnly(
                                    messages[i - 1].sentAt.toLocal(),
                                  ) !=
                                  DateUtils.dateOnly(
                                    messages[i].sentAt.toLocal(),
                                  ))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  MaterialLocalizations.of(
                                    context,
                                  ).formatMediumDate(
                                    messages[i].sentAt.toLocal(),
                                  ),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ),
                          ChatMessageTile(
                            key: ValueKey(messages[i].id),
                            message: messages[i],
                            repo: repo,
                            userId: userId,
                            canModerate: role >= 1,
                            onAction:
                                (action) => _messageAction(messages[i], action),
                          ),
                        ],
                      ],
                    ),
                    if (newMessages > 0)
                      Positioned(
                        bottom: 8,
                        right: 16,
                        child: FilledButton.icon(
                          onPressed: _scrollBottom,
                          icon: const Icon(LucideIcons.arrowDown),
                          label: Text('$newMessages tin mới'),
                        ),
                      ),
                  ],
                ),
      ),
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Column(
            children: [
              if (reply != null)
                Row(
                  children: [
                    const Icon(LucideIcons.share2, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Trả lời ${reply!.senderName}: ${reply!.content}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hủy trả lời',
                      onPressed:
                          sending
                              ? null
                              : () => setState(() {
                                reply = null;
                                nonce = null;
                              }),
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ],
                ),
              if (files.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final file in files)
                      InputChip(
                        label: Text(file.name, overflow: TextOverflow.ellipsis),
                        onDeleted:
                            sending
                                ? null
                                : () => setState(() {
                                  files.remove(file);
                                  nonce = null;
                                }),
                      ),
                  ],
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Đính kèm ảnh/file',
                    onPressed: sending || channel == null ? null : _pickFiles,
                    icon: const Icon(LucideIcons.circlePlus),
                  ),
                  Expanded(
                    child: TextField(
                      controller: input,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Nhắn vào #${channel?.name ?? 'chung'}',
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) {
                        if (!sending) nonce = null;
                      },
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gửi',
                    onPressed:
                        connected.value && channel != null && !sending
                            ? _send
                            : null,
                    icon:
                        sending
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(LucideIcons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          voiceChannel != null
              ? voiceChannel!.name
              : '# ${channel?.name ?? widget.group.name}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!wide)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Các kênh chat',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(LucideIcons.hash),
              ),
            ),
          IconButton(
            tooltip: 'Thành viên',
            onPressed: _members,
            icon: const Icon(LucideIcons.userRound),
          ),
          IconButton(
            tooltip: 'Thông tin và quản lý nhóm',
            onPressed: _details,
            icon: const Icon(LucideIcons.settings),
          ),
          if (role >= 1 && channel != null && voiceChannel == null)
            PopupMenuButton<String>(
              tooltip: 'Quản lý kênh',
              onSelected: _channelAction,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Đổi tên kênh')),
                if (!channel!.isDefault)
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('Lưu trữ kênh'),
                  ),
              ],
            ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(child: Builder(builder: _channelList)),
            ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 235,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Builder(builder: _channelList),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: voice,
                  builder: (context, _) {
                    if (!voice.joined || voiceChannel != null) {
                      return const SizedBox.shrink();
                    }
                    return Material(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(LucideIcons.headphones),
                        title: const Text('Đang trong phòng voice'),
                        subtitle: Text(
                          voiceChannels
                                  .where((item) => item.id == voice.channelId)
                                  .firstOrNull
                                  ?.name ??
                              '',
                        ),
                        onTap: () => setState(
                          () => voiceChannel = voiceChannels
                              .where((item) => item.id == voice.channelId)
                              .firstOrNull,
                        ),
                        trailing: IconButton(
                          tooltip: 'Rời phòng voice',
                          onPressed: voice.leave,
                          icon: const Icon(LucideIcons.phoneOff),
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: voiceChannel == null
                      ? _timeline()
                      : VoiceRoomPanel(
                          controller: voice,
                          channel: voiceChannel!,
                          onChat: () => setState(() => voiceChannel = null),
                        ),
                ),
              ],
            ),
          ),
          if (wide)
            SizedBox(
              width: 220,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: _memberList(),
              ),
            ),
        ],
      ),
    );
  }
}
