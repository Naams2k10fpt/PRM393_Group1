import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/repositories/groups_repository.dart';

const chatEmojis = ['👍', '❤️', '😂', '🎉', '🤔', '👀', '✅', '❌'];

class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({
    super.key,
    required this.message,
    required this.repo,
    required this.userId,
    required this.canModerate,
    required this.onAction,
  });
  final ChatMessage message;
  final GroupsRepository repo;
  final String userId;
  final bool canModerate;
  final void Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    if (message.kind != 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            '${message.senderName} ${message.kind == 1 ? 'đã vào nhóm' : 'đã rời nhóm'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    final own = message.senderUserId == userId;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            foregroundImage:
                message.senderAvatarUrl?.startsWith('https://') == true
                    ? NetworkImage(message.senderAvatarUrl!)
                    : null,
            child: Text(
              message.senderName.characters.firstOrNull?.toUpperCase() ?? '?',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: own ? colors.primary : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      TimeOfDay.fromDateTime(
                        message.sentAt.toLocal(),
                      ).format(context),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (!message.isDeleted)
                      PopupMenuButton<String>(
                        tooltip: 'Thao tác tin nhắn',
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        onSelected: onAction,
                        itemBuilder:
                            (_) => [
                              const PopupMenuItem(
                                value: 'reply',
                                child: Text('Trả lời'),
                              ),
                              const PopupMenuItem(
                                value: 'copy',
                                child: Text('Sao chép'),
                              ),
                              if (own)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Sửa'),
                                ),
                              if (own || canModerate)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Xóa'),
                                ),
                              const PopupMenuDivider(),
                              for (final emoji in chatEmojis)
                                PopupMenuItem(
                                  value: emoji,
                                  child: Text('Thả $emoji'),
                                ),
                            ],
                      ),
                  ],
                ),
                if (message.reply != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: colors.primary, width: 3),
                      ),
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: .5,
                      ),
                    ),
                    child: Text(
                      '↪ ${message.reply!.senderName}: ${message.reply!.content.isEmpty ? 'File đính kèm' : message.reply!.content}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (message.isDeleted)
                  Text(
                    'Tin nhắn đã bị xóa',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else ...[
                  if (message.content.isNotEmpty)
                    SelectableText(message.content),
                  if (message.editedAt != null)
                    Text(
                      '(đã chỉnh sửa)',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  for (final file in message.attachments)
                    ChatAttachmentTile(
                      key: ValueKey(file.id),
                      file: file,
                      repo: repo,
                    ),
                  if (message.reactions.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final emoji
                            in message.reactions
                                .map((item) => item.emoji)
                                .toSet())
                          ActionChip(
                            label: Text(
                              '$emoji ${message.reactions.where((item) => item.emoji == emoji).length}',
                            ),
                            backgroundColor:
                                message.reactions.any(
                                      (item) =>
                                          item.emoji == emoji &&
                                          item.userId == userId,
                                    )
                                    ? colors.primaryContainer
                                    : null,
                            onPressed: () => onAction(emoji),
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatAttachmentTile extends StatefulWidget {
  const ChatAttachmentTile({super.key, required this.file, required this.repo});
  final ChatFile file;
  final GroupsRepository repo;
  @override
  State<ChatAttachmentTile> createState() => _ChatAttachmentTileState();
}

class _ChatAttachmentTileState extends State<ChatAttachmentTile> {
  Future<Uint8List>? bytes;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    if (widget.file.isImage) bytes = widget.repo.downloadFile(widget.file);
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final data = await (bytes ??= widget.repo.downloadFile(widget.file));
      await FilePicker.saveFile(
        fileName: widget.file.fileName,
        bytes: data,
        dialogTitle: 'Lưu file',
      );
    } catch (_) {
      bytes = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải file. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    constraints: const BoxConstraints(maxWidth: 360),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.file.isImage && bytes != null)
          FutureBuilder<Uint8List>(
            future: bytes,
            builder:
                (context, snapshot) =>
                    snapshot.hasData
                        ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: InkWell(
                            onTap:
                                () => showDialog<void>(
                                  context: context,
                                  builder:
                                      (context) => Dialog(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: IconButton(
                                                tooltip: 'Đóng ảnh',
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                                icon: const Icon(LucideIcons.x),
                                              ),
                                            ),
                                            Flexible(
                                              child: InteractiveViewer(
                                                maxScale: 4,
                                                child: Image.memory(
                                                  snapshot.data!,
                                                  cacheWidth: 2048,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                ),
                            child: Image.memory(
                              snapshot.data!,
                              cacheWidth: 600,
                              height: 190,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, _, _) => const SizedBox(
                                    height: 80,
                                    child: Center(
                                      child: Icon(LucideIcons.image),
                                    ),
                                  ),
                            ),
                          ),
                        )
                        : SizedBox(
                          height: 120,
                          child: Center(
                            child:
                                snapshot.hasError
                                    ? const Icon(LucideIcons.image)
                                    : const CircularProgressIndicator(),
                          ),
                        ),
          ),
        ListTile(
          dense: true,
          leading: Icon(
            widget.file.isImage
                ? LucideIcons.image
                : LucideIcons.fileText,
          ),
          title: Text(
            widget.file.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(widget.file.sizeLabel),
          trailing: IconButton(
            tooltip: 'Tải file',
            onPressed: saving ? null : _save,
            icon:
                saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(LucideIcons.download),
          ),
        ),
      ],
    ),
  );
}
