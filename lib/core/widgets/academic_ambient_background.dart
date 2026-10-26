import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Academic Cyber Ambient Background
///
/// An animated multi-layered celestial environment:
/// 1. Deep Midnight canvas (#0F172A -> #060913) or Daylight Slate (#F8FAFC -> #E2E8F0).
/// 2. Slowly orbiting radial diffuse glowing orbs (Indigo, Cyan, Warm Amber).
/// 3. Fine dot-matrix grid with organic wave interference.
/// 4. Drifting constellation micro-particles with continuous sinusoidal twinkling.
/// 5. 8 Academic Motifs (∫, ∑, λ, π, √x, Δ, ∞, ∂) breathing continuously from 0% to 100%
///    with staggered delay offsets (0s, 4s, 8s, 2s, 6s...).
class AcademicAmbientBackground extends StatefulWidget {
  const AcademicAmbientBackground({
    super.key,
    this.child,
    this.showRunes = true,
    this.animate = true,
  });

  final Widget? child;
  final bool showRunes;
  final bool animate;

  @override
  State<AcademicAmbientBackground> createState() => _AcademicAmbientBackgroundState();
}

class _AcademicAmbientBackgroundState extends State<AcademicAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_DriftingParticle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );

    final inTest = WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
        (!kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true');

    if (widget.animate && !inTest) {
      _controller.repeat();
    } else {
      _controller.value = 0.5;
    }

    final rng = math.Random(1337);
    _particles = List.generate(48, (i) {
      final isMajor = i < 14;
      return _DriftingParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        vx: (rng.nextDouble() - 0.5) * 0.00035,
        vy: (rng.nextDouble() - 0.5) * 0.00035,
        radius: isMajor ? (rng.nextDouble() * 1.3 + 1.1) : (rng.nextDouble() * 0.8 + 0.35),
        baseAlpha: isMajor ? 0.65 : (rng.nextDouble() * 0.25 + 0.12),
        twinkleSpeed: rng.nextDouble() * 2.4 + 1.2,
        twinklePhase: rng.nextDouble() * math.pi * 2,
        isMajor: isMajor,
        colorIndex: i % 4,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _AnimatedAcademicBackgroundPainter(
              progress: _controller.value,
              particles: _particles,
              showRunes: widget.showRunes,
              isDark: isDark,
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _DriftingParticle {
  _DriftingParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.baseAlpha,
    required this.twinkleSpeed,
    required this.twinklePhase,
    required this.isMajor,
    required this.colorIndex,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final double radius;
  final double baseAlpha;
  final double twinkleSpeed;
  final double twinklePhase;
  final bool isMajor;
  final int colorIndex;
}

class _AnimatedAcademicBackgroundPainter extends CustomPainter {
  _AnimatedAcademicBackgroundPainter({
    required this.progress,
    required this.particles,
    required this.showRunes,
    required this.isDark,
  });

  final double progress;
  final List<_DriftingParticle> particles;
  final bool showRunes;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
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

    // 2. Harmonic Orbiting Radial Diffuse Glowing Orbs
    final tRad = progress * 2 * math.pi;

    // Orb 1: Indigo / Violet top-right
    final orb1Center = Offset(
      size.width * (0.82 + 0.06 * math.sin(tRad)),
      size.height * (0.16 + 0.05 * math.cos(tRad)),
    );
    final orb1Radius = math.max(size.width, size.height) * 0.55;
    final orb1Color = isDark ? const Color(0xFF7C6DF8) : const Color(0xFF6366F1);
    final orb1Alpha = isDark ? 0.16 : 0.10;
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          orb1Color.withValues(alpha: orb1Alpha),
          orb1Color.withValues(alpha: orb1Alpha * 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: orb1Radius));
    canvas.drawCircle(orb1Center, orb1Radius, orb1Paint);

    // Orb 2: Cyan / Sky bottom-left
    final orb2Center = Offset(
      size.width * (0.12 + 0.05 * math.cos(tRad * 1.2)),
      size.height * (0.78 + 0.06 * math.sin(tRad * 1.2)),
    );
    final orb2Radius = math.max(size.width, size.height) * 0.50;
    final orb2Color = isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7);
    final orb2Alpha = isDark ? 0.12 : 0.09;
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          orb2Color.withValues(alpha: orb2Alpha),
          orb2Color.withValues(alpha: orb2Alpha * 0.40),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: orb2Radius));
    canvas.drawCircle(orb2Center, orb2Radius, orb2Paint);

    // Orb 3: Warm Amber center-right
    final orb3Center = Offset(
      size.width * (0.68 + 0.05 * math.sin(tRad * 0.8)),
      size.height * (0.54 + 0.04 * math.cos(tRad * 0.8)),
    );
    final orb3Radius = math.max(size.width, size.height) * 0.38;
    final orb3Color = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final orb3Alpha = isDark ? 0.07 : 0.05;
    final orb3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          orb3Color.withValues(alpha: orb3Alpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: orb3Center, radius: orb3Radius));
    canvas.drawCircle(orb3Center, orb3Radius, orb3Paint);

    // 3. Dense Dot-Matrix Grid with Subtle Sine-Wave Highlight
    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF475569).withValues(alpha: 0.09);
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const spacing = 36.0;
    for (double x = 18; x < size.width; x += spacing) {
      for (double y = 18; y < size.height; y += spacing) {
        final n = math.sin(x * 0.035 + tRad * 0.2) * math.cos(y * 0.035 + tRad * 0.2);
        if (n > 0.55) {
          final hlColor = isDark
              ? const Color(0xFF22D3EE).withValues(alpha: 0.18)
              : const Color(0xFF6366F1).withValues(alpha: 0.18);
          canvas.drawCircle(Offset(x, y), 1.25, Paint()..color = hlColor);
        } else {
          canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
        }
      }
    }

    // 4. Drifting Micro-Particles & Constellation Neural Links
    final particleScreenPositions = <Offset>[];
    final particlePaints = <Paint>[];

    final themeColors = isDark
        ? [
            const Color(0xFF818CF8), // Indigo
            const Color(0xFF38BDF8), // Cyan
            const Color(0xFFFBBF24), // Amber
            const Color(0xFFA78BFA), // Lavender
          ]
        : [
            const Color(0xFF4F46E5), // Indigo
            const Color(0xFF0284C7), // Sky
            const Color(0xFFD97706), // Amber
            const Color(0xFF7C3AED), // Violet
          ];

    for (final p in particles) {
      // Dynamic motion wrap
      p.x = (p.x + p.vx) % 1.0;
      if (p.x < 0) p.x += 1.0;
      p.y = (p.y + p.vy) % 1.0;
      if (p.y < 0) p.y += 1.0;

      final px = p.x * size.width;
      final py = p.y * size.height;
      particleScreenPositions.add(Offset(px, py));

      // Organic sinusoidal twinkling
      final twinkle = math.sin(p.twinklePhase + tRad * p.twinkleSpeed) * 0.14;
      final alpha = (p.baseAlpha + twinkle).clamp(0.04, 0.95);
      final col = themeColors[p.colorIndex].withValues(alpha: alpha);

      final pt = Paint()
        ..color = col
        ..style = PaintingStyle.fill;
      particlePaints.add(pt);

      canvas.drawCircle(Offset(px, py), p.radius, pt);
    }

    // Neural constellation links between nearby major nodes
    final lineBaseColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1);
    for (int i = 0; i < 14 && i < particles.length; i++) {
      final p1 = particleScreenPositions[i];
      for (int j = i + 1; j < 14 && j < particles.length; j++) {
        final p2 = particleScreenPositions[j];
        final dist = (p1 - p2).distance;
        if (dist < 115) {
          final lineAlpha = (1.0 - dist / 115) * (isDark ? 0.16 : 0.12);
          final linkPaint = Paint()
            ..color = lineBaseColor.withValues(alpha: lineAlpha)
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke;
          canvas.drawLine(p1, p2, linkPaint);
        }
      }
    }

    // 5. 8 Academic Motifs Breathing from 0% to 100% with Staggered Delays
    if (showRunes && size.width > 200 && size.height > 200) {
      final runes = [
        _AnimatedRune('∫', 0.88, 0.09, 24, 0.00,  // delay 0s
            isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
        _AnimatedRune('∑', 0.12, 0.18, 24, 0.25,  // delay 4s
            isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
        _AnimatedRune('λ', 0.82, 0.42, 22, 0.50,  // delay 8s
            isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED)),
        _AnimatedRune('π', 0.08, 0.62, 22, 0.125, // delay 2s
            isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
        _AnimatedRune('√x', 0.90, 0.86, 20, 0.375, // delay 6s
            isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
        _AnimatedRune('Δ', 0.22, 0.85, 22, 0.625, // delay 10s
            isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
        _AnimatedRune('∞', 0.50, 0.09, 24, 0.1875, // delay 3s
            isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA)),
        _AnimatedRune('∂', 0.52, 0.92, 22, 0.4375, // delay 7s
            isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
      ];

      for (int i = 0; i < runes.length; i++) {
        final r = runes[i];

        // Harmonic breathing cycle: 2 cycles per 24s period -> 12s per full breath (0 -> 100 -> 0)
        final breathPhase = (progress * 2.0 - r.delayPhase) * 2 * math.pi;
        final rawSine = math.sin(breathPhase);
        final breath = (rawSine + 1.0) / 2.0; // 0.0 -> 1.0 smooth sine wave
        final opacity = (math.pow(breath, 2.0) * (isDark ? 0.84 : 0.76)).toDouble();

        if (opacity < 0.02) continue; // Skip nearly invisible frames

        // Gentle directional drift
        final driftX = math.sin(breathPhase + i) * 8.0;
        final driftY = -breath * 18.0;
        final motifOffset = Offset(
          size.width * r.relX + driftX,
          size.height * r.relY + driftY,
        );

        final textStyle = TextStyle(
          fontSize: r.size * (0.92 + breath * 0.16),
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          color: r.color.withValues(alpha: opacity),
          fontFamily: 'serif',
          shadows: [
            Shadow(
              color: r.color.withValues(alpha: opacity * 0.85),
              blurRadius: 14.0 * breath,
            ),
          ],
        );

        final tp = TextPainter(
          text: TextSpan(text: r.char, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(canvas, motifOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedAcademicBackgroundPainter oldDelegate) {
    return true; // Continuously animated at 60fps/120fps
  }
}

class _AnimatedRune {
  const _AnimatedRune(this.char, this.relX, this.relY, this.size, this.delayPhase, this.color);
  final String char;
  final double relX;
  final double relY;
  final double size;
  final double delayPhase;
  final Color color;
}
