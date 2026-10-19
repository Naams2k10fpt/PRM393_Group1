import 'json.dart';

/// A deck inside a [Subject]. Mirrors `ApiDeck` in PRN232.
///
/// [dueCount] and [learnedCount] are this user's flashcard progress in the deck,
/// so the list can show what is waiting to be reviewed.
class Deck {
  const Deck({
    required this.id,
    required this.title,
    this.subjectId,
    this.subjectName = '',
    this.description,
    this.cardCount = 0,
    this.timeLimitMinutes = 0,
    this.dueCount = 0,
    this.learnedCount = 0,
    this.nextReviewAtUtc,
  });

  final String id;

  /// `name` on the backend; kept as `title` because that is what the UI calls it.
  final String title;

  final String? subjectId;
  final String subjectName;
  final String? description;

  /// Number of questions in the deck — the number of cards to study.
  final int cardCount;

  final int timeLimitMinutes;
  final int dueCount;
  final int learnedCount;
  final DateTime? nextReviewAtUtc;

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        id: Json.id(json, const ['id', 'deckId']),
        title: Json.string(json, const ['name', 'title', 'deckName']),
        subjectId: Json.stringOrNull(json, const ['subjectId']),
        subjectName: Json.string(json, const ['subjectName']),
        description: Json.stringOrNull(json, const ['description', 'summary']),
        cardCount: Json.integer(json, const ['questionCount', 'cardCount', 'totalCards']),
        timeLimitMinutes: Json.integer(json, const ['timeLimitMinutes']),
        dueCount: Json.integer(json, const ['dueCount']),
        learnedCount: Json.integer(json, const ['learnedCount']),
        nextReviewAtUtc: DateTime.tryParse(Json.string(json, const ['nextReviewAtUtc']))?.toLocal(),
      );
}
