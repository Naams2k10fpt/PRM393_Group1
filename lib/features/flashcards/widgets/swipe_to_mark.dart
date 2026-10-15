import 'package:flutter/material.dart';

/// Horizontal swipe that marks a card, used instead of [Dismissible].
///
/// [Dismissible] also fires on a fast flick regardless of how far the finger
/// travelled, so a tap with a bit of sideways motion marks the card by mistake —
/// and a mark is a request that moves the card in the review schedule. This
/// commits on distance only: the card must cross [commitFraction] of its own
/// width, otherwise it springs back and nothing is sent.
class SwipeToMark extends StatefulWidget {
  const SwipeToMark({
    super.key,
    required this.child,
    required this.onMarked,
    this.leftHint,
    this.rightHint,
    this.commitFraction = 0.33,
  });

  final Widget child;

  /// true when swiped right ("Đã thuộc"), false when swiped left.
  final void Function(bool remembered) onMarked;

  /// Shown while dragging right / left.
  final Widget? leftHint;
  final Widget? rightHint;

  final double commitFraction;

  @override
  State<SwipeToMark> createState() => _SwipeToMarkState();
}

class _SwipeToMarkState extends State<SwipeToMark> {
  double _dx = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final threshold = width * widget.commitFraction;
        final progress = threshold == 0 ? 0.0 : (_dx.abs() / threshold).clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: (details) => setState(() => _dx += details.delta.dx),
          onHorizontalDragEnd: (_) {
            final committed = _dx.abs() >= threshold;
            final remembered = _dx > 0;
            setState(() {
              _dragging = false;
              _dx = 0;
            });
            if (committed) widget.onMarked(remembered);
          },
          onHorizontalDragCancel: () => setState(() {
            _dragging = false;
            _dx = 0;
          }),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_dx > 0 && widget.leftHint != null)
                Positioned.fill(child: Opacity(opacity: progress, child: widget.leftHint)),
              if (_dx < 0 && widget.rightHint != null)
                Positioned.fill(child: Opacity(opacity: progress, child: widget.rightHint)),
              AnimatedSlide(
                offset: Offset(width == 0 ? 0 : _dx / width, 0),
                // Follows the finger while dragging; springs back on release.
                duration: _dragging ? Duration.zero : const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}
