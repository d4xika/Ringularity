import 'package:flutter/material.dart';
import 'dart:math';
import '../../theme/app_colors.dart';

class BatteryIndicator extends StatelessWidget {
  final double percentage;

  const BatteryIndicator({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BatteryPainter(
        percentage: percentage,
        color: AppColors.accentGreen,
        backgroundColor: Colors.grey.withValues(alpha: 0.3),
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: const Icon(Icons.bolt, color: AppColors.accentGreen, size: 17),
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color backgroundColor;

  _BatteryPainter({
    required this.percentage,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    const strokeWidth = 3.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * percentage,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}
