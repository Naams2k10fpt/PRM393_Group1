import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../core/config.dart';

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

class KahootSignalRService extends ChangeNotifier {
  HubConnection? _hubConnection;
  
  int participantId = 0;
  String currentRoomCode = '';
  String currentNickname = '';
  int totalScore = 0;

  KahootQuestionModel? currentQuestion;
  KahootResultModel? lastAnswerResult;
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

    _hubConnection = HubConnectionBuilder()
        .withUrl(AppConfig.kahootHubUrl)
        .withAutomaticReconnect()
        .build();

    _hubConnection!.on('JoinedSuccess', _handleJoinedSuccess);
    _hubConnection!.on('ReceiveQuestion', _handleReceiveQuestion);
    _hubConnection!.on('AnswerResult', _handleAnswerResult);
    _hubConnection!.on('QuestionEnded', _handleQuestionEnded);
    _hubConnection!.on('GameOver', _handleGameOver);

    await _hubConnection!.start();
    isConnected = true;
    notifyListeners();

    // Gọi JoinRoom lên server (userId là optional param, mặc định null)
    await _hubConnection!.invoke('JoinRoom', args: [currentRoomCode, currentNickname]);
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
      isAnswerSubmitted = false;
      lastAnswerResult = null;
      _questionStreamController.add(currentQuestion!);
      notifyListeners();
    }
  }

  void _handleAnswerResult(List<dynamic>? args) {
    if (args != null && args.isNotEmpty) {
      final map = args[0] as Map<String, dynamic>;
      lastAnswerResult = KahootResultModel.fromMap(map);
      totalScore = lastAnswerResult!.totalScore;
      _resultStreamController.add(lastAnswerResult!);
      notifyListeners();
    }
  }

  void _handleQuestionEnded(List<dynamic>? args) {
    notifyListeners();
  }

  void _handleGameOver(List<dynamic>? args) {
    isGameOver = true;
    notifyListeners();
  }

  Future<void> submitAnswer(int selectedAnswerId, double elapsedSeconds) async {
    if (_hubConnection == null || currentQuestion == null || participantId == 0) return;

    isAnswerSubmitted = true;
    notifyListeners();

    await _hubConnection!.invoke('SubmitAnswer', args: [
      currentRoomCode,
      participantId,
      currentQuestion!.questionId,
      selectedAnswerId,
      elapsedSeconds,
    ]);
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
