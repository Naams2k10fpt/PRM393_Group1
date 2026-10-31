import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/liquid_glass_logo.dart';
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
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LiquidGlassLogo(height: 320, logoSize: 200),
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(
                  error.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
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
