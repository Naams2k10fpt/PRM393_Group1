import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'kahoot_colors.dart';
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
        SnackBar(
          content: Text('Đã nhận mã PIN: $scannedPin'),
          backgroundColor: KahootColors.accent,
        ),
      );
    }
  }

  void _joinGame() {
    final pin = _pinController.text.trim().toUpperCase();
    final nickname = _nicknameController.text.trim();

    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mã PIN hoặc quét mã QR'),
          backgroundColor: KahootColors.danger,
        ),
      );
      return;
    }

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập biệt danh của bạn'),
          backgroundColor: KahootColors.danger,
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KahootColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Header
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: KahootColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: KahootColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    LucideIcons.gamepad2,
                    color: KahootColors.accent,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [KahootColors.accent, KahootColors.cyan],
                  ).createShader(bounds),
                  child: const Text(
                    'QUIZ ARENA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đấu trường thi đấu trắc nghiệm thời gian thực',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: KahootColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),

                // Modern Glass Card
                Container(
                  decoration: BoxDecoration(
                    color: KahootColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: KahootColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Label PIN
                      const Text(
                        'MÃ PHÒNG (PIN)',
                        style: TextStyle(
                          color: KahootColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // PIN Input
                      TextField(
                        controller: _pinController,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: KahootColors.cyan,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: '6 KÝ TỰ',
                          hintStyle: const TextStyle(
                            color: KahootColors.textDim,
                            letterSpacing: 2,
                            fontSize: 18,
                          ),
                          filled: true,
                          fillColor: KahootColors.elevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: KahootColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: KahootColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: KahootColors.cyan, width: 2),
                          ),
                          prefixIcon: const Icon(LucideIcons.hash, color: KahootColors.cyan),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Nút quét QR Code
                      OutlinedButton.icon(
                        onPressed: _openQrScanner,
                        icon: const Icon(LucideIcons.qrCode, color: KahootColors.cyan, size: 20),
                        label: const Text(
                          'Quét mã QR từ Host',
                          style: TextStyle(
                            color: KahootColors.cyan,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: KahootColors.cyan, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: KahootColors.cyan.withValues(alpha: 0.05),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Label Nickname
                      const Text(
                        'BIỆT DANH THÍ SINH',
                        style: TextStyle(
                          color: KahootColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Nickname Input
                      TextField(
                        controller: _nicknameController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: KahootColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập biệt danh của bạn...',
                          hintStyle: const TextStyle(color: KahootColors.textDim, fontSize: 15),
                          filled: true,
                          fillColor: KahootColors.elevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: KahootColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: KahootColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: KahootColors.accent, width: 2),
                          ),
                          prefixIcon: const Icon(LucideIcons.userRound, color: KahootColors.accent),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Nút Tham gia Gradient sang trọng
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [KahootColors.accent, Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: KahootColors.accent.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _joinGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.zap, size: 22),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'VÀO ĐẤU TRƯỜNG',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.lockKeyhole, size: 14, color: KahootColors.textDim),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Realtime WebSocket • Quiz Arena System',
                        style: TextStyle(color: KahootColors.textDim, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

