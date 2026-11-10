import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Turns one choice around its vertical axis while keeping its layout stable.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.onRevealed,
  });

  final Widget front;
  final Widget back;
  final VoidCallback? onRevealed;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  bool _showBack = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    _showBack = !_showBack;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = _showBack ? 1 : 0;
    } else if (_showBack) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    if (_showBack) widget.onRevealed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final angle =
                    Curves.easeInOutCubic.transform(_controller.value) *
                    math.pi;
                final showingBack = angle >= math.pi / 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(showingBack ? angle - math.pi : angle),
                  child: Stack(
                    children: [
                      Visibility(
                        visible: !showingBack,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: widget.front,
                      ),
                      Visibility(
                        visible: showingBack,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: widget.back,
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _toggle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
