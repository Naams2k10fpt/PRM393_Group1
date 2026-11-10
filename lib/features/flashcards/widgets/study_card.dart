import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/flashcard.dart';
import 'flip_card.dart';

class StudyCard extends StatefulWidget {
  const StudyCard({super.key, required this.card});

  final Flashcard card;

  @override
  State<StudyCard> createState() => _StudyCardState();
}

class _StudyCardState extends State<StudyCard> {
  final _revealed = <int>{};

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final options = card.options;
    final explanation = card.explanation?.trim() ?? '';
    final showExplanation =
        explanation.isNotEmpty &&
        options.isNotEmpty &&
        _revealed.length == options.length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Câu hỏi',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(card.content, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.elevatedColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      options.isEmpty ? 'Đáp án' : 'Các lựa chọn',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      options.isEmpty
                          ? 'Chạm để xem đáp án.'
                          : 'Chạm từng lựa chọn để xem đúng hoặc sai.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (options.isEmpty)
                      FlipCard(
                        front: const _ChoiceFace(text: 'Xem đáp án'),
                        back: _ChoiceFace(
                          text: card.answerText.isEmpty
                              ? 'Chưa có đáp án.'
                              : card.answerText,
                          result:
                              card.correctAnswers.isNotEmpty &&
                                  explanation.isNotEmpty
                              ? 'Giải thích\n$explanation'
                              : null,
                        ),
                      ),
                    for (final (index, option) in options.indexed) ...[
                      if (index > 0) const SizedBox(height: 8),
                      FlipCard(
                        front: _ChoiceFace(
                          text: _optionText(index, option.content),
                        ),
                        back: _ChoiceFace(
                          text: _optionText(index, option.content),
                          result: option.isCorrect
                              ? 'Đáp án đúng'
                              : 'Lựa chọn sai',
                          correct: option.isCorrect,
                        ),
                        onRevealed: () {
                          if (explanation.isNotEmpty &&
                              !_revealed.contains(index)) {
                            setState(() => _revealed.add(index));
                          }
                        },
                      ),
                    ],
                    if (showExplanation) ...[
                      const SizedBox(height: 12),
                      Text('Giải thích', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(explanation),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _optionText(int index, String content) {
    final label = index < 26 ? String.fromCharCode(65 + index) : '${index + 1}';
    return '$label. $content';
  }
}

class _ChoiceFace extends StatelessWidget {
  const _ChoiceFace({required this.text, this.result, this.correct});

  final String text;
  final String? result;
  final bool? correct;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = switch (correct) {
      true => context.isDark ? AppDarkColors.success : AppLightColors.success,
      false => colors.error,
      null => colors.outlineVariant,
    };
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: correct == null
            ? colors.surface
            : Color.alphaBlend(accent.withValues(alpha: 0.12), colors.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text),
          if (result != null)
            Text(result!, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
