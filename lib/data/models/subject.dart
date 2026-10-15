import 'json.dart';

/// A subject on the Home grid. Mirrors `ApiSubject` in PRN232; the backend sends
/// no description or icon, so those stay null unless it grows them later.
class Subject {
  const Subject({
    required this.id,
    required this.name,
    this.ownerName = '',
    this.description,
    this.deckCount = 0,
    this.questionCount = 0,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String ownerName;
  final String? description;
  final int deckCount;
  final int questionCount;
  final String? iconUrl;

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: Json.id(json, const ['id', 'subjectId']),
        name: Json.string(json, const ['name', 'title', 'subjectName']),
        ownerName: Json.string(json, const ['ownerName']),
        description: Json.stringOrNull(json, const ['description', 'summary']),
        deckCount: Json.integer(json, const ['deckCount', 'decksCount', 'totalDecks']),
        questionCount: Json.integer(json, const ['questionCount', 'totalQuestions']),
        iconUrl: Json.stringOrNull(json, const ['iconUrl', 'imageUrl', 'thumbnailUrl']),
      );
}
