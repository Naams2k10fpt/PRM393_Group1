import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Academic Cyber Ambient Background
///
/// Draws a smooth multi-layered ambient space:
/// 1. Deep midnight gradient base (#0B1120 -> #070B14)
/// 2. Glowing radial diffuse orbs (Primary Indigo #7C6DF8, Secondary Cyan #22D3EE, Warm Amber #FBBF24)
/// 3. Subtle dot-matrix grid with faint academic constellation nodes
/// 4. Soft mathematical & academic runes (✦, ∑, λ, π, ?, ⚡) rendered with subtle transparency
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
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AcademicBackgroundPainter(showRunes: showRunes),
        child: child,
      ),
    );
  }
}

class _AcademicBackgroundPainter extends CustomPainter {
  const _AcademicBackgroundPainter({required this.showRunes});

  final bool showRunes;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Deep Midnight Base Gradient
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0F172A),
          Color(0xFF0B1120),
          Color(0xFF060913),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    // 2. Radial Diffuse Glowing Orbs
    // Top-right glowing indigo orb
    final orb1Center = Offset(size.width * 0.85, size.height * 0.15);
    final orb1Radius = math.max(size.width, size.height) * 0.55;
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7C6DF8).withValues(alpha: 0.16),
          const Color(0xFF6366F1).withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: orb1Radius));
    canvas.drawCircle(orb1Center, orb1Radius, orb1Paint);

    // Bottom-left glowing cyan orb
    final orb2Center = Offset(size.width * 0.1, size.height * 0.8);
    final orb2Radius = math.max(size.width, size.height) * 0.5;
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF22D3EE).withValues(alpha: 0.12),
          const Color(0xFF0EA5E9).withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: orb2Radius));
    canvas.drawCircle(orb2Center, orb2Radius, orb2Paint);

    // Center-right subtle warm amber orb
    final orb3Center = Offset(size.width * 0.7, size.height * 0.55);
    final orb3Radius = math.max(size.width, size.height) * 0.35;
    final orb3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFBBF24).withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: orb3Center, radius: orb3Radius));
    canvas.drawCircle(orb3Center, orb3Radius, orb3Paint);

    // 3. Dot-matrix Grid
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const spacing = 36.0;
    for (double x = 18; x < size.width; x += spacing) {
      for (double y = 18; y < size.height; y += spacing) {
        // Pseudo-random subtle opacity variation based on coordinates
        final n = math.sin(x * 0.05) * math.cos(y * 0.05);
        if (n > 0.4) {
          final highlightPaint = Paint()
            ..color = const Color(0xFF22D3EE).withValues(alpha: 0.18)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x, y), 1.2, highlightPaint);
        } else {
          canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
        }
      }
    }

    // 4. Subtle Constellation Lines connecting a few key nodes
    final linePaint = Paint()
      ..color = const Color(0xFF7C6DF8).withValues(alpha: 0.09)
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
      final runes = [
        _RuneSpec('✦', Offset(size.width * 0.88, size.height * 0.08), 16, const Color(0xFFFBBF24).withValues(alpha: 0.25)),
        _RuneSpec('∑', Offset(size.width * 0.12, size.height * 0.18), 22, const Color(0xFF7C6DF8).withValues(alpha: 0.18)),
        _RuneSpec('λ', Offset(size.width * 0.82, size.height * 0.42), 20, const Color(0xFF22D3EE).withValues(alpha: 0.15)),
        _RuneSpec('π', Offset(size.width * 0.08, size.height * 0.62), 20, const Color(0xFF34D399).withValues(alpha: 0.14)),
        _RuneSpec('⚡', Offset(size.width * 0.92, size.height * 0.88), 16, const Color(0xFFFBBF24).withValues(alpha: 0.20)),
        _RuneSpec('?', Offset(size.width * 0.25, size.height * 0.85), 24, const Color(0xFF7C6DF8).withValues(alpha: 0.12)),
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
    return oldDelegate.showRunes != showRunes;
  }
}

class _RuneSpec {
  const _RuneSpec(this.char, this.offset, this.size, this.color);
  final String char;
  final Offset offset;
  final double size;
  final Color color;
}
