import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A card that turns over around its vertical axis when tapped.
///
/// Only the face currently pointing at the viewer is in the tree, so a test can
/// assert on the term before the flip and on the definition after it. Giving the
/// widget a key per card makes the next card start face up by itself.
class FlipCard extends StatefulWidget {
  const FlipCard({super.key, required this.front, required this.back});

  final Widget front;
  final Widget back;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> _turn =
      Tween<double>(begin: 0, end: math.pi).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isAnimating) return;
    _controller.value > 0.5 ? _controller.reverse() : _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, child) {
          final angle = _turn.value;
          final showingBack = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            // setEntry adds the perspective. Without it the card looks like it is
            // being squashed flat rather than turning in space.
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: showingBack
                // The back is drawn mirrored by the parent rotation, so turn it
                // back the other way or its text reads in reverse.
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: widget.back,
                  )
                : widget.front,
          );
        },
      ),
    );
  }
}

/// One side of a [FlipCard].
class CardFace extends StatelessWidget {
  const CardFace({
    super.key,
    required this.text,
    this.caption,
    this.footnote,
    this.accent = AppColors.accent,
  });

  final String text;

  /// Small label above the text ("Thuật ngữ" / "Nghĩa").
  final String? caption;

  /// Optional example sentence under the definition.
  final String? footnote;

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    final footnote = this.footnote;
    final theme = Theme.of(context);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (caption != null) ...[
            Text(
              caption.toUpperCase(),
              style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
          ],
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 16),
            Text(
              footnote,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
