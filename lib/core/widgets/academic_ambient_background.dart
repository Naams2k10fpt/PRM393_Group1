import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Academic Cyber Ambient Background
///
/// Draws a smooth multi-layered ambient space:
/// 1. Deep midnight gradient base in Dark mode (#0B1120 -> #070B14) or soft daylight slate (#F8FAFC -> #E2E8F0) in Light mode.
/// 2. Glowing radial diffuse orbs (Indigo, Cyan, Warm Amber).
/// 3. Subtle dot-matrix grid with faint academic constellation nodes.
/// 4. Soft mathematical & academic runes (✦, ∑, λ, π, ?, ⚡) rendered with subtle transparency.
class AcademicAmbientBackground extends StatelessWidget {
  const AcademicAmbientBackground({
    super.key,
    this.child,
    this.showRunes = true,
  });

  final Widget? child;
  final bool showRunes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AcademicBackgroundPainter(showRunes: showRunes, isDark: isDark),
        child: child,
      ),
    );
  }
}

class _AcademicBackgroundPainter extends CustomPainter {
  const _AcademicBackgroundPainter({
    required this.showRunes,
    required this.isDark,
  });

  final bool showRunes;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Base Gradient
    final baseColors = isDark
        ? const [
            Color(0xFF0F172A),
            Color(0xFF0B1120),
            Color(0xFF060913),
          ]
        : const [
            Color(0xFFF8FAFC),
            Color(0xFFF1F5F9),
            Color(0xFFE2E8F0),
          ];

    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: baseColors,
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    // 2. Radial Diffuse Glowing Orbs
    // Top-right glowing indigo orb
    final orb1Center = Offset(size.width * 0.85, size.height * 0.15);
    final orb1Radius = math.max(size.width, size.height) * 0.55;
    final orb1Color = isDark ? const Color(0xFF7C6DF8) : const Color(0xFF6366F1);
    final orb1Alpha = isDark ? 0.16 : 0.12;
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          orb1Color.withValues(alpha: orb1Alpha),
          orb1Color.withValues(alpha: orb1Alpha * 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: orb1Radius));
    canvas.drawCircle(orb1Center, orb1Radius, orb1Paint);

    // Bottom-left glowing cyan orb
    final orb2Center = Offset(size.width * 0.1, size.height * 0.8);
    final orb2Radius = math.max(size.width, size.height) * 0.5;
    final orb2Color = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);
    final orb2Alpha = isDark ? 0.12 : 0.10;
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          orb2Color.withValues(alpha: orb2Alpha),
          orb2Color.withValues(alpha: orb2Alpha * 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: orb2Radius));
    canvas.drawCircle(orb2Center, orb2Radius, orb2Paint);

    // Center-right subtle warm amber orb
    final orb3Center = Offset(size.width * 0.7, size.height * 0.55);
    final orb3Radius = math.max(size.width, size.height) * 0.35;
    final orb3Color = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final orb3Alpha = isDark ? 0.06 : 0.05;
    final orb3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          orb3Color.withValues(alpha: orb3Alpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: orb3Center, radius: orb3Radius));
    canvas.drawCircle(orb3Center, orb3Radius, orb3Paint);

    // 3. Dense Dot-matrix Grid (Increased density of tiny background dots)
    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF64748B).withValues(alpha: 0.12);
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const spacing = 20.0;
    for (double x = 10; x < size.width; x += spacing) {
      for (double y = 10; y < size.height; y += spacing) {
        final n = math.sin(x * 0.04) * math.cos(y * 0.04);
        if (n > 0.45) {
          final highlightColor = isDark
              ? const Color(0xFF22D3EE).withValues(alpha: 0.22)
              : const Color(0xFF6366F1).withValues(alpha: 0.22);
          final highlightPaint = Paint()
            ..color = highlightColor
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x, y), 1.25, highlightPaint);
        } else if (n < -0.45) {
          final amberColor = isDark
              ? const Color(0xFFFBBF24).withValues(alpha: 0.18)
              : const Color(0xFFD97706).withValues(alpha: 0.18);
          final amberPaint = Paint()
            ..color = amberColor
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x, y), 1.05, amberPaint);
        } else {
          canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
        }
      }
    }

    // 4. Subtle Constellation Lines connecting a few key nodes
    final lineColor = isDark
        ? const Color(0xFF7C6DF8).withValues(alpha: 0.09)
        : const Color(0xFF6366F1).withValues(alpha: 0.11);
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final p1 = Offset(size.width * 0.2, size.height * 0.25);
    final p2 = Offset(size.width * 0.45, size.height * 0.2);
    final p3 = Offset(size.width * 0.75, size.height * 0.32);
    final p4 = Offset(size.width * 0.35, size.height * 0.65);
    final p5 = Offset(size.width * 0.8, size.height * 0.75);

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p4.dx, p4.dy)
      ..lineTo(p5.dx, p5.dy);
    canvas.drawPath(path, linePaint);

    // 5. Academic Runes & Symbols (soft, subtle watermark style)
    if (showRunes && size.width > 200 && size.height > 200) {
      final runes = isDark
          ? [
              _RuneSpec('✦', Offset(size.width * 0.88, size.height * 0.08), 16, const Color(0xFFFBBF24).withValues(alpha: 0.25)),
              _RuneSpec('∑', Offset(size.width * 0.12, size.height * 0.18), 22, const Color(0xFF7C6DF8).withValues(alpha: 0.18)),
              _RuneSpec('λ', Offset(size.width * 0.82, size.height * 0.42), 20, const Color(0xFF22D3EE).withValues(alpha: 0.15)),
              _RuneSpec('π', Offset(size.width * 0.08, size.height * 0.62), 20, const Color(0xFF34D399).withValues(alpha: 0.14)),
              _RuneSpec('⚡', Offset(size.width * 0.92, size.height * 0.88), 16, const Color(0xFFFBBF24).withValues(alpha: 0.20)),
              _RuneSpec('?', Offset(size.width * 0.25, size.height * 0.85), 24, const Color(0xFF7C6DF8).withValues(alpha: 0.12)),
            ]
          : [
              _RuneSpec('✦', Offset(size.width * 0.88, size.height * 0.08), 16, const Color(0xFFD97706).withValues(alpha: 0.25)),
              _RuneSpec('∑', Offset(size.width * 0.12, size.height * 0.18), 22, const Color(0xFF6366F1).withValues(alpha: 0.22)),
              _RuneSpec('λ', Offset(size.width * 0.82, size.height * 0.42), 20, const Color(0xFF0284C7).withValues(alpha: 0.20)),
              _RuneSpec('π', Offset(size.width * 0.08, size.height * 0.62), 20, const Color(0xFF16A34A).withValues(alpha: 0.20)),
              _RuneSpec('⚡', Offset(size.width * 0.92, size.height * 0.88), 16, const Color(0xFFD97706).withValues(alpha: 0.22)),
              _RuneSpec('?', Offset(size.width * 0.25, size.height * 0.85), 24, const Color(0xFF6366F1).withValues(alpha: 0.16)),
            ];

      for (final r in runes) {
        final tp = TextPainter(
          text: TextSpan(
            text: r.char,
            style: TextStyle(
              fontSize: r.size,
              fontWeight: FontWeight.w600,
              color: r.color,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, r.offset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AcademicBackgroundPainter oldDelegate) {
    return oldDelegate.showRunes != showRunes || oldDelegate.isDark != isDark;
  }
}

class _RuneSpec {
  const _RuneSpec(this.char, this.offset, this.size, this.color);
  final String char;
  final Offset offset;
  final double size;
  final Color color;
}
