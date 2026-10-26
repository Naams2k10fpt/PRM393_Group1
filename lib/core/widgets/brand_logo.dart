import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Minimalist Monogram Container & Vector Emblem matching Web's _BrandLogo.cshtml
/// AuthKit Cyber-Academic Design System
class BrandEmblem extends StatelessWidget {
  final double size;
  final bool showGlow;

  const BrandEmblem({super.key, this.size = 48, this.showGlow = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Expansive diffuse ambient glow halo (smoothly bleeding outwards, never clipped into a box)
          if (showGlow)
            Positioned(
              width: size * 2.2,
              height: size * 2.2,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        isDark
                            ? const Color(0xFF663AF3).withValues(alpha: 0.42)
                            : const Color(0xFF6366F1).withValues(alpha: 0.18),
                        isDark
                            ? const Color(0xFF38BDF8).withValues(alpha: 0.20)
                            : const Color(0xFF0284C7).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          CustomPaint(
            size: Size(size, size),
            painter: _BrandEmblemPainter(isDark: isDark),
          ),
        ],
      ),
    );
  }
}

class _BrandEmblemPainter extends CustomPainter {
  final bool isDark;

  _BrandEmblemPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Container box (AuthKit style rounded rect)
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * (4 / 64), h * (4 / 64), w * (56 / 64), h * (56 / 64)),
      Radius.circular(w * (16 / 64)),
    );

    // Box Shadow for elevated glass feel
    final shadowPaint = Paint()
      ..color = isDark ? const Color(0x33000000) : const Color(0x140F172A)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * (3 / 64));
    canvas.drawRRect(boxRect.shift(Offset(0, w * (1.5 / 64))), shadowPaint);

    final boxFillPaint = Paint()
      ..color = isDark ? const Color(0xFF161C28) : const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(boxRect, boxFillPaint);

    final boxStrokePaint = Paint()
      ..color = isDark ? const Color(0x2EBAE3FA) : const Color(0x1F0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * (1.5 / 64));
    canvas.drawRRect(boxRect, boxStrokePaint);

    // 2. Primary Gradient (#663af3 to #38bdf8)
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF663AF3), Color(0xFF38BDF8)],
    );
    final emblemRect = Rect.fromLTWH(0, 0, w, h);
    final strokePaint = Paint()
      ..shader = gradient.createShader(emblemRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * (4.5 / 64)
      ..strokeCap = StrokeCap.round;

    // 3. Clean Geometric Q Monogram Ring
    final center = Offset(w * (32 / 64), h * (30 / 64));
    final radius = w * (14 / 64);
    canvas.drawCircle(center, radius, strokePaint);

    // 4. Clean Geometric Q Tail (45-degree angled stroke)
    final p1 = Offset(w * (38 / 64), h * (36 / 64));
    final p2 = Offset(w * (46 / 64), h * (44 / 64));
    canvas.drawLine(p1, p2, strokePaint);

    // 5. Subtle Inner Focus Dot
    final dotPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, w * (2.5 / 64), dotPaint);
  }

  @override
  bool shouldRepaint(covariant _BrandEmblemPainter oldDelegate) => oldDelegate.isDark != isDark;
}

/// Full Brand Logo with Emblem and "QuizMS" text matching Web navbar
class BrandLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final TextStyle? textStyle;

  const BrandLogo({
    super.key,
    this.size = 32,
    this.showText = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final emblem = BrandEmblem(size: size, showGlow: false);
    if (!showText) return emblem;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultStyle = TextStyle(
      fontSize: size * 0.55,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: isDark ? const Color(0xFFD1E4FA) : const Color(0xFF0F172A),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        emblem,
        SizedBox(width: size * 0.28),
        Text(
          'QuizMS',
          style: textStyle ?? defaultStyle,
        ),
      ],
    );
  }
}
