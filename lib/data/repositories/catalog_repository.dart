import '../api/api_client.dart';
import '../models/deck.dart';
import '../models/json.dart';
import '../models/subject.dart';

enum FavoriteKind { subject, deck }

/// Catalogue and account favorites behind the Home and Deck
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

  Future<Set<String>> favoriteIds(FavoriteKind kind) async {
    final ids = await _api.get('/api/favorites/${kind.name}s') as List;
    return ids.map((id) => id.toString()).toSet();
  }

  Future<void> setFavorite(
    String accountId,
    FavoriteKind kind,
    String id,
    bool favorite,
  ) async {
    await _api.put(
      '/api/favorites/${kind.name}s/$id',
      data: {'accountId': accountId, 'favorite': favorite},
    );
  }

  Future<void> importFavorites(
    String accountId,
    FavoriteKind kind,
    List<String> legacyIds,
  ) async {
    final ids = legacyIds
        .map(int.tryParse)
        .whereType<int>()
        .where((id) => id > 0 && id <= 2147483647)
        .toSet()
        .toList();
    const batchSize = 500;
    for (var start = 0; start < ids.length; start += batchSize) {
      await _api.post(
        '/api/favorites/${kind.name}s/import',
        data: {
          'accountId': accountId,
          'ids': ids.skip(start).take(batchSize).toList(),
        },
      );
    }
  }
}
