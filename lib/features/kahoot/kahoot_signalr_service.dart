import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../../core/config/app_config.dart';

class KahootQuestionModel {
  final int questionIndex;
  final int totalQuestions;
  final int questionId;
  final String content;
  final int timeLimit;
  final List<KahootAnswerChoice> answers;

  KahootQuestionModel({
    required this.questionIndex,
    required this.totalQuestions,
    required this.questionId,
    required this.content,
    required this.timeLimit,
    required this.answers,
  });

  factory KahootQuestionModel.fromMap(Map<String, dynamic> map) {
    var rawAnswers = map['answers'] as List<dynamic>? ?? [];
    return KahootQuestionModel(
      questionIndex: map['questionIndex'] as int? ?? 1,
      totalQuestions: map['totalQuestions'] as int? ?? 1,
      questionId: map['questionId'] as int? ?? 0,
      content: map['content'] as String? ?? '',
      timeLimit: map['timeLimit'] as int? ?? 20,
      answers: rawAnswers.map((a) => KahootAnswerChoice.fromMap(a as Map<String, dynamic>)).toList(),
    );
  }
}

class KahootAnswerChoice {
  final int id;
  final String text;
  final int colorIndex;

  KahootAnswerChoice({
    required this.id,
    required this.text,
    required this.colorIndex,
  });

  factory KahootAnswerChoice.fromMap(Map<String, dynamic> map) {
    return KahootAnswerChoice(
      id: map['id'] as int? ?? 0,
      text: map['text'] as String? ?? '',
      colorIndex: map['colorIndex'] as int? ?? 0,
    );
  }
}

class KahootResultModel {
  final bool isCorrect;
  final int scoreEarned;
  final int totalScore;

  KahootResultModel({
    required this.isCorrect,
    required this.scoreEarned,
    required this.totalScore,
  });

  factory KahootResultModel.fromMap(Map<String, dynamic> map) {
    return KahootResultModel(
      isCorrect: map['isCorrect'] as bool? ?? false,
      scoreEarned: map['scoreEarned'] as int? ?? 0,
      totalScore: map['totalScore'] as int? ?? 0,
    );
  }
}

class KahootLeaderboardItem {
  final int rank;
  final String nickname;
  final int score;
  final int participantId;

  KahootLeaderboardItem({
    required this.rank,
    required this.nickname,
    required this.score,
    required this.participantId,
  });

  factory KahootLeaderboardItem.fromMap(Map<String, dynamic> map) {
    return KahootLeaderboardItem(
      rank: map['rank'] as int? ?? 0,
      nickname: map['nickname'] as String? ?? '',
      score: map['score'] as int? ?? (map['totalScore'] as int? ?? 0),
      participantId: map['participantId'] as int? ?? 0,
    );
  }
}

class KahootSignalRService extends ChangeNotifier {
  HubConnection? _hubConnection;
  
  int participantId = 0;
  String currentRoomCode = '';
  String currentNickname = '';
  int totalScore = 0;

  KahootQuestionModel? currentQuestion;
  KahootResultModel? lastAnswerResult;
  KahootResultModel? pendingAnswerResult;
  bool isLeaderboardRevealed = false;
  DateTime? questionReceivedAt;
  int? questionEndedCorrectAnswerId;
  List<KahootLeaderboardItem> currentLeaderboard = [];
  List<KahootLeaderboardItem> podium = [];
  String? lastErrorMessage;

  bool isConnected = false;
  bool isAnswerSubmitted = false;
  bool isGameOver = false;

  final _questionStreamController = StreamController<KahootQuestionModel>.broadcast();
  Stream<KahootQuestionModel> get onQuestionReceived => _questionStreamController.stream;

  final _resultStreamController = StreamController<KahootResultModel>.broadcast();
  Stream<KahootResultModel> get onAnswerResult => _resultStreamController.stream;

  Future<void> connect(String roomCode, String nickname) async {
    currentRoomCode = roomCode.trim().toUpperCase();
    currentNickname = nickname.trim();
    lastErrorMessage = null;

    _hubConnection = HubConnectionBuilder()
        .withUrl(AppConfig.kahootHubUrl)
        .withAutomaticReconnect()
        .build();

    _hubConnection!.onreconnected(({connectionId}) {
      isConnected = true;
      notifyListeners();
      // Khôi phục phiên kết nối phòng chơi khi mạng reconnect
      if (currentRoomCode.isNotEmpty && currentNickname.isNotEmpty) {
        _hubConnection!.invoke('JoinRoom', args: [currentRoomCode, currentNickname, '']).catchError((_) {});
      }
    });

    _hubConnection!.on('JoinedSuccess', _handleJoinedSuccess);
    _hubConnection!.on('ReceiveQuestion', _handleReceiveQuestion);
    _hubConnection!.on('AnswerResult', _handleAnswerResult);
    _hubConnection!.on('QuestionEnded', _handleQuestionEnded);
    _hubConnection!.on('LeaderboardShown', _handleLeaderboardShown);
    _hubConnection!.on('GameOver', _handleGameOver);
    _hubConnection!.on('Error', _handleError);

    await _hubConnection!.start();
    isConnected = true;
    notifyListeners();

    // Gọi JoinRoom lên server với 3 tham số (userId = '' cho khách vãng lai)
    await _hubConnection!.invoke('JoinRoom', args: [currentRoomCode, currentNickname, '']);
  }

