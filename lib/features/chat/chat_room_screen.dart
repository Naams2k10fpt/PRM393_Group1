import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../core/config/app_config.dart';
import '../../data/api/api_exception.dart';
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
  HubConnection? hub;
  final messages = <ChatMessage>[];
  bool loading = true;
  bool loadingOlder = false;
  bool hasOlder = true;
  bool connected = false;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    final connection = hub;
    if (connection != null) {
      connection
          .invoke('LeaveGroup', args: [widget.group.id])
          .catchError((_) => null)
          .whenComplete(() => connection.stop());
    }
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      await _refresh();
      final connection =
          HubConnectionBuilder()
              .withUrl(
                '${AppConfig.baseUrl}/hubs/chat',
                options: HttpConnectionOptions(
                  accessTokenFactory: repo.api.accessToken,
                ),
              )
              .withAutomaticReconnect()
              .build();
      hub = connection;
      connection.on('ReceiveMessage', (args) {
        if (args == null || args.isEmpty || args[0] is! Map) return;
        final message = ChatMessage.fromJson(
          Map<String, dynamic>.from(args[0] as Map),
        );
        if (message.groupId == widget.group.id) _add(message);
      });
      connection.on('GroupAccessRevoked', (args) {
        if (args?.isNotEmpty == true &&
            args![0] == widget.group.id &&
            mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bạn không còn quyền vào nhóm.')),
          );
          Navigator.pop(context);
        }
      });
      connection.onreconnecting(({error}) {
        if (mounted) setState(() => connected = false);
      });
      connection.onreconnected(({connectionId}) async {
        if (!mounted) return;
        try {
          await connection.invoke('JoinGroup', args: [widget.group.id]);
          await _refresh();
          if (mounted) setState(() => connected = true);
        } catch (e) {
          if (mounted) {
            setState(() => error = e is ApiException ? e.message : '$e');
          }
        }
      });
      connection.onclose(({error}) {
        if (mounted) setState(() => connected = false);
      });
      await connection.start();
      await connection.invoke('JoinGroup', args: [widget.group.id]);
      await _refresh();
      if (mounted) setState(() => connected = true);
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => loading = false);
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
      final response = await hub!.invoke(
        'SendMessage',
        args: [widget.group.id, content],
      );
      if (response is Map) {
        _add(ChatMessage.fromJson(Map<String, dynamic>.from(response)));
      }
      if (mounted) input.clear();
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
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Đang kết nối phòng chat...'),
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
                                          Text(
                                            message.senderName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
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
