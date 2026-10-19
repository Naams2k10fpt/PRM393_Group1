import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_exception.dart';
import '../../data/repositories/groups_repository.dart';
import 'chat_room_screen.dart';

typedef _GroupDraft = ({String name, String description, int mode});

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final description = TextEditingController();
  int mode = 0;

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tạo nhóm học'),
    content: SingleChildScrollView(
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Tên nhóm'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Nhập tên nhóm.'
                          : null,
            ),
            TextFormField(
              controller: description,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            DropdownButtonFormField<int>(
              initialValue: mode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Quyền tham gia'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Tham gia tự do')),
                DropdownMenuItem(value: 1, child: Text('Cần phê duyệt')),
              ],
              onChanged: (value) => setState(() => mode = value ?? 0),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (formKey.currentState!.validate()) {
            Navigator.pop(context, (
              name: name.text.trim(),
              description: description.text.trim(),
              mode: mode,
            ));
          }
        },
        child: const Text('Tạo'),
      ),
    ],
  );
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final GroupsRepository repo = context.read<GroupsRepository>();
  List<StudyGroup> mine = [];
  List<StudyGroup> discover = [];
  bool loading = true;
  final pendingActions = <int>{};
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final groups = await Future.wait([repo.mine(), repo.discover()]);
      if (mounted) {
        setState(() {
          mine = groups[0];
          discover = groups[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    final request = await showDialog<_GroupDraft>(
      context: context,
      builder: (_) => const _CreateGroupDialog(),
    );
    if (request == null || !mounted) return;
    try {
      await repo.create(request.name, request.description, request.mode);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _join(StudyGroup group) async {
    if (!pendingActions.add(group.id)) return;
    setState(() {});
    try {
      await repo.join(group.id);
      await _load();
      if (mounted && group.accessMode == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu tham gia.')),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => pendingActions.remove(group.id));
    }
  }

  Future<void> _cancelRequest(StudyGroup group) async {
    if (!pendingActions.add(group.id)) return;
    setState(() {});
    try {
      await repo.cancelJoinRequest(group.id);
      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => pendingActions.remove(group.id));
    }
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : e is FormatException
                ? e.message
                : '$e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Nhóm học'),
      actions: [
        IconButton(
          tooltip: 'Tạo nhóm',
          onPressed: _create,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body:
        loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const Text(
                    'Nhóm của tôi',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (mine.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Bạn chưa tham gia nhóm nào.'),
                    ),
                  for (final group in mine)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.forum_outlined),
                        title: Text(group.name),
                        subtitle: Text(
                          '${group.subjectName ?? 'Chung'} · ${group.memberCount} thành viên${group.description?.isNotEmpty == true ? ' · ${group.description}' : ''}',
                        ),
                        trailing:
                            group.unreadCount > 0
                                ? Badge(
                                  label: Text('${group.unreadCount}'),
                                  child: const Icon(Icons.chevron_right),
                                )
                                : const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(group: group),
                            ),
                          );
                          if (mounted) _load();
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Khám phá nhóm',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  for (final group in discover.where((g) => !g.isMember))
                    Card(
                      child: ListTile(
                        title: Text(group.name),
                        subtitle: Text(
                          '${group.subjectName ?? 'Chung'} · ${group.memberCount} thành viên · ${group.accessMode == 1 ? 'Cần phê duyệt' : 'Công khai'}',
                        ),
                        trailing:
                            group.hasPendingRequest
                                ? TextButton(
                                  onPressed:
                                      pendingActions.contains(group.id)
                                          ? null
                                          : () => _cancelRequest(group),
                                  child: const Text('Hủy yêu cầu'),
                                )
                                : TextButton(
                                  onPressed:
                                      pendingActions.contains(group.id)
                                          ? null
                                          : () => _join(group),
                                  child: const Text('Tham gia'),
                                ),
                      ),
                    ),
                ],
              ),
            ),
  );
}
