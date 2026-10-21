import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Anillo de progreso animado con degradado de marca (lima → cian). En
/// rojo si se pasa de la meta.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.stroke = 10,
    this.over = false,
    this.center,
  });

  /// 0–1 (lo que pase de 1 se dibuja lleno).
  final double value;
  final double size;
  final double stroke;
  final bool over;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(v, stroke, over),
          child: Center(child: child),
        ),
        child: center,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.over);

  final double value;
  final double stroke;
  final bool over;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(stroke / 2);
    canvas.drawArc(
      inner, 0, 2 * pi, false,
      Paint()
        ..color = MagraColors.outlineSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (over) {
      paint.color = MagraColors.bad;
    } else {
      paint.shader = const SweepGradient(
        colors: [MagraColors.lime, MagraColors.cyan, MagraColors.lime],
        transform: GradientRotation(-pi / 2),
      ).createShader(rect);
    }
    canvas.drawArc(inner, -pi / 2, 2 * pi * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.over != over || old.stroke != stroke;
}

/// Barra de progreso que se llena con animación.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({super.key, required this.value, this.color, this.height = 8});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: color,
        ),
      ),
    );
  }
}
