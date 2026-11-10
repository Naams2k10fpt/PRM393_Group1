import 'json.dart';

/// One answer choice of a card. The same question also works as multiple choice,
/// so the backend ships every option with the card.
class FlashcardOption {
  const FlashcardOption({required this.id, required this.content, required this.isCorrect});

  final String id;
  final String content;
  final bool isCorrect;

  factory FlashcardOption.fromJson(Map<String, dynamic> json) => FlashcardOption(
        id: Json.id(json),
        content: Json.string(json, const ['content']),
        isCorrect: Json.boolean(json, const ['isCorrect']),
      );
}

/// Where this card sits in the user's review schedule. Null until the card has
/// been reviewed once.
class FlashcardProgress {
  const FlashcardProgress({required this.repetition, required this.nextReviewAtUtc});

  final int repetition;
  final DateTime? nextReviewAtUtc;

  factory FlashcardProgress.fromJson(Map<String, dynamic> json) => FlashcardProgress(
        repetition: Json.integer(json, const ['repetition']),
        nextReviewAtUtc: DateTime.tryParse(Json.string(json, const ['nextReviewAtUtc']))?.toLocal(),
      );
}

/// A card to study. Mirrors `ApiFlashcard` in PRN232.
///
/// The study screen keeps [content] visible while revealing each of [options].
/// Older cards without options use [correctAnswers] and [explanation] instead.
class Flashcard {
  const Flashcard({
    required this.questionId,
    required this.content,
    this.questionType = 0,
    this.explanation,
    this.correctAnswers = const [],
    this.options = const [],
    this.progress,
  });

  final String questionId;
  final String content;
  final int questionType;
  final String? explanation;
  final List<String> correctAnswers;
  final List<FlashcardOption> options;
  final FlashcardProgress? progress;

  /// The fallback answer for a card without choices.
  String get answerText =>
      correctAnswers.isEmpty ? (explanation ?? '') : correctAnswers.join('\n');

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['correctAnswers'];
    final rawOptions = json['options'];
    final rawProgress = json['progress'];

    return Flashcard(
      questionId: Json.id(json, const ['questionId', 'id']),
      content: Json.string(json, const ['content']),
      questionType: Json.integer(json, const ['questionType']),
      explanation: Json.stringOrNull(json, const ['explanation']),
      correctAnswers: rawAnswers is List ? rawAnswers.map((answer) => '$answer').toList() : const [],
      options: rawOptions is List
          ? rawOptions.whereType<Map<String, dynamic>>().map(FlashcardOption.fromJson).toList()
          : const [],
      progress: rawProgress is Map<String, dynamic> ? FlashcardProgress.fromJson(rawProgress) : null,
    );
  }
}

/// One study session: the cards plus the counters the deck header shows.
/// Mirrors `ApiFlashcardDeck`.
class FlashcardSession {
  const FlashcardSession({
    required this.deckId,
    required this.deckName,
    this.subjectName = '',
    this.totalCards = 0,
    this.dueCards = 0,
    this.studyingAll = false,
    this.nextReviewAtUtc,
    this.cards = const [],
  });

  final String deckId;
  final String deckName;
  final String subjectName;
  final int totalCards;
  final int dueCards;

  /// true when the session was asked for with `mode=all` rather than only due cards.
  final bool studyingAll;

  /// When the next card falls due, for the "nothing to review" state.
  final DateTime? nextReviewAtUtc;

  final List<Flashcard> cards;

  factory FlashcardSession.fromJson(Map<String, dynamic> json) => FlashcardSession(
        deckId: Json.id(json, const ['deckId', 'id']),
        deckName: Json.string(json, const ['deckName', 'name']),
        subjectName: Json.string(json, const ['subjectName']),
        totalCards: Json.integer(json, const ['totalCards']),
        dueCards: Json.integer(json, const ['dueCards']),
        studyingAll: Json.boolean(json, const ['studyingAll']),
        nextReviewAtUtc: DateTime.tryParse(Json.string(json, const ['nextReviewAtUtc']))?.toLocal(),
        // The list lives under `cards`, not a generic paging key.
        cards: Json.objects(json, const ['cards']).map(Flashcard.fromJson).toList(),
      );
}

/// What the backend answers to a review: the card's new place in the schedule.
class FlashcardReview {
  const FlashcardReview({
    required this.questionId,
    required this.repetition,
    required this.intervalMinutes,
    this.nextReviewAtUtc,
  });

  final String questionId;
  final int repetition;
  final int intervalMinutes;
  final DateTime? nextReviewAtUtc;

  factory FlashcardReview.fromJson(Map<String, dynamic> json) => FlashcardReview(
        questionId: Json.id(json, const ['questionId']),
        repetition: Json.integer(json, const ['repetition']),
        intervalMinutes: Json.integer(json, const ['intervalMinutes']),
        nextReviewAtUtc: DateTime.tryParse(Json.string(json, const ['nextReviewAtUtc']))?.toLocal(),
      );
}
