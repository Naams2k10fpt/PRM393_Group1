import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Flutter implementation of the Liquid Glass Logo entrance:
/// - Sphere-to-tile superellipse glass entrance (0.0s -> 1.8s)
/// - Wavelength-based spectral bevel refraction & chromatic edge streaks
/// - Measured responsive fitting & MediaQuery disableAnimations support
/// - Finishes on the project's Q logo alone at its normal resting size on a black background
class LiquidGlassLogo extends StatefulWidget {
  final double height;
  final double logoSize;

  const LiquidGlassLogo({
    super.key,
    this.height = 480,
    this.logoSize = 256,
  });

  @override
  State<LiquidGlassLogo> createState() => _LiquidGlassLogoState();
}

class _LiquidGlassLogoState extends State<LiquidGlassLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Container(
      height: widget.height,
      width: double.infinity,
      color: Colors.black,
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 480.0;
          final h =
              constraints.maxHeight.isFinite ? constraints.maxHeight : widget.height;
          final fitScale = math.min(
            1.0,
            math.min(w / (widget.logoSize * 1.9), h / (widget.logoSize * 1.5)),
          );
          final unit = widget.logoSize * fitScale;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = reducedMotion ? 1.8 : _controller.value * 1.8;
              return CustomPaint(
                size: Size(unit * 1.5, unit * 1.5),
                painter: _LiquidGlassLogoPainter(
                  time: t,
                  unit: unit,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LiquidGlassLogoPainter extends CustomPainter {
  final double time;
  final double unit;

  _LiquidGlassLogoPainter({
    required this.time,
    required this.unit,
  });

  double _smooth(double a, double b, double x) {
    final v = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return v * v * (3.0 - 2.0 * v);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t = time;
    final enter = _smooth(0.025, 0.16, t);
    if (enter < 0.001) return;

    final settle = ((t - 1.16) / (1.4 - 1.16)).clamp(0.0, 1.0);
    final settleEase = _smooth(0.0, 1.0, settle);
    final expand =
        enter * (0.64 + 0.41 * (1.0 - math.exp(-math.max(t - 0.16, 0.0) * 5.8)));
    final collapse = 1.0 - _smooth(1.33, 1.52, t);
    final lensScale = math.max(
      0.001,
      expand * (0.48 + (1.0 - 0.48) * collapse) * (1.0 - settleEase) +
          1.0 * settleEase,
    );

    final glass = (1.0 - _smooth(1.05, 1.4, t)) * collapse * (1.0 - settleEase);
    final plateExtent = unit * lensScale;

    // Morph from sphere (radius = 0.5 * plateExtent) to superellipse tile (corner radius ~ 0.24)
    final morphToTile = _smooth(0.29, 0.36, t);
    final cornerRadius =
        plateExtent * (0.5 * (1.0 - morphToTile) + 0.24 * morphToTile);

    final plateRect = Rect.fromCenter(
      center: center,
      width: plateExtent,
      height: plateExtent,
    );
    final plateRRect =
        RRect.fromRectAndRadius(plateRect, Radius.circular(cornerRadius));

    // 1. Liquid glass plate & chromatic bevel dispersion (fades out as glass settles)
    if (glass > 0.005) {
      // Deep #060c18 glass plate body
      final platePaint = Paint()
        ..color = const Color(0xFF060C18).withValues(alpha: (0.95 * glass).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(plateRRect, platePaint);

      // Wavelength-based chromatic bevel streaks (violet/cyan upper-left, blue/amber lower-right)
      final bevelShader = SweepGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.75 * glass),
          const Color(0xFF663AF3).withValues(alpha: 0.65 * glass),
          const Color(0xFFE0F2FE).withValues(alpha: 0.90 * glass),
          const Color(0xFF0284C7).withValues(alpha: 0.55 * glass),
          const Color(0xFFF59E0B).withValues(alpha: 0.35 * glass),
          const Color(0xFF38BDF8).withValues(alpha: 0.75 * glass),
        ],
      ).createShader(plateRect);

      final rimPaint = Paint()
        ..shader = bevelShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, unit * 0.022 * glass);
      canvas.drawRRect(plateRRect, rimPaint);

      // Inset back-wall refraction channel
      final insetGap = unit * 0.065 * lensScale;
      final insetRect = plateRect.deflate(insetGap);
      if (insetRect.width > 4) {
        final insetRRect = RRect.fromRectAndRadius(
          insetRect,
          Radius.circular(math.max(2.0, cornerRadius - insetGap * 0.85)),
        );
        final insetPaint = Paint()
          ..color =
              const Color(0xFF7DD3FC).withValues(alpha: (0.32 * glass).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, unit * 0.012);
        canvas.drawRRect(insetRRect, insetPaint);
      }

      // Young sphere studio softbox reflection
      final sphereLight = (1.0 - _smooth(0.245, 0.36, t)) * glass;
      if (sphereLight > 0.01) {
        final highlightRect = Rect.fromCenter(
          center: center.translate(-plateExtent * 0.12, -plateExtent * 0.18),
          width: plateExtent * 0.55,
          height: plateExtent * 0.35,
        );
        final highlightPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFBFE3FF).withValues(alpha: 0.55 * sphereLight),
              Colors.transparent,
            ],
          ).createShader(highlightRect);
        canvas.drawOval(highlightRect, highlightPaint);
      }
    }

    // 2. Refracted / resting QuizMS Q Logo (magnified under young dome, settling to 1.0 normal size)
    final artSettle = _smooth(1.13, 1.28, t);
    final earlyScale = 1.40 - 0.29 * _smooth(0.2, 1.13, t);
    final artScale = earlyScale * (1.0 - artSettle) + 1.0 * artSettle;
    final logoBoxSize = unit * 0.72 * artScale;

    // Chromatic dispersion offset during active glass phase
    final dispersionShift = unit * 0.014 * glass;
    if (dispersionShift > 0.2) {
      _drawQGlyph(
        canvas,
        center.translate(-dispersionShift, -dispersionShift * 0.5),
        logoBoxSize,
        const Color(0xFF38BDF8).withValues(alpha: 0.45 * glass),
        const Color(0xFF38BDF8).withValues(alpha: 0.45 * glass),
      );
      _drawQGlyph(
        canvas,
        center.translate(dispersionShift, dispersionShift * 0.5),
        logoBoxSize,
        const Color(0xFF663AF3).withValues(alpha: 0.45 * glass),
        const Color(0xFFF43F5E).withValues(alpha: 0.35 * glass),
      );
    }

    // Main Q Glyph (transitions smoothly to crisp resting logo at normal size)
    _drawQGlyph(
      canvas,
      center,
      logoBoxSize,
      const Color(0xFFFFFFFF),
      const Color(0xFF38BDF8),
    );
  }

  void _drawQGlyph(
    Canvas canvas,
    Offset center,
    double boxSize,
    Color primaryColor,
    Color dotColor,
  ) {
    final ringCenter = Offset(center.dx, center.dy - boxSize * (2 / 64));
    final ringRadius = boxSize * (16 / 64);
    final strokeW = boxSize * (5.5 / 64);

    final gradientRect =
        Rect.fromCenter(center: center, width: boxSize, height: boxSize);
    final ringPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, dotColor],
      ).createShader(gradientRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(ringCenter, ringRadius, ringPaint);

    final tailStart = Offset(
      center.dx + boxSize * ((39 - 32) / 64),
      center.dy + boxSize * ((37 - 32) / 64),
    );
    final tailEnd = Offset(
      center.dx + boxSize * ((49 - 32) / 64),
      center.dy + boxSize * ((47 - 32) / 64),
    );
    canvas.drawLine(tailStart, tailEnd, ringPaint);

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(ringCenter, boxSize * (3.2 / 64), dotPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassLogoPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.unit != unit;
  }
}
