import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../auth/auth_controller.dart';

/// Placeholder home until the Home/Subjects screens (Person 2) land. Lists the features that exist.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Management'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthController>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
