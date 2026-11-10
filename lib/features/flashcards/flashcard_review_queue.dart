import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

class PendingFlashcardReview {
  const PendingFlashcardReview(this.id, this.questionId, this.remembered);

  factory PendingFlashcardReview.create(String questionId, bool remembered) {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    return PendingFlashcardReview(id, questionId, remembered);
  }

  factory PendingFlashcardReview.decode(String value) {
    final fields = jsonDecode(value) as List<dynamic>;
    return PendingFlashcardReview(
      fields[0] as String,
      fields[1] as String,
      fields[2] as bool,
    );
  }

  final String id;
  final String questionId;
  final bool remembered;

  String encode() => jsonEncode([id, questionId, remembered]);
}

/// Writes are serialized even when a study screen is being closed/reopened.
class FlashcardReviewQueue {
  FlashcardReviewQueue(String userId, String deckId)
    : _key =
          'flashcard.reviews.v1.${jsonEncode([AppConfig.baseUrl, userId, deckId])}';

  final String _key;
  static Future<void>? _writes;

  Future<List<PendingFlashcardReview>> read() async {
    if (_writes case final writes?) await writes;
    return _read(await SharedPreferences.getInstance());
  }

  List<PendingFlashcardReview> _read(SharedPreferences prefs) => [
    for (final value in prefs.getStringList(_key) ?? <String>[])
      PendingFlashcardReview.decode(value),
  ];

  Future<void> add(PendingFlashcardReview review) =>
      _update((items) => items.add(review));

  Future<void> remove(String reviewId) =>
      _update((items) => items.removeWhere((item) => item.id == reviewId));

  Future<void> _update(void Function(List<PendingFlashcardReview>) change) {
    final write = (_writes ?? Future<void>.value()).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final items = _read(prefs);
      change(items);
      try {
        final saved = items.isEmpty
            ? await prefs.remove(_key)
            : await prefs.setStringList(
                _key,
                items.map((item) => item.encode()).toList(),
              );
        if (!saved) throw StateError('Could not write flashcard review queue');
      } catch (_) {
        await prefs.reload();
        rethrow;
      }
    });
    late final Future<void> tail;
    tail = write.then((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_writes, tail)) _writes = null;
    });
    _writes = tail;
    return write;
  }
}
