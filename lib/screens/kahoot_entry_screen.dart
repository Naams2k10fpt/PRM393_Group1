import 'package:flutter/material.dart';
import '../core/config.dart';
import '../core/theme.dart';
import 'qr_scanner_screen.dart';
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

    if (scannedPin != null && scannedPin.isNotEmpty) {
      setState(() {
        _pinController.text = scannedPin;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã nhận mã PIN: $scannedPin')),
      );
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
        builder: (context) => KahootGameScreen(
          roomCode: pin,
          nickname: nickname,
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final urlController = TextEditingController(text: AppConfig.baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cấu hình Server Backend'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'Server Base URL',
            hintText: 'http://10.0.2.2:5039 hoặc link Render',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              AppConfig.baseUrl = urlController.text.trim();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã lưu URL: ${AppConfig.baseUrl}')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KahootColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Cài đặt kết nối server',
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              const Text(
                'KAHOOT!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Quiz Management Mobile',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 36),

              // Card Input
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // PIN Input
                      TextField(
                        controller: _pinController,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'MÃ PIN (6 SỐ)',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.pin),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Nút quét QR Code
                      OutlinedButton.icon(
                        onPressed: _openQrScanner,
                        icon: const Icon(Icons.qr_code_scanner, color: KahootColors.blue),
                        label: const Text(
                          'Quét mã QR bằng Camera',
                          style: TextStyle(color: KahootColors.blue, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: KahootColors.blue, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Nickname Input
                      TextField(
                        controller: _nicknameController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Biệt danh của bạn',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Nút Tham gia
                      ElevatedButton(
                        onPressed: _joinGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        child: const Text(
                          'THAM GIA NGAY',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
