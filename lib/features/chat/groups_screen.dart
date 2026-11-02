import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../data/api/api_exception.dart';
import '../../data/repositories/groups_repository.dart';
import 'chat_room_screen.dart';
import 'join_invite_dialog.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final repo = context.read<GroupsRepository>();
  final search = TextEditingController();
  List<StudyGroup> mine = [];
  List<GroupInvitation> invitations = [];
  GroupOptions? options;
  GroupDiscovery? discovery;
  int? accessMode, subjectId;
  String sort = 'newest';
  bool loading = true, searching = false;
  int searchVersion = 0;
  final pending = <int>{};
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait<Object>([
        repo.mine(),
        repo.options(),
        repo.invitations(),
      ]);
      if (!mounted) return;
      setState(() {
        mine = values[0] as List<StudyGroup>;
        options = values[1] as GroupOptions;
        invitations = values[2] as List<GroupInvitation>;
      });
      await _find(page: discovery?.page ?? 1);
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _find({int page = 1}) async {
    final version = ++searchVersion;
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final data = await repo.discovery(
        search: search.text.trim(),
        accessMode: accessMode,
        subjectId: subjectId,
        sort: sort,
        page: page,
      );
      if (mounted && version == searchVersion) setState(() => discovery = data);
    } catch (e) {
      if (mounted && version == searchVersion) {
        setState(() => error = _message(e));
      }
    } finally {
      if (mounted && version == searchVersion) {
        setState(() => searching = false);
      }
    }
  }

  String _message(Object e) =>
      e is ApiException ? e.message : 'Không thể tải nhóm. Vui lòng thử lại.';

  Future<void> _action(
    int id,
    Future<void> Function() action, {
    String? success,
  }) async {
    if (!pending.add(id)) return;
    setState(() {});
    try {
      await action();
      if (!mounted) return;
      await _load();
      if (mounted && success != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(e))));
      }
    } finally {
      if (mounted) setState(() => pending.remove(id));
    }
  }

  Future<void> _open(StudyGroup group) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ChatRoomScreen(group: group)),
    );
    if (mounted) await _load();
  }

  Future<void> _joinLink() async {
    final id = await showDialog<int>(
      context: context,
      builder: (_) => JoinInviteDialog(repo: repo),
    );
    if (id == null || !mounted) return;
    await _load();
    if (!mounted) return;
    final group = mine.where((g) => g.id == id).firstOrNull;
    if (group != null) await _open(group);
  }

  Future<void> _create() async {
    final created = await showDialog<bool>(
      context: context,
      builder:
          (_) => _CreateGroupDialog(
            repo: repo,
            subjects: options?.mySubjects ?? [],
          ),
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Nhóm học'),
      actions: [
        IconButton(
          tooltip: 'Tham gia bằng link mời',
          onPressed: _joinLink,
          icon: const Icon(LucideIcons.link),
        ),
        IconButton(
          tooltip: 'Tạo nhóm',
          onPressed: loading ? null : _create,
          icon: const Icon(LucideIcons.plus),
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
                  if (error != null) ...[
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ],
                  if (invitations.isNotEmpty) ...[
                    _heading('Lời mời tham gia'),
                    for (final invitation in invitations)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invitation.groupName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Hết hạn: ${invitation.expiresAt.toLocal().day}/${invitation.expiresAt.toLocal().month}/${invitation.expiresAt.toLocal().year}',
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed:
                                        pending.contains(invitation.groupId)
                                            ? null
                                            : () => _action(
                                              invitation.groupId,
                                              () => repo.respondInvitation(
                                                invitation.groupId,
                                                false,
                                              ),
                                            ),
                                    child: const Text('Từ chối'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        pending.contains(invitation.groupId)
                                            ? null
                                            : () => _action(
                                              invitation.groupId,
                                              () => repo.respondInvitation(
                                                invitation.groupId,
                                                true,
                                              ),
                                              success: 'Đã tham gia nhóm.',
                                            ),
                                    child: const Text('Chấp nhận'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                  _heading('Nhóm của tôi'),
                  if (mine.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Bạn chưa tham gia nhóm nào.'),
                    ),
                  for (final group in mine)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          group.accessMode == 2
                              ? LucideIcons.lockKeyhole
                              : LucideIcons.messageCircle,
                        ),
                        title: Text(group.name),
                        subtitle: Text(
                          '${group.subjectName ?? 'Chung'} · ${group.memberCount} thành viên${group.description?.isNotEmpty == true ? ' · ${group.description}' : ''}',
                        ),
                        trailing:
                            group.unreadCount > 0
                                ? Badge(
                                  label: Text('${group.unreadCount}'),
                                  child: const Icon(LucideIcons.chevronRight),
                                )
                                : const Icon(LucideIcons.chevronRight),
                        onTap: () => _open(group),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _heading('Khám phá nhóm'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: search,
                    decoration: InputDecoration(
                      labelText: 'Tìm nhóm',
                      hintText: 'Tên hoặc mô tả',
                      suffixIcon: IconButton(
                        tooltip: 'Tìm kiếm',
                        onPressed: () => _find(),
                        icon: const Icon(LucideIcons.search),
                      ),
                    ),
                    onSubmitted: (_) => _find(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: accessMode ?? -1,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Quyền tham gia',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: -1,
                        child: Text('Tất cả nhóm công khai'),
                      ),
                      DropdownMenuItem(value: 0, child: Text('Tham gia tự do')),
                      DropdownMenuItem(value: 1, child: Text('Cần phê duyệt')),
                    ],
                    onChanged: (value) {
                      setState(() => accessMode = value == -1 ? null : value);
                      _find();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: subjectId ?? -1,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Môn học'),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('Tất cả môn học'),
                      ),
                      for (final subject
                          in options?.publicSubjects ?? <GroupSubject>[])
                        DropdownMenuItem(
                          value: subject.id,
                          child: Text(subject.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => subjectId = value == -1 ? null : value);
                      _find();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: sort,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sắp xếp'),
                    items: const [
                      DropdownMenuItem(
                        value: 'newest',
                        child: Text('Mới nhất'),
                      ),
                      DropdownMenuItem(
                        value: 'popular',
                        child: Text('Nhiều thành viên nhất'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => sort = value ?? 'newest');
                      _find();
                    },
                  ),
                  const SizedBox(height: 12),
                  if (searching) const LinearProgressIndicator(),
                  if (!searching && discovery != null)
                    Text('${discovery!.totalCount} nhóm phù hợp'),
                  for (final group in discovery?.groups ?? <StudyGroup>[])
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${group.subjectName ?? 'Chung'} · ${group.memberCount} thành viên · ${groupAccessLabel(group.accessMode)}',
                            ),
                            if (group.ownerName != null)
                              Text('Chủ phòng: ${group.ownerName}'),
                            if (group.description?.isNotEmpty == true)
                              Text(group.description!),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    pending.contains(group.id) || searching
                                        ? null
                                        : () => _action(
                                          group.id,
                                          () =>
                                              group.hasPendingRequest
                                                  ? repo.cancelJoinRequest(
                                                    group.id,
                                                  )
                                                  : repo.join(group.id),
                                          success:
                                              !group.hasPendingRequest &&
                                                      group.accessMode == 1
                                                  ? 'Đã gửi yêu cầu tham gia.'
                                                  : null,
                                        ),
                                child: Text(
                                  group.hasPendingRequest
                                      ? 'Hủy yêu cầu'
                                      : 'Tham gia',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!searching && discovery?.groups.isEmpty == true)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Không tìm thấy nhóm phù hợp.'),
                    ),
                  if (discovery != null && discovery!.pageCount > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed:
                              searching || discovery!.page <= 1
                                  ? null
                                  : () => _find(page: discovery!.page - 1),
                          child: const Text('Trước'),
                        ),
                        Text('${discovery!.page}/${discovery!.pageCount}'),
                        TextButton(
                          onPressed:
                              searching ||
                                      discovery!.page >= discovery!.pageCount
                                  ? null
                                  : () => _find(page: discovery!.page + 1),
                          child: const Text('Tiếp'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
  );

  Widget _heading(String text) => Text(
    text,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  );
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({required this.repo, required this.subjects});
  final GroupsRepository repo;
  final List<GroupSubject> subjects;
  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(), description = TextEditingController();
  int mode = 0;
  int? subjectId;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (busy || !formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repo.create(
        name.text,
        description.text,
        mode,
        subjectId: subjectId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error =
                  e is ApiException
                      ? e.message
                      : 'Không thể tạo nhóm. Vui lòng thử lại.',
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
      title: const Text('Tạo nhóm học'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              TextFormField(
                controller: name,
                maxLength: 200,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Tên nhóm'),
                validator:
                    (v) =>
                        v == null || v.trim().isEmpty ? 'Nhập tên nhóm.' : null,
              ),
              TextFormField(
                controller: description,
                maxLength: 500,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              DropdownButtonFormField<int>(
                value: -1,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Môn học của bạn'),
                items: [
                  const DropdownMenuItem(
                    value: -1,
                    child: Text('Nhóm học chung'),
                  ),
                  for (final subject in widget.subjects)
                    DropdownMenuItem(
                      value: subject.id,
                      child: Text(subject.name),
                    ),
                ],
                onChanged:
                    busy
                        ? null
                        : (v) => setState(() => subjectId = v == -1 ? null : v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: mode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Quyền tham gia'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Tham gia tự do')),
                  DropdownMenuItem(value: 1, child: Text('Cần phê duyệt')),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('Riêng tư · chỉ được mời'),
                  ),
                ],
                onChanged: busy ? null : (v) => setState(() => mode = v ?? 0),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : _save,
                child: Text(busy ? 'Đang tạo...' : 'Tạo'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
