import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_screen.dart';

/// Placeholder home until the Home/Subjects screens (Person 2) land. Lists the features that exist.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Management'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Hồ sơ',
              icon: UserAvatar(user: user, radius: 16),
              onPressed: () => context.push(AppRoutes.profile),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Quiz cá nhân'),
              subtitle: const Text('Làm bài, xem kết quả và lịch sử'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.quiz),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Nhóm học'),
              subtitle: const Text('Tham gia và trò chuyện thời gian thực'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.groups),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sports_esports_outlined),
              title: const Text('Kahoot Live'),
              subtitle: const Text('Nhập mã PIN hoặc quét QR để vào phòng'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.kahoot),
            ),
          ),
        ],
      ),
    );
  }
}
