import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_user.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _roleNames = {'Admin': 'Quản trị viên', 'Mentor': 'Mentor', 'User': 'Học viên'};

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    // Signed out: the router is already on its way to login.
    if (user == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(child: UserAvatar(user: user, radius: 44)),
          const SizedBox(height: 12),
          Text(user.username, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          Text(user.email, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Vai trò'),
                  trailing: Text(_roleNames[user.role] ?? user.role),
                ),
                if (user.createdAt != null)
                  ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Thành viên từ'),
                    trailing: Text(formatDate(user.createdAt!)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Sửa hồ sơ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.editProfile),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Đổi mật khẩu'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.changePassword),
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppTheme.themeModeNotifier,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark;
                    return SwitchListTile(
                      secondary: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                      title: const Text('Giao diện tối (Dark Mode)'),
                      value: isDark,
                      onChanged: (_) => AppTheme.toggleTheme(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => context.read<AuthController>().logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Avatar image from [AppUser.avatarUrl], falling back to the username's initial.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 20});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = user.username.isEmpty ? '?' : user.username.characters.first.toUpperCase();
    final url = user.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundImage: url == null ? null : NetworkImage(url),
      // A broken avatar URL just shows the initial.
      onForegroundImageError: url == null ? null : (_, _) {},
      child: Text(initial, style: TextStyle(fontSize: radius * 0.8, color: Colors.white)),
    );
  }
}
