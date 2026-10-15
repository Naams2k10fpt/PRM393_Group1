import '../api/api_client.dart';
import '../models/deck.dart';
import '../models/json.dart';
import '../models/subject.dart';

/// `/api/subjects` and `/api/decks`. Read-only catalogue behind the Home and Deck
/// screens. Failures stay as [ApiException] for the controller to show.
class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  /// Subjects for the Home grid, each with its deck count.
  Future<List<Subject>> subjects() async {
    final body = await _api.get('/api/subjects');
    return Json.objects(body).map(Subject.fromJson).toList();
  }

  /// Decks inside one subject.
  Future<List<Deck>> decksOfSubject(String subjectId) async {
    final body = await _api.get('/api/subjects/$subjectId/decks');
    return Json.objects(body).map(Deck.fromJson).toList();
  }

  /// One deck, for the detail screen reached by deep link, where the list that
  /// would have carried the deck was never loaded.
  Future<Deck> deck(String deckId) async {
    final body = await _api.get('/api/decks/$deckId');
    return Deck.fromJson(body as Map<String, dynamic>);
  }
}
