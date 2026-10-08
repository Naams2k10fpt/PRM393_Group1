import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_exception.dart';
import '../../data/repositories/groups_repository.dart';
import 'chat_room_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final GroupsRepository repo = context.read<GroupsRepository>();
  List<StudyGroup> mine = [];
  List<StudyGroup> discover = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    final name = TextEditingController();
    final description = TextEditingController();
    var mode = 0;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, update) => AlertDialog(
                  title: const Text('Tạo nhóm học'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Tên nhóm',
                        ),
                      ),
                      TextField(
                        controller: description,
                        maxLength: 500,
                        decoration: const InputDecoration(labelText: 'Mô tả'),
                      ),
                      DropdownButtonFormField<int>(
                        initialValue: mode,
                        items: const [
                          DropdownMenuItem(
                            value: 0,
                            child: Text('Tham gia tự do'),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Text('Cần phê duyệt'),
                          ),
                        ],
                        onChanged: (value) => update(() => mode = value ?? 0),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Tạo'),
                    ),
                  ],
                ),
          ),
    );
    if (ok == true) {
      try {
        if (name.text.trim().isEmpty) {
          throw const FormatException('Nhập tên nhóm.');
        }
        await repo.create(name.text, description.text, mode);
        await _load();
      } catch (e) {
        _showError(e);
      }
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _join(StudyGroup group) async {
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
                                ? const Text('Đang chờ')
                                : TextButton(
                                  onPressed: () => _join(group),
                                  child: const Text('Tham gia'),
                                ),
                      ),
                    ),
                ],
              ),
            ),
  );
}