  void _handleJoinedSuccess(List<dynamic>? args) {
    if (args != null && args.isNotEmpty) {
      final data = args[0] as Map<String, dynamic>;
      participantId = data['participantId'] as int? ?? 0;
      notifyListeners();
    }
  }

  void _handleReceiveQuestion(List<dynamic>? args) {
    if (args != null && args.isNotEmpty) {
      final map = args[0] as Map<String, dynamic>;
      currentQuestion = KahootQuestionModel.fromMap(map);
      questionReceivedAt = DateTime.now();
      isAnswerSubmitted = false;
      lastAnswerResult = null;
      pendingAnswerResult = null;
      isLeaderboardRevealed = false;
      questionEndedCorrectAnswerId = null;
      lastErrorMessage = null;
      _questionStreamController.add(currentQuestion!);
      notifyListeners();
    }
  }

  void _handleAnswerResult(List<dynamic>? args) {
    if (args != null && args.isNotEmpty) {
      final map = args[0] as Map<String, dynamic>;
      // Lưu tạm kết quả chấm điểm từ server, KHÔNG hiển thị và KHÔNG cộng điểm ngay
      // Người chơi giữ nguyên màn hình chờ đã nộp cho tới khi chủ phòng mở bảng điểm
      pendingAnswerResult = KahootResultModel.fromMap(map);
      notifyListeners();
    }
  }

  void _handleLeaderboardShown(List<dynamic>? args) {
    isLeaderboardRevealed = true;
    if (pendingAnswerResult != null) {
      lastAnswerResult = pendingAnswerResult;
      totalScore = lastAnswerResult!.totalScore;
      _resultStreamController.add(lastAnswerResult!);
    }
    if (args != null && args.isNotEmpty) {
      final map = args[0] as Map<String, dynamic>;
      final rawBoard = map['leaderboard'] as List<dynamic>? ?? [];
      currentLeaderboard = rawBoard
          .map((item) => KahootLeaderboardItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  void _handleQuestionEnded(List<dynamic>? args) {
    if (args != null && args.isNotEmpty) {
      final map = args[0] as Map<String, dynamic>;
      questionEndedCorrectAnswerId = map['correctAnswerId'] as int?;
      final rawBoard = map['leaderboard'] as List<dynamic>? ?? [];
      currentLeaderboard = rawBoard
          .map((item) => KahootLeaderboardItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  void _handleGameOver(List<dynamic>? args) {
    isGameOver = true;
    if (pendingAnswerResult != null && lastAnswerResult == null) {
      lastAnswerResult = pendingAnswerResult;
      totalScore = lastAnswerResult!.totalScore;
    }
    if (args != null && args.isNotEmpty) {
      final map = args[0] as Map<String, dynamic>;
      final rawPodium = map['podium'] as List<dynamic>? ?? [];
      final rawBoard = map['fullLeaderboard'] as List<dynamic>? ?? [];
      podium = rawPodium
          .map((item) => KahootLeaderboardItem.fromMap(item as Map<String, dynamic>))
          .toList();
      currentLeaderboard = rawBoard
          .map((item) => KahootLeaderboardItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  void _handleError(List<dynamic>? args) {
    if (args != null && args.isNotEmpty) {
      lastErrorMessage = args[0]?.toString() ?? 'Lỗi kết nối phòng đấu';
      isAnswerSubmitted = false;
      notifyListeners();
    }
  }

  Future<void> submitAnswer(int selectedAnswerId, [double? elapsedSeconds]) async {
    if (_hubConnection == null || currentQuestion == null || participantId == 0) return;

    double calculatedElapsed = elapsedSeconds ?? 0.0;
    if (elapsedSeconds == null && questionReceivedAt != null) {
      calculatedElapsed = DateTime.now().difference(questionReceivedAt!).inMilliseconds / 1000.0;
    }

    isAnswerSubmitted = true;
    notifyListeners();

    try {
      await _hubConnection!.invoke('SubmitAnswer', args: [
        currentRoomCode,
        participantId,
        currentQuestion!.questionId,
        selectedAnswerId,
        calculatedElapsed,
      ]);
    } catch (e) {
      lastErrorMessage = e.toString();
      isAnswerSubmitted = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _hubConnection = null;
      isConnected = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _questionStreamController.close();
    _resultStreamController.close();
    disconnect();
    super.dispose();
  }
}
