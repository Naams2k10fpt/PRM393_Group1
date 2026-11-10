import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'qr_scanner_screen.dart';
import '../../core/theme/app_theme.dart';
import 'kahoot_game_screen.dart';

class KahootEntryScreen extends StatefulWidget {
  const KahootEntryScreen({super.key});

  @override
  State<KahootEntryScreen> createState() => _KahootEntryScreenState();
}

class _KahootEntryScreenState extends State<KahootEntryScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  void _openQrScanner() async {
    final scannedPin = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    if (!mounted) return;
    if (scannedPin != null && scannedPin.isNotEmpty) {
      _pinController.text = scannedPin;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đã nhận mã PIN: $scannedPin')));
    }
  }

  void _joinGame() {
    final pin = _pinController.text.trim().toUpperCase();
    final nickname = _nicknameController.text.trim();

    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã PIN hoặc quét mã QR')),
      );
      return;
    }

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập biệt danh của bạn')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Theme(
          data: AppTheme.dark(),
          child: KahootGameScreen(roomCode: pin, nickname: nickname),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kahoot Live')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Tham gia phòng', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        'Nhập mã do người tổ chức cung cấp.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pinController,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Mã phòng (PIN)',
                          prefixIcon: Icon(LucideIcons.hash),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _openQrScanner,
                        icon: const Icon(LucideIcons.qrCode, size: 18),
                        label: const Text('Quét mã QR'),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _nicknameController,
                        onSubmitted: (_) => _joinGame(),
                        decoration: const InputDecoration(
                          labelText: 'Biệt danh',
                          prefixIcon: Icon(LucideIcons.userRound),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _joinGame,
                        icon: const Icon(LucideIcons.logIn, size: 18),
                        label: const Text('Vào phòng'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
