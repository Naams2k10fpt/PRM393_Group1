import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_exception.dart';
import '../../data/realtime/chat_connection.dart';
import '../../data/repositories/groups_repository.dart';
import '../auth/auth_controller.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key, required this.group});
  final StudyGroup group;
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  late final GroupsRepository repo = context.read<GroupsRepository>();
  late final String userId = context.read<AuthController>().user!.id;
  final input = TextEditingController();
  final scroll = ScrollController();
  ChatConnection? hub;
  final messages = <ChatMessage>[];
  bool loading = true;
  bool loadingOlder = false;
  bool hasOlder = true;
  bool connected = false;
  bool connecting = false;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    unawaited(hub?.close().catchError((Object _) {}));
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (connecting) return;
    setState(() {
      connecting = true;
      connected = false;
      error = null;
    });
    final previous = hub;
    try {
      await previous?.close();
      if (!mounted) return;
      final connection = repo.openChat(widget.group.id);
      hub = connection;
      connection.onMessage = _add;
      connection.onAccessRevoked = () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn không còn quyền vào nhóm.')),
        );
        Navigator.pop(context);
      };
      connection.onDisconnected = () {
        if (mounted) setState(() => connected = false);
      };
      connection.onError = _showError;
      connection.onReconnected = () async {
        await _refresh();
        if (mounted) {
          setState(() {
            connected = true;
            error = null;
          });
        }
      };
      await connection.connect();
      if (!mounted) return;
      await _refresh();
      if (mounted) setState(() => connected = true);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          connecting = false;
        });
      }
    }
  }

  void _showError(Object e) {
    if (mounted) {
      setState(
        () =>
            error =
                e is ApiException
                    ? e.message
                    : 'Không thể kết nối hoặc gửi tin nhắn. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _refresh() async {
    final latest = await repo.messages(widget.group.id);
    if (!mounted) return;
    setState(() {
      for (final message in latest) {
        if (!messages.any((m) => m.id == message.id)) messages.add(message);
      }
      messages.sort((a, b) => a.id.compareTo(b.id));
      hasOlder = latest.length == 30;
    });
    _markRead();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
  }

  void _add(ChatMessage message) {
    if (!mounted || messages.any((m) => m.id == message.id)) return;
    setState(() {
      messages.add(message);
      messages.sort((a, b) => a.id.compareTo(b.id));
    });
    _markRead();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
  }

  void _markRead() {
    if (messages.isEmpty) return;
    repo.markRead(widget.group.id, messages.last.id).catchError((_) {});
  }

  void _scrollBottom() {
    if (mounted && scroll.hasClients) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
    }
  }

  Future<void> _older() async {
    if (loadingOlder || messages.isEmpty) return;
    setState(() => loadingOlder = true);
    try {
      final old = await repo.messages(
        widget.group.id,
        beforeId: messages.first.id,
      );
      if (mounted) {
        setState(() {
          messages.insertAll(
            0,
            old.where((m) => !messages.any((shown) => shown.id == m.id)),
          );
          hasOlder = old.length == 30;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException ? e.message : '$e');
      }
    } finally {
      if (mounted) setState(() => loadingOlder = false);
    }
  }

  Future<void> _send() async {
    final content = input.text.trim();
    if (content.isEmpty || content.length > 2000 || sending || !connected) {
      return;
    }
    setState(() => sending = true);
    try {
      final response = await hub!.send(content);
      if (response != null) _add(response);
      // Keep anything the user typed while the previous message was sending.
      if (mounted && input.text.trim() == content) input.clear();
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.group.name)),
    body: Column(
      children: [
        if (!connected)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    connecting
                        ? 'Đang kết nối phòng chat...'
                        : 'Đã mất kết nối.',
                  ),
                ),
                if (!connecting)
                  TextButton(
                    onPressed: _open,
                    child: const Text('Kết nối lại'),
                  ),
              ],
            ),
          ),
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
        Expanded(
          child:
              loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (hasOlder && messages.isNotEmpty)
                        Center(
                          child: TextButton(
                            onPressed: loadingOlder ? null : _older,
                            child: Text(
                              loadingOlder ? 'Đang tải...' : 'Tin nhắn cũ hơn',
                            ),
                          ),
                        ),
                      if (messages.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Chưa có tin nhắn.'),
                          ),
                        ),
                      for (final message in messages)
                        message.kind == 0
                            ? Align(
                              alignment:
                                  message.senderUserId == userId
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 13,
                                            foregroundImage:
                                                message.senderAvatarUrl
                                                            ?.startsWith(
                                                              'http',
                                                            ) ==
                                                        true
                                                    ? NetworkImage(
                                                      message.senderAvatarUrl!,
                                                    )
                                                    : null,
                                            child: Text(
                                              message.senderName.isEmpty
                                                  ? '?'
                                                  : message.senderName[0]
                                                      .toUpperCase(),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              message.senderName,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(message.content),
                                      Text(
                                        '${message.sentAt.toLocal().hour.toString().padLeft(2, '0')}:${message.sentAt.toLocal().minute.toString().padLeft(2, '0')}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '${message.senderName} ${message.kind == 1 ? 'đã vào nhóm' : 'đã rời nhóm'}',
                                ),
                              ),
                            ),
                    ],
                  ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  tooltip: 'Gửi',
                  onPressed: connected && !sending ? _send : null,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
