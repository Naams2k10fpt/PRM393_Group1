import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/form_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flashcard.dart';
import '../../data/repositories/flashcard_repository.dart';
import '../auth/auth_controller.dart';
import 'flashcard_review_queue.dart';
import 'widgets/study_card.dart';
import 'widgets/swipe_to_mark.dart';

enum _StudyMode { due, all, missed }

/// Study a deck, with reviews written locally before being sent to the server.
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

  final _pending = <PendingFlashcardReview>[];
  late final AuthController _auth;
  late final String _userId;
  late final FlashcardReviewQueue _queue;
  bool _persisting = false;
  bool _syncing = false;
  String? _storageError;

  _StudyMode _mode = _StudyMode.due;

  bool get _finished => _cards.isNotEmpty && _index >= _cards.length;
  bool get _canLoad => !_busy && !_persisting && !_syncing && _pending.isEmpty;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>();
    _userId = _auth.user!.id;
    _queue = FlashcardReviewQueue(_userId, widget.deckId);
    _restore();
  }

  Future<void> _restore() async {
    try {
      final pending = await _queue.read();
      if (!mounted) return;
      _pending.addAll(pending);
      await _sync();
    } catch (_) {
      if (!mounted) return;
      _storageError = 'Không đọc được tiến độ đã lưu trên thiết bị.';
    }
    if (mounted) await _load(_mode, refresh: true);
  }

  Future<void> _load(_StudyMode mode, {bool refresh = false}) async {
    if (!refresh && !_canLoad) return;
    final repository = context.read<FlashcardRepository>();
    setState(() {
      _mode = mode;
      _busy = true;
      _error = null;
    });
    try {
      final session = await repository.session(
        widget.deckId,
        studyAll: mode != _StudyMode.due,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        // A zero repetition on an existing progress record is a missed review.
        final pendingIds = _pending.map((review) => review.questionId).toSet();
        _cards = [
          for (final card in session.cards)
            if (!pendingIds.contains(card.questionId) &&
                (mode != _StudyMode.missed || card.progress?.repetition == 0))
              card,
        ];
        _index = 0;
        _knownCount = 0;
        _missedCount = 0;
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

  Future<bool> _answer(String questionId, bool remembered) async {
    if (_busy ||
        _persisting ||
        _index >= _cards.length ||
        _cards[_index].questionId != questionId) {
      return false;
    }
    setState(() {
      _persisting = true;
      _storageError = null;
    });
    late final PendingFlashcardReview review;
    try {
      review = PendingFlashcardReview.create(questionId, remembered);
      await _queue.add(review);
    } catch (_) {
      if (mounted) {
        setState(() {
          _persisting = false;
          _storageError = 'Không lưu được trên thiết bị. Hãy đánh dấu lại.';
        });
      }
      return false;
    }
    if (!mounted) return true;
    setState(() {
      _persisting = false;
      _pending.add(review);
      remembered ? _knownCount++ : _missedCount++;
      _index++;
    });
    _sync();
    return true;
  }

  Future<void> _sync() async {
    if (_pending.isEmpty || _syncing) return;
    final repository = context.read<FlashcardRepository>();
    setState(() => _syncing = true);
    try {
      while (mounted && _auth.user?.id == _userId && _pending.isNotEmpty) {
        final review = _pending.first;
        try {
          await repository.review(
            deckId: widget.deckId,
            questionId: review.questionId,
            remembered: review.remembered,
            reviewId: review.id,
          );
        } on ApiException catch (error) {
          // A removed question cannot be reviewed again.
          if (error.code != 'question_not_found') break;
        }
        await _queue.remove(review.id);
        if (mounted) setState(() => _pending.removeAt(0));
      }
    } catch (_) {
      // Leave the review queued if removing it from local storage failed.
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _retryPending() async {
    await _sync();
    if (mounted && _cards.isEmpty && _pending.isEmpty) {
      await _load(_mode, refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deckTitle ?? _session?.deckName ?? 'Học thẻ'),
        actions: [
          if (_error == null &&
              _cards.isNotEmpty &&
              _index == 0 &&
              _mode != _StudyMode.missed)
            IconButton(
              tooltip: 'Ôn câu chưa thuộc',
              onPressed: _canLoad ? () => _load(_StudyMode.missed) : null,
              icon: const Icon(LucideIcons.bookmark),
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_busy) return const Center(child: CircularProgressIndicator());

    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ErrorBanner(
              message: error.message,
              action: TextButton(
                onPressed: () => _load(_mode, refresh: true),
                child: const Text('Thử lại'),
              ),
            ),
            _syncStatus(),
          ],
        ),
      );
    }

    if (_cards.isEmpty) return _nothingToStudy();

    return _finished ? _summary() : _studyView();
  }

  Widget _nothingToStudy() {
    final total = _session?.totalCards ?? 0;
    final hasCardsNotDue = _mode == _StudyMode.due && total > 0;
    final studyingMissed = _mode == _StudyMode.missed;
    final message = switch (_mode) {
      _StudyMode.missed => 'Chưa có câu nào được đánh dấu chưa thuộc.',
      _ when hasCardsNotDue => 'Bạn đã ôn hết thẻ đến hạn hôm nay.',
      _ when _pending.isNotEmpty => 'Đang chờ đồng bộ các thẻ đã đánh dấu.',
      _ => 'Bộ đề này chưa có thẻ nào.',
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasCardsNotDue ? LucideIcons.circleCheck : LucideIcons.layers,
              size: 44,
              color: hasCardsNotDue
                  ? AppColors.success
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            _syncStatus(),
            if (hasCardsNotDue) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _canLoad ? () => _load(_StudyMode.all) : null,
                icon: const Icon(LucideIcons.bookOpen),
                label: Text('Ôn trước cả $total thẻ'),
              ),
              _studyMissedButton(),
            ],
            if (studyingMissed)
              TextButton(
                onPressed: _canLoad ? () => _load(_StudyMode.due) : null,
                child: const Text('Học thẻ đến hạn'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _studyView() {
    final card = _cards[_index];
    final total = _cards.length;
    final theme = Theme.of(context);
    final knownColor = context.isDark
        ? AppDarkColors.success
        : AppLightColors.success;
    final missedColor = theme.colorScheme.error;

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: ValueKey(card.questionId),
            padding: const EdgeInsets.all(16),
            children: [
              if (_mode == _StudyMode.missed) ...[
                Text('Ôn câu chưa thuộc', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Text(
                    '${_index + 1}/$total',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _index / total,
                        minHeight: 8,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Đã học $_index/$total  ·  Đã thuộc $_knownCount  ·  Chưa thuộc $_missedCount',
                style: theme.textTheme.bodySmall,
              ),
              _syncStatus(showSaving: false),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 140),
                builder: (context, value, child) =>
                    Opacity(opacity: value, child: child),
                child: SwipeToMark(
                  onMarked: (remembered) =>
                      _answer(card.questionId, remembered),
                  rememberedColor: knownColor,
                  missedColor: missedColor,
                  child: StudyCard(card: card),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kéo thẻ sang trái hoặc phải, hoặc chọn nút bên dưới.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: missedColor,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _persisting
                            ? null
                            : () => _answer(card.questionId, false),
                        icon: const Icon(LucideIcons.arrowLeft),
                        label: const Text('Chưa thuộc'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: knownColor,
                          foregroundColor: AppDarkColors.background,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _persisting
                            ? null
                            : () => _answer(card.questionId, true),
                        icon: const Icon(LucideIcons.arrowRight),
                        iconAlignment: IconAlignment.end,
                        label: const Text('Đã thuộc'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _studyMissedButton() => OutlinedButton.icon(
    onPressed: _canLoad ? () => _load(_StudyMode.missed) : null,
    icon: const Icon(LucideIcons.bookmark),
    label: const Text('Ôn câu chưa thuộc'),
  );

  Widget _syncStatus({bool showSaving = true}) {
    if (_storageError case final message?) {
      return ErrorBanner(message: message);
    }
    if (_pending.isNotEmpty && !_syncing) {
      return ErrorBanner(
        message: 'Có ${_pending.length} thẻ chưa lưu được tiến độ.',
        action: TextButton(
          onPressed: _syncing ? null : _retryPending,
          child: const Text('Gửi lại'),
        ),
      );
    }
    if (showSaving && _syncing) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: const Text('Đang lưu tiến độ...'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _summary() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final recallPercent = (100 * _knownCount / _cards.length).round();
    final showMissed = _mode != _StudyMode.missed || _missedCount > 0;
    final dueLabel = _summaryActionLabel(
      LucideIcons.calendarClock,
      'Học thẻ đến hạn',
      'Ôn thẻ mới và thẻ đã đến lịch',
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        const Icon(LucideIcons.award, size: 56, color: AppColors.warning),
        const SizedBox(height: 12),
        Text(
          'Hoàn thành!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Bạn đã học hết ${_cards.length} thẻ.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Tỷ lệ tự đánh giá đã thuộc $recallPercent%',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ScoreTile(
                label: 'Đã thuộc',
                value: _knownCount,
                color: context.isDark
                    ? AppDarkColors.success
                    : AppLightColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ScoreTile(
                label: 'Chưa thuộc',
                value: _missedCount,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _syncStatus(),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Bước tiếp theo', style: theme.textTheme.titleSmall),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.cyanColor,
            foregroundColor: AppDarkColors.background,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _canLoad
              ? () => _load(showMissed ? _StudyMode.missed : _StudyMode.due)
              : null,
          child: showMissed
              ? _summaryActionLabel(
                  LucideIcons.bookmark,
                  'Ôn câu chưa thuộc',
                  'Ôn ngay các câu đã đánh dấu',
                )
              : dueLabel,
        ),
        if (showMissed) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.surface,
              foregroundColor: colors.onSurface,
              side: BorderSide(color: colors.outlineVariant),
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: _canLoad ? () => _load(_StudyMode.due) : null,
            child: dueLabel,
          ),
        ],
        const SizedBox(height: 4),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: colors.onSurfaceVariant,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(LucideIcons.arrowLeft, size: 18),
          label: const Text('Về danh sách bộ đề'),
        ),
      ],
    );
  }

  Widget _summaryActionLabel(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(LucideIcons.chevronRight, size: 18),
      ],
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.label,
    required this.value,
    required this.color,
  });

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
          Text(
            '$value',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
