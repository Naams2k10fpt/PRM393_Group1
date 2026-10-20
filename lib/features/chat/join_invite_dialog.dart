import 'package:flutter/material.dart';
import '../../data/api/api_exception.dart';
import '../../data/repositories/groups_repository.dart';

String? inviteToken(String text) {
  final value = text.trim();
  if (RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value)) return value;
  final uri = Uri.tryParse(value);
  final segments = uri?.pathSegments ?? [];
  if (segments.length == 3 &&
      segments[0] == 'groups' &&
      segments[1] == 'invite' &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(segments[2])) {
    return segments[2];
  }
  return null;
}

class JoinInviteDialog extends StatefulWidget {
  const JoinInviteDialog({super.key, required this.repo});
  final GroupsRepository repo;
  @override
  State<JoinInviteDialog> createState() => _JoinInviteDialogState();
}

class _JoinInviteDialogState extends State<JoinInviteDialog> {
  final input = TextEditingController();
  GroupInvitePreview? preview;
  String? token, error;
  bool busy = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (busy) return;
    final parsed = inviteToken(input.text);
    if (parsed == null) {
      setState(() => error = 'Link mời không hợp lệ.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (preview == null || token != parsed) {
        final data = await widget.repo.previewLink(parsed);
        if (mounted) {
          setState(() {
            preview = data;
            token = parsed;
          });
        }
      } else {
        final id = await widget.repo.acceptLink(parsed);
        if (mounted) Navigator.pop(context, id);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error =
                  e is ApiException
                      ? e.message
                      : 'Không thể kiểm tra link mời. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Tham gia bằng link mời'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: input,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Dán link mời'),
              onChanged:
                  (_) => setState(() {
                    preview = null;
                    token = null;
                  }),
            ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('Tham gia nhóm “${preview!.groupName}”?'),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: Text(
            busy
                ? 'Đang xử lý...'
                : preview == null
                ? 'Kiểm tra link'
                : 'Xác nhận tham gia',
          ),
        ),
      ],
    ),
  );
}
