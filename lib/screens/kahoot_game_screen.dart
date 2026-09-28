import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/kahoot_signalr_service.dart';

class KahootGameScreen extends StatefulWidget {
  final String roomCode;
  final String nickname;

  const KahootGameScreen({
    super.key,
    required this.roomCode,
    required this.nickname,
  });

  @override
  State<KahootGameScreen> createState() => _KahootGameScreenState();
}

class _KahootGameScreenState extends State<KahootGameScreen> {
  late KahootSignalRService _service;
  DateTime? _questionStartTime;

  @override
  void initState() {
    super.initState();
    _service = KahootSignalRService();
    _initConnection();
  }

  void _initConnection() async {
    try {
      await _service.connect(widget.roomCode, widget.nickname);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối: $e')),
        );
      }
    }
  }

  void _onAnswerSelected(KahootAnswerChoice ans) {
    if (_service.currentQuestion == null || _service.isAnswerSubmitted) return;

    double elapsed = 0.0;
    if (_questionStartTime != null) {
      elapsed = DateTime.now().difference(_questionStartTime!).inMilliseconds / 1000.0;
    }

    _service.submitAnswer(ans.id, elapsed);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _service,
      child: Scaffold(
        backgroundColor: KahootColors.background,
        appBar: AppBar(
          backgroundColor: KahootColors.surface,
          elevation: 0,
          shape: const Border(
            bottom: BorderSide(color: KahootColors.border, width: 1),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: KahootColors.textMuted),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              const Icon(Icons.person_rounded, size: 20, color: KahootColors.cyan),
              const SizedBox(width: 8),
              Text(
                widget.nickname,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: KahootColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: KahootColors.elevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: KahootColors.border),
                ),
                child: Text(
                  widget.roomCode,
                  style: const TextStyle(
                    color: KahootColors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Consumer<KahootSignalRService>(
              builder: (context, s, _) => Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${s.totalScore} pts',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Consumer<KahootSignalRService>(
          builder: (context, s, _) {
            if (!s.isConnected) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: KahootColors.accent),
                    SizedBox(height: 18),
                    Text(
                      'Đang kết nối vào đấu trường...',
                      style: TextStyle(
                        color: KahootColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (s.isGameOver) {
              return _buildGameOverView(s);
            }

            if (s.lastAnswerResult != null) {
              return _buildResultView(s.lastAnswerResult!);
            }

            if (s.isAnswerSubmitted) {
              return _buildSubmittedWaitingView();
            }

            if (s.currentQuestion != null) {
              _questionStartTime ??= DateTime.now();
              return _buildAnsweringView(s.currentQuestion!);
            }

            // Mặc định ở phòng chờ Lobby
            return _buildLobbyWaitingView();
          },
        ),
      ),
    );
  }

  Widget _buildLobbyWaitingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: KahootColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: KahootColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [KahootColors.accent.withValues(alpha: 0.2), KahootColors.cyan.withValues(alpha: 0.15)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: KahootColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.flash_on_rounded, color: KahootColors.cyan, size: 44),
              ),
              const SizedBox(height: 24),
              const Text(
                'SẴN SÀNG CHIẾN ĐẤU!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KahootColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: KahootColors.elevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KahootColors.border),
                ),
                child: Text(
                  'PHÒNG: ${widget.roomCode}',
                  style: const TextStyle(
                    color: KahootColors.cyan,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bạn đã vào phòng thi đấu an toàn.\nHãy nhìn lên màn hình chính của Host và chờ trận đấu bắt đầu!',
                textAlign: TextAlign.center,
                style: TextStyle(color: KahootColors.textMuted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: KahootColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnsweringView(KahootQuestionModel q) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          // Header câu hỏi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: KahootColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: KahootColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: KahootColors.warning, size: 20),
                const SizedBox(width: 6),
                Text(
                  'CÂU HỎI ${q.questionIndex} / ${q.totalQuestions}',
                  style: const TextStyle(
                    color: KahootColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lưới 4 nút bấm phong cách Cyber Arena
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.95,
              children: List.generate(q.answers.length, (index) {
                final ans = q.answers[index];
                return _buildKahootButton(
                  gradient: KahootColors.answerGradients[index % 4],
                  letter: KahootColors.answerShapes[index % 4],
                  answerText: ans.text,
                  onTap: () => _onAnswerSelected(ans),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKahootButton({
    required LinearGradient gradient,
    required String letter,
    required String answerText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: Colors.white30,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  answerText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmittedWaitingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: KahootColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: KahootColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: KahootColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: KahootColors.success.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.shield_outlined, color: KahootColors.success, size: 44),
              ),
              const SizedBox(height: 24),
              const Text(
                'ĐÃ KHÓA LỰA CHỌN!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KahootColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Lựa chọn của bạn đã được gửi an toàn lên hệ thống.\nĐang chờ thời gian kết thúc để chấm điểm...',
                textAlign: TextAlign.center,
                style: TextStyle(color: KahootColors.textMuted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: KahootColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultView(KahootResultModel res) {
    final bool isCorrect = res.isCorrect;
    final color = isCorrect ? KahootColors.success : KahootColors.danger;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: KahootColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: color,
                  size: 52,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isCorrect ? 'CHÍNH XÁC!' : 'CHƯA ĐÚNG!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: KahootColors.elevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KahootColors.border),
                ),
                child: Text(
                  isCorrect ? '+${res.scoreEarned} điểm' : '+0 điểm',
                  style: TextStyle(
                    color: isCorrect ? KahootColors.warning : KahootColors.textMuted,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Hãy nhìn lên màn hình chính để xem thứ hạng!',
                textAlign: TextAlign.center,
                style: TextStyle(color: KahootColors.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverView(KahootSignalRService s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: KahootColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: KahootColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              const Text(
                'HOÀN THÀNH TRẬN ĐẤU!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KahootColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: KahootColors.elevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: KahootColors.border),
                ),
                child: Text(
                  'Tổng điểm: ${s.totalScore} pts',
                  style: const TextStyle(
                    color: KahootColors.warning,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [KahootColors.accent, Color(0xFF4F46E5)],
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
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('VỀ TRANG CHỦ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
