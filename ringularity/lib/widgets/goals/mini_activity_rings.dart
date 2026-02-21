import 'package:flutter/material.dart';
import 'dart:math';
import '../../theme/app_colors.dart';

class MiniActivityRings extends StatelessWidget {
  final double size;
  final double stepsPercent;
  final double activityPercent;
  final double sleepPercent;

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

    // Die Dicke der Ringe passt sich dynamisch der Größe an (ca. 1/15 der Gesamtgröße)
    final strokeWidth = size.width / 12;
    final spacing = strokeWidth / 2;

    // 1. Äußerer Ring (Steps - Blau)
    _drawRing(
      canvas,
      center,
      maxRadius,
      AppColors.accentBlue,
      stepsPercent,
      strokeWidth,
    );

    // 2. Mittlerer Ring (Sleep - Cyan)
    _drawRing(
      canvas,
      center,
      maxRadius - strokeWidth - spacing,
      AppColors.accentCyan,
      sleepPercent,
      strokeWidth,
    );

    // 3. Innerer Ring (Activity - Grün)
    _drawRing(
      canvas,
      center,
      maxRadius - (2 * (strokeWidth + spacing)),
      AppColors.accentGreen,
      activityPercent,
      strokeWidth,
    );
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double percent,
    double width,
  ) {
    // Falls Radius zu klein wird (negativ), nicht zeichnen
    if (radius <= 0) return;

    // Hintergrund (dunkler/transparenter Kreis)
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    canvas.drawCircle(center, radius, bgPaint);

    // Vordergrund (Fortschritt)
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start bei 12 Uhr
      2 * pi * percent, // Voller Kreis = 2 * pi
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
