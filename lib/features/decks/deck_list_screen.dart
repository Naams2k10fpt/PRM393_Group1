import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/deck.dart';
import '../../data/repositories/catalog_repository.dart';
import '../auth/auth_controller.dart';
import '../catalog/catalog_favorites.dart';

/// The decks inside one subject. [subjectName] comes from the Home grid as
/// `extra`; a deep link has none, so the title falls back to a generic one.
class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key, required this.subjectId, this.subjectName});

  final String subjectId;
  final String? subjectName;

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  bool _busy = true;
  ApiException? _error;
  List<Deck> _decks = const [];
  late final _favorites = CatalogFavorites(
    context.read<AuthController>().user!.id,
    FavoriteKind.deck,
  );

  @override
  void initState() {
    super.initState();
    _favorites.restore();
    _load();
  }

  @override
  void dispose() {
    _favorites.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final catalog = context.read<CatalogRepository>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final decks = await catalog.decksOfSubject(widget.subjectId);
      if (!mounted) return;
      setState(() {
        _decks = decks;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subjectName ?? 'Bộ đề')),
      body: ListenableBuilder(
        listenable: _favorites,
        builder: (context, _) =>
            RefreshIndicator(onRefresh: _load, child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_busy) return const Center(child: CircularProgressIndicator());

    final error = _error;
    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          ErrorBanner(
            message: error.message,
            action: TextButton(onPressed: _load, child: const Text('Thử lại')),
          ),
        ],
      );
    }

    final variantColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (_decks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 16),
        children: [
          Icon(LucideIcons.archive, size: 40, color: variantColor),
          const SizedBox(height: 12),
          Text(
            'Môn học này chưa có bộ đề nào.',
            textAlign: TextAlign.center,
            style: TextStyle(color: variantColor),
          ),
        ],
      );
    }

    final decks = _favorites.ordered(_decks, (deck) => deck.id);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: decks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final deck = decks[index];
        return Card(
          key: ValueKey(deck.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deck.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subtitleFor(deck),
                            style: TextStyle(color: variantColor),
                          ),
                        ],
                      ),
                    ),
                    CatalogFavoriteButton(
                      favorites: _favorites,
                      id: deck.id,
                      name: deck.title,
                    ),
                  ],
                ),
                if (deck.cardCount > 0) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppDarkColors.accent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => context.push(
                          AppRoutes.studyFor(deck.id),
                          extra: deck.title,
                        ),
                        icon: const Icon(LucideIcons.layers, size: 18),
                        label: const Text('Học flashcard'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          AppRoutes.quizFor(widget.subjectId, deck.id),
                        ),
                        icon: const Icon(LucideIcons.bookOpen, size: 18),
                        label: const Text('Làm quiz'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// "20 thẻ · 6 đến hạn" — the due count comes from the backend's per-user
  /// flashcard progress, so the list shows what is actually waiting.
  String _subtitleFor(Deck deck) {
    if (deck.cardCount == 0) return 'Chưa có thẻ';
    final parts = ['${deck.cardCount} thẻ'];
    if (deck.dueCount > 0) parts.add('${deck.dueCount} đến hạn');
    return parts.join(' · ');
  }
}
