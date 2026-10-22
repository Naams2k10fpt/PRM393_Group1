import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import 'auth_controller.dart';

/// Shown while the stored token is checked. The router leaves this screen once the status is known;
/// if the check failed (offline, server waking up) the user can retry or log in again.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final error = auth.startupError;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandEmblem(size: 80),
              const SizedBox(height: 16),
              Text(
                'QuizMS',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 32),
              if (error == null) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Đang kết nối máy chủ…',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ] else ...[
                Text(error.message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: auth.restoreSession,
                  child: const Text('Thử lại'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: auth.logout,
                  child: const Text('Đăng nhập lại'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
