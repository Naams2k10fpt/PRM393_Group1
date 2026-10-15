import '../api/api_client.dart';
import '../models/flashcard.dart';

/// `/api/decks/{id}/flashcards` and `/api/flashcards/progress`.
///
/// The backend schedules each card on its own (repetition, interval, next review),
/// so a review is one request per card rather than one batch per session.
class FlashcardRepository {
  FlashcardRepository(this._api);

  final ApiClient _api;

  /// Cards to study. `due` (the default) is new and due cards; `all` is the
  /// whole deck, for a user who wants to revise ahead of schedule.
  Future<FlashcardSession> session(String deckId, {bool studyAll = false}) async {
    final body = await _api.get(
      '/api/decks/$deckId/flashcards',
      query: {'mode': studyAll ? 'all' : 'due'},
    );
    return FlashcardSession.fromJson(body as Map<String, dynamic>);
  }

  /// Records one card and returns where the backend put it in the schedule.
  Future<FlashcardReview> review({
    required String deckId,
    required String questionId,
    required bool remembered,
  }) async {
    final body = await _api.post('/api/flashcards/progress', data: {
      // The backend binds these as ints, so send numbers when the ids are numeric.
      'deckId': _asNumberOrString(deckId),
      'questionId': _asNumberOrString(questionId),
      'remembered': remembered,
    });
    return FlashcardReview.fromJson(body as Map<String, dynamic>);
  }

  static Object _asNumberOrString(String value) => int.tryParse(value) ?? value;
}
