import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../config/app_updates.dart';

Future<void> _showUpdate(
  BuildContext context,
  AppUpdates updates,
  AndroidUpdate update,
) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Có bản cập nhật ${update.name}'),
      content: const Text(
        'Bạn có thể tiếp tục dùng phiên bản hiện tại và cập nhật khi thuận tiện.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Để sau'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Mở trang cập nhật'),
        ),
      ],
    ),
  );
  if (open != true || !context.mounted) return;
  try {
    await updates.open(update);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được trang cập nhật.')),
      );
    }
  }
}

/// The automatic check stays off the loading path for Home.
class AppUpdateNotice extends StatefulWidget {
  const AppUpdateNotice({super.key});

  @override
  State<AppUpdateNotice> createState() => _AppUpdateNoticeState();
}

class _AppUpdateNoticeState extends State<AppUpdateNotice> {
  AndroidUpdate? _update;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final update = await context.read<AppUpdates?>()!.check();
      if (mounted && update != null) setState(() => _update = update);
    } catch (_) {
      // A temporary update check failure should not interrupt study.
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    if (update == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(LucideIcons.download),
        title: Text('Có bản cập nhật ${update.name}'),
        subtitle: const Text('Chạm để xem bản mới'),
        trailing: IconButton(
          tooltip: 'Để sau',
          onPressed: () => setState(() => _update = null),
          icon: const Icon(LucideIcons.x),
        ),
        onTap: () async {
          await _showUpdate(context, context.read<AppUpdates?>()!, update);
          if (mounted) setState(() => _update = null);
        },
      ),
    );
  }
}

class AppVersionTile extends StatefulWidget {
  const AppVersionTile({super.key});

  @override
  State<AppVersionTile> createState() => _AppVersionTileState();
}

class _AppVersionTileState extends State<AppVersionTile> {
  late final _updates = context.read<AppUpdates?>()!;
  late final _installed = _updates.installed();
  bool _checking = false;

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final update = await _updates.check();
      if (!mounted) return;
      if (update != null) {
        await _showUpdate(context, _updates, update);
      } else {
        _notify('Hiện chưa có bản cập nhật phù hợp.');
      }
    } catch (_) {
      if (mounted) _notify('Chưa kiểm tra được cập nhật. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InstalledAppVersion>(
      future: _installed,
      builder: (context, snapshot) {
        final version = snapshot.data;
        return ListTile(
          leading: const Icon(LucideIcons.download),
          title: Text(_checking ? 'Đang kiểm tra…' : 'Kiểm tra cập nhật'),
          subtitle: version == null
              ? null
              : Text('Phiên bản ${version.name} · Bản dựng ${version.code}'),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: _checking ? null : _check,
        );
      },
    );
  }
}
