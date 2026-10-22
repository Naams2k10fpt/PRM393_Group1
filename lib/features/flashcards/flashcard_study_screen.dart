import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flashcard.dart';
import '../../data/repositories/flashcard_repository.dart';
import 'widgets/flip_card.dart';
import 'widgets/swipe_to_mark.dart';

/// One card whose review the backend has not accepted yet.
class _PendingReview {
  const _PendingReview(this.questionId, this.remembered);

  final String questionId;
  final bool remembered;
}

/// Study one deck, a card at a time: tap to flip, then swipe or press a button.
///
/// Each answer is sent on its own, because the backend keeps a spaced-repetition
/// schedule per card. A review that fails goes into [_pending] and the summary
/// offers to send it again, so a flaky connection never loses the session.
class FlashcardStudyScreen extends StatefulWidget {
  const FlashcardStudyScreen({super.key, required this.deckId, this.deckTitle});

  final String deckId;
  final String? deckTitle;

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  bool _busy = true;
  ApiException? _error;

  FlashcardSession? _session;
  List<Flashcard> _cards = const [];
  int _index = 0;

  int _knownCount = 0;
  int _missedCount = 0;

  final _pending = <_PendingReview>[];
  bool _retrying = false;

  bool _studyAll = false;

  bool get _finished => _cards.isNotEmpty && _index >= _cards.length;
  int get _answered => _knownCount + _missedCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = context.read<FlashcardRepository>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await repository.session(widget.deckId, studyAll: _studyAll);
      if (!mounted) return;
      setState(() {
        _session = session;
        _cards = session.cards;
        _index = 0;
        _knownCount = 0;
        _missedCount = 0;
        _pending.clear();
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

  /// Advances straight away and sends the review behind the scenes, so the
  /// learner is never waiting on the network between cards.
  void _answer(bool remembered) {
    if (_finished) return;
    final card = _cards[_index];
    setState(() {
      remembered ? _knownCount++ : _missedCount++;
      _index++;
    });
    _send(_PendingReview(card.questionId, remembered));
  }

  Future<void> _send(_PendingReview review) async {
    final repository = context.read<FlashcardRepository>();
    try {
      await repository.review(
        deckId: widget.deckId,
        questionId: review.questionId,
        remembered: review.remembered,
      );
    } on ApiException {
      if (!mounted) return;
      setState(() => _pending.add(review));
    }
  }

  Future<void> _retryPending() async {
    if (_pending.isEmpty || _retrying) return;
    final queued = List.of(_pending);
    setState(() {
      _retrying = true;
      _pending.clear();
    });
    for (final review in queued) {
      await _send(review);
    }
    if (!mounted) return;
    setState(() => _retrying = false);
  }

  /// Reloads with `mode=all` so the user can revise cards that are not due yet.
  void _studyEverything() {
    _studyAll = true;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.deckTitle ?? _session?.deckName ?? 'Học thẻ')),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_busy) return const Center(child: CircularProgressIndicator());

    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorBanner(
          message: error.message,
          action: TextButton(onPressed: _load, child: const Text('Thử lại')),
        ),
      );
    }

    if (_cards.isEmpty) return _nothingToStudy();

    return _finished ? _summary() : _studyView();
  }

  Widget _nothingToStudy() {
    final session = _session;
    final hasCardsNotDue = session != null && !session.studyingAll && session.totalCards > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasCardsNotDue ? Icons.check_circle_outline : Icons.style_outlined,
              size: 44,
              color: hasCardsNotDue ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasCardsNotDue ? 'Bạn đã ôn hết thẻ đến hạn hôm nay.' : 'Bộ đề này chưa có thẻ nào.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (hasCardsNotDue) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _studyEverything,
                icon: const Icon(Icons.auto_stories_outlined),
                label: Text('Ôn trước cả ${session.totalCards} thẻ'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _studyView() {
    final card = _cards[_index];
    final total = _cards.length;
    final answer = card.answerText;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text('${_index + 1}/$total', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _index / total,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: SwipeToMark(
                key: ValueKey('swipe-${card.questionId}'),
                onMarked: _answer,
                leftHint: const _SwipeHint(
                  alignment: Alignment.centerLeft,
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                  label: 'Đã thuộc',
                ),
                rightHint: const _SwipeHint(
                  alignment: Alignment.centerRight,
                  color: AppColors.danger,
                  icon: Icons.refresh,
                  label: 'Chưa thuộc',
                ),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: FlipCard(
                    key: ValueKey('card-${card.questionId}'),
                    front: CardFace(text: card.content, caption: 'Câu hỏi'),
                    back: CardFace(
                      text: answer.isEmpty ? '(Chưa có đáp án)' : answer,
                      caption: 'Đáp án',
                      footnote: card.correctAnswers.isEmpty ? null : card.explanation,
                      accent: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Chạm vào thẻ để lật · vuốt sang hai bên để đánh dấu',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => _answer(false),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Chưa thuộc'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => _answer(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Đã thuộc'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.emoji_events_outlined, size: 56, color: AppColors.warning),
        const SizedBox(height: 12),
        Text('Hoàn thành!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Bạn đã học hết $_answered thẻ.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _ScoreTile(label: 'Đã thuộc', value: _knownCount, color: AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _ScoreTile(label: 'Chưa thuộc', value: _missedCount, color: AppColors.danger)),
          ],
        ),
        const SizedBox(height: 24),
        if (_retrying)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: Text('Đang gửi lại...'))),
        if (_pending.isNotEmpty && !_retrying)
          ErrorBanner(
            message: 'Có ${_pending.length} thẻ chưa lưu được tiến độ.',
            action: TextButton(onPressed: _retryPending, child: const Text('Gửi lại')),
          ),
        const SizedBox(height: 16),
        if (_missedCount > 0)
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.replay),
            label: const Text('Ôn lại các thẻ đến hạn'),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Về danh sách bộ đề'),
        ),
      ],
    );
  }
}

/// What shows behind the card while it is being swiped.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }
}
