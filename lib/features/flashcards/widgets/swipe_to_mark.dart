import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Marks a card after a deliberate horizontal swipe. Short flicks return
/// the card to its original position without changing its review schedule.
class SwipeToMark extends StatefulWidget {
  const SwipeToMark({
    super.key,
    required this.child,
    required this.onMarked,
    required this.rememberedColor,
    required this.missedColor,
  });

  final Widget child;
  final ValueChanged<bool> onMarked;
  final Color rememberedColor;
  final Color missedColor;

  @override
  State<SwipeToMark> createState() => _SwipeToMarkState();
}

class _SwipeToMarkState extends State<SwipeToMark>
    with SingleTickerProviderStateMixin {
  late final _offset = AnimationController.unbounded(vsync: this);
  bool _committing = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Future<void> _settle(double width, {required bool commit}) async {
    if (_committing) return;
    _committing = commit;
    final remembered = _offset.value > 0;
    final target = commit ? (remembered ? width + 32 : -width - 32) : 0.0;

    if (MediaQuery.disableAnimationsOf(context)) {
      _offset.value = target;
    } else {
      try {
        await _offset
            .animateTo(
              target,
              duration: Duration(milliseconds: commit ? 170 : 230),
              curve: commit ? Curves.easeOutCubic : Curves.easeOutQuart,
            )
            .orCancel;
      } on TickerCanceled {
        return;
      }
    }

    if (commit && mounted) widget.onMarked(remembered);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final threshold = (width * 0.25).clamp(56.0, 112.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: (_) {
            if (!_committing) _offset.stop();
          },
          onHorizontalDragUpdate: (details) {
            if (!_committing) _offset.value += details.delta.dx;
          },
          onHorizontalDragEnd: (_) =>
              _settle(width, commit: _offset.value.abs() >= threshold),
          onHorizontalDragCancel: () => _settle(width, commit: false),
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _offset,
              child: widget.child,
              builder: (context, child) {
                final dx = _offset.value;
                final progress = (dx.abs() / threshold).clamp(0.0, 1.0);
                final remembered = dx > 0;
                final color = remembered
                    ? widget.rememberedColor
                    : widget.missedColor;
                return Stack(
                  children: [
                    if (dx != 0)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: progress * 0.16),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(dx, 0),
                      child: Transform.rotate(
                        angle: reduceMotion
                            ? 0
                            : (dx / width).clamp(-1.0, 1.0) * 0.10,
                        child: IgnorePointer(
                          ignoring: _committing,
                          child: child,
                        ),
                      ),
                    ),
                    if (dx != 0)
                      Positioned(
                        top: 12,
                        left: remembered ? null : 12,
                        right: remembered ? 12 : null,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Opacity(
                              opacity: (progress * 3).clamp(0.0, 1.0),
                              child: _SwipeBadge(
                                remembered: remembered,
                                ready: progress == 1 && !_committing,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SwipeBadge extends StatelessWidget {
  const _SwipeBadge({
    required this.remembered,
    required this.ready,
    required this.color,
  });

  final bool remembered;
  final bool ready;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: ready ? 0.24 : 0.08),
          theme.colorScheme.surface,
        ),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  remembered ? LucideIcons.check : LucideIcons.rotateCcw,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  remembered ? 'Đã thuộc' : 'Chưa thuộc',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            if (ready)
              Text('Thả để đánh dấu', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
