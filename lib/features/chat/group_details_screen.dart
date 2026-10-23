import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:radix_icons/radix_icons.dart';
import '../../core/config/app_config.dart';
import '../../data/api/api_exception.dart';
import '../../data/repositories/groups_repository.dart';
import '../auth/auth_controller.dart';

class GroupDetailsScreen extends StatefulWidget {
  const GroupDetailsScreen({super.key, required this.groupId});
  final int groupId;
  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late final repo = context.read<GroupsRepository>();
  late final userId = context.read<AuthController>().user!.id;
  final email = TextEditingController();
  final emailForm = GlobalKey<FormState>();
  GroupDetails? group;
  GroupManagement? management;
  bool loading = true, busy = false;
  int durationDays = 7;
  int accessRevision = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final details = await repo.details(widget.groupId);
      final controls =
          details.isManager ? await repo.management(widget.groupId) : null;
      if (mounted) {
        setState(() {
          group = details;
          management = controls;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _message(Object e) =>
      e is ApiException
          ? e.message
          : 'Không thể thực hiện thao tác. Vui lòng thử lại.';

  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Xác nhận'),
                ),
              ],
            ),
      ) ==
      true;

  Future<void> _perform(
    Future<void> Function() action, {
    String success = 'Đã cập nhật nhóm.',
    bool leave = false,
  }) async {
    if (busy || loading) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (!mounted) return;
      if (leave) {
        Navigator.pop(context, true);
        return;
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _memberAction(String action, GroupMember member) async {
    if (busy || loading) return;
    switch (action) {
      case 'moderator':
        await _perform(
          () => repo.setModerator(
            widget.groupId,
            member.userId,
            member.role != 1,
          ),
        );
      case 'transfer':
        if (await _confirm(
          'Chuyển chủ phòng?',
          '${member.username} sẽ trở thành chủ phòng. Bạn trở lại vai trò thành viên.',
        )) {
          if (mounted) {
            await _perform(() => repo.transfer(widget.groupId, member.userId));
          }
        }
      case 'remove':
        if (await _confirm(
          'Loại khỏi nhóm?',
          '${member.username} sẽ bị chặn tham gia lại cho đến khi được bỏ chặn.',
        )) {
          if (mounted) {
            await _perform(
              () => repo.removeMember(widget.groupId, member.userId),
            );
          }
        }
    }
  }

  Future<void> _copy(GroupInviteLink link) async {
    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              '${AppConfig.baseUrl.replaceFirst(RegExp(r'/+$'), '')}/groups/invite/${link.token}',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã sao chép link mời.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Không thể sao chép link. Vui lòng thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = group;
    final disabled = busy || loading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin nhóm'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: disabled ? null : _load,
            icon: const Icon(RadixIcons.Reload),
          ),
        ],
      ),
      body:
          data == null && loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: disabled ? () async {} : _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (disabled) const LinearProgressIndicator(),
                    if (error != null) ...[
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      TextButton(
                        onPressed: disabled ? null : _load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                    if (data != null) ...[
                      Text(
                        data.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (data.description?.isNotEmpty == true)
                        Text(data.description!),
                      Text(groupAccessLabel(data.accessMode)),
                      if (data.isOwner)
                        _section('Quyền tham gia', [
                          const Text(
                            'Đổi chế độ sẽ hủy các yêu cầu, lời mời và link mời đang hoạt động.',
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: ValueKey('${data.accessMode}:$accessRevision'),
                            value: data.accessMode,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Chế độ nhóm',
                            ),
                            items: [
                              for (var mode = 0; mode < 3; mode++)
                                DropdownMenuItem(
                                  value: mode,
                                  child: Text(groupAccessLabel(mode)),
                                ),
                            ],
                            onChanged:
                                disabled
                                    ? null
                                    : (mode) async {
                                      if (mode == null ||
                                          mode == data.accessMode) {
                                        return;
                                      }
                                      if (await _confirm(
                                        'Đổi quyền tham gia?',
                                        'Các yêu cầu, lời mời đang chờ và link mời cũ sẽ bị hủy.',
                                      )) {
                                        if (mounted) {
                                          await _perform(
                                            () => repo.changeAccess(
                                              data.id,
                                              mode,
                                            ),
                                          );
                                        }
                                      }
                                      if (mounted) {
                                        setState(() => accessRevision++);
                                      }
                                    },
                          ),
                        ]),
                      if (data.isManager)
                        _section('Mời thành viên', [
                          const Text(
                            'Mời tài khoản đã xác minh bằng email. Lời mời hết hạn sau 7 ngày.',
                          ),
                          const SizedBox(height: 12),
                          Form(
                            key: emailForm,
                            child: TextFormField(
                              controller: email,
                              enabled: !disabled,
                              maxLength: 320,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email cần mời',
                              ),
                              validator:
                                  (v) =>
                                      v == null ||
                                              !RegExp(
                                                r'^\S+@\S+\.\S+$',
                                              ).hasMatch(v.trim())
                                          ? 'Nhập email hợp lệ.'
                                          : null,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                disabled
                                    ? null
                                    : () {
                                      if (emailForm.currentState!.validate()) {
                                        _perform(
                                          () =>
                                              repo.invite(data.id, email.text),
                                          success:
                                              'Đã gửi lời mời trong ứng dụng.',
                                        );
                                      }
                                    },
                            child: const Text('Gửi lời mời'),
                          ),
                        ]),
                      if (data.isOwner)
                        _section('Link mời vào nhóm', [
                          DropdownButtonFormField<int>(
                            value: durationDays,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Thời hạn link mời',
                            ),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 ngày')),
                              DropdownMenuItem(value: 7, child: Text('7 ngày')),
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 ngày'),
                              ),
                              DropdownMenuItem(
                                value: 0,
                                child: Text('Vĩnh viễn'),
                              ),
                            ],
                            onChanged:
                                disabled
                                    ? null
                                    : (v) =>
                                        setState(() => durationDays = v ?? 7),
                          ),
                          TextButton(
                            onPressed:
                                disabled
                                    ? null
                                    : () => _perform(
                                      () => repo.createLink(
                                        data.id,
                                        durationDays,
                                      ),
                                      success: 'Đã tạo link mời.',
                                    ),
                            child: const Text('Tạo link mời'),
                          ),
                          if (management?.links.isEmpty == true)
                            const Text('Chưa có link mời nào.'),
                          for (final link
                              in management?.links ?? <GroupInviteLink>[]) ...[
                            const Divider(),
                            Text(
                              'Link #${link.id} · ${link.revokedAt != null
                                  ? 'Đã thu hồi'
                                  : link.isActive
                                  ? 'Đang hoạt động'
                                  : 'Đã hết hạn'}',
                            ),
                            Text(
                              link.expiresAt == null
                                  ? 'Vĩnh viễn'
                                  : 'Hết hạn: ${link.expiresAt!.toLocal()}',
                            ),
                            if (link.isActive)
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (link.token != null)
                                    TextButton.icon(
                                      onPressed:
                                          disabled ? null : () => _copy(link),
                                      icon: const Icon(RadixIcons.Copy),
                                      label: const Text('Sao chép'),
                                    ),
                                  TextButton(
                                    onPressed:
                                        disabled
                                            ? null
                                            : () async {
                                              if (await _confirm(
                                                'Thu hồi link mời?',
                                                'Người có link này sẽ không thể dùng link để tham gia nữa.',
                                              )) {
                                                if (mounted) {
                                                  await _perform(
                                                    () => repo.revokeLink(
                                                      data.id,
                                                      link.id,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                    child: const Text('Thu hồi'),
                                  ),
                                ],
                              ),
                          ],
                        ]),
                      if (data.isManager && data.accessMode == 1)
                        _section('Yêu cầu tham gia', [
                          if (management?.requests.isEmpty == true)
                            const Text('Không có yêu cầu đang chờ.'),
                          for (final request
                              in management?.requests ?? <GroupRequest>[])
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(request.username),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed:
                                          disabled
                                              ? null
                                              : () => _perform(
                                                () => repo.review(
                                                  data.id,
                                                  request.userId,
                                                  true,
                                                ),
                                              ),
                                      child: const Text('Duyệt'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          disabled
                                              ? null
                                              : () => _perform(
                                                () => repo.review(
                                                  data.id,
                                                  request.userId,
                                                  false,
                                                ),
                                              ),
                                      child: const Text('Từ chối'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ]),
                      _section('Thành viên (${data.members.length})', [
                        for (final member in data.members)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(
                                member.username.isEmpty
                                    ? '?'
                                    : member.username.characters.first
                                        .toUpperCase(),
                              ),
                            ),
                            title: Text(
                              '${member.username}${member.userId == userId ? ' (bạn)' : ''}',
                            ),
                            subtitle: Text(member.roleLabel),
                            trailing:
                                data.isManager &&
                                        member.userId != userId &&
                                        member.role < data.myRole
                                    ? PopupMenuButton<String>(
                                      tooltip:
                                          'Thao tác với ${member.username}',
                                      enabled: !disabled,
                                      onSelected:
                                          (action) =>
                                              _memberAction(action, member),
                                      itemBuilder:
                                          (_) => [
                                            if (data.isOwner) ...[
                                              PopupMenuItem(
                                                value: 'moderator',
                                                child: Text(
                                                  member.role == 1
                                                      ? 'Bỏ quyền quản lý'
                                                      : 'Cho quyền quản lý',
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'transfer',
                                                child: Text('Chuyển chủ phòng'),
                                              ),
                                            ],
                                            const PopupMenuItem(
                                              value: 'remove',
                                              child: Text('Loại khỏi nhóm'),
                                            ),
                                          ],
                                    )
                                    : null,
                          ),
                      ]),
                      if (data.isManager)
                        _section('Tài khoản bị chặn', [
                          if (management?.banned.isEmpty == true)
                            const Text('Không có tài khoản bị chặn.'),
                          for (final member
                              in management?.banned ?? <GroupRequest>[])
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(member.username),
                              trailing: TextButton(
                                onPressed:
                                    disabled
                                        ? null
                                        : () => _perform(
                                          () => repo.unban(
                                            data.id,
                                            member.userId,
                                          ),
                                        ),
                                child: const Text('Bỏ chặn'),
                              ),
                            ),
                        ]),
                      if (!data.isOwner)
                        OutlinedButton.icon(
                          onPressed:
                              disabled
                                  ? null
                                  : () async {
                                    if (await _confirm(
                                      'Rời nhóm?',
                                      'Bạn sẽ ngừng nhận tin nhắn của nhóm.',
                                    )) {
                                      if (mounted) {
                                        await _perform(
                                          () => repo.leave(data.id),
                                          leave: true,
                                        );
                                      }
                                    }
                                  },
                          icon: const Icon(RadixIcons.Exit),
                          label: const Text('Rời nhóm'),
                        ),
                      if (data.isOwner)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Chuyển chủ phòng cho thành viên khác trước khi rời nhóm.',
                          ),
                        ),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.symmetric(vertical: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}
