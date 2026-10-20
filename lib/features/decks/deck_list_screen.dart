import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/deck.dart';
import '../../data/repositories/catalog_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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
      body: RefreshIndicator(onRefresh: _load, child: _body()),
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

    if (_decks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 16),
        children: const [
          Icon(Icons.inbox_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Môn học này chưa có bộ đề nào.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _decks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final deck = _decks[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(deck.title),
            subtitle: Text(
              _subtitleFor(deck),
              style: const TextStyle(color: AppColors.textMuted),
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Học với bộ đề',
              onSelected: (action) {
                if (action == 'quiz') {
                  context.push(AppRoutes.quizFor(widget.subjectId, deck.id));
                } else {
                  context.push(AppRoutes.studyFor(deck.id), extra: deck.title);
                }
              },
              itemBuilder:
                  (_) => [
                    const PopupMenuItem(
                      value: 'study',
                      child: Text('Học flashcard'),
                    ),
                    PopupMenuItem(
                      value: 'quiz',
                      enabled: deck.cardCount > 0,
                      child: const Text('Làm quiz'),
                    ),
                  ],
            ),
            // The title rides along so the study screen can name itself.
            onTap:
                () => context.push(
                  AppRoutes.studyFor(deck.id),
                  extra: deck.title,
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
