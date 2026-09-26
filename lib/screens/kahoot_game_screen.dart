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

  void _onAnswerSelected(int colorIndex) {
    if (_service.currentQuestion == null || _service.isAnswerSubmitted) return;

    final question = _service.currentQuestion!;
    final selectedAnswer = question.answers.firstWhere(
      (a) => a.colorIndex == colorIndex,
      orElse: () => question.answers.first,
    );

    double elapsed = 0.0;
    if (_questionStartTime != null) {
      elapsed = DateTime.now().difference(_questionStartTime!).inMilliseconds / 1000.0;
    }

    _service.submitAnswer(selectedAnswer.id, elapsed);
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
          backgroundColor: Colors.black26,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.nickname,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            Consumer<KahootSignalRService>(
              builder: (context, s, _) => Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${s.totalScore} pts',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Đang kết nối vào phòng...', style: TextStyle(color: Colors.white, fontSize: 18)),
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
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration, color: Colors.amber, size: 72),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bạn đã vào phòng!',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Mã PIN: ${widget.roomCode}',
              style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hãy nhìn lên màn hình chính và chờ chủ phòng bắt đầu trận đấu...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on, color: Colors.amber, size: 20),
                const SizedBox(width: 6),
                Text(
                  'CÂU ${q.questionIndex} / ${q.totalQuestions}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lưới 4 nút bấm màu sắc gradient lớn
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
                  onTap: () => _onAnswerSelected(index),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white30,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
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
                const SizedBox(height: 10),
                Text(
                  answerText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.greenAccent, size: 90),
          SizedBox(height: 20),
          Text(
            'Đã nhận câu trả lời!',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Đang chờ những người khác hoàn thành...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(KahootResultModel res) {
    final bool isCorrect = res.isCorrect;
    return Container(
      color: isCorrect ? KahootColors.green : KahootColors.red,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_outline : Icons.highlight_off,
            color: Colors.white,
            size: 100,
          ),
          const SizedBox(height: 16),
          Text(
            isCorrect ? 'CHÍNH XÁC!' : 'CHƯA ĐÚNG!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCorrect ? '+${res.scoreEarned} điểm' : '+0 điểm',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nhìn lên màn hình chính để xem bảng xếp hạng!',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverView(KahootSignalRService s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏁', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            const Text(
              'HOÀN THÀNH TRẬN ĐẤU!',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              'Tổng điểm: ${s.totalScore} pts',
              style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('VỀ TRANG CHỦ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
