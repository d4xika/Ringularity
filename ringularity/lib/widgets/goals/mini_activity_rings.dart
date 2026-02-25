import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A static, scaled-down version of the primary ActivityRingsCard used heavily in list views and calendars.
class MiniActivityRings extends StatelessWidget {
  /// Defines both the width and height bounds of the widget.
  final double size;

  final double stepsPercent;
  final double activityPercent;
  final double sleepPercent;

  /// Creates a new [MiniActivityRings] instance.
  const MiniActivityRings({
    super.key,
    required this.size,
    required this.stepsPercent,
    required this.activityPercent,
    required this.sleepPercent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MiniRingsPainter(
          stepsPercent: stepsPercent,
          activityPercent: activityPercent,
          sleepPercent: sleepPercent,
        ),
      ),
    );
  }
}

/// Computes the correct radii, spacing, and stroke widths for a dense cluster of three progress rings.
class _MiniRingsPainter extends CustomPainter {
  final double stepsPercent;
  final double activityPercent;
  final double sleepPercent;

  _MiniRingsPainter({
    required this.stepsPercent,
    required this.activityPercent,
    required this.sleepPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final strokeWidth = size.width / 12;
    final spacing = strokeWidth / 2;

    _drawRing(
      canvas,
      center,
      maxRadius,
      AppColors.accentBlue,
      stepsPercent,
      strokeWidth,
    );

    _drawRing(
      canvas,
      center,
      maxRadius - strokeWidth - spacing,
      AppColors.accentCyan,
      sleepPercent,
      strokeWidth,
    );

    _drawRing(
      canvas,
      center,
      maxRadius - (2 * (strokeWidth + spacing)),
      AppColors.accentGreen,
      activityPercent,
      strokeWidth,
    );
  }

  /// Draws the semi-transparent track and the colored progress fill for a single ring.
  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double percent,
    double width,
  ) {
    if (radius <= 0) return;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * percent,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
