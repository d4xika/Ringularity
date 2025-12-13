import 'package:flutter/material.dart';
import 'dart:math';
import '../theme/app_colors.dart';

class ActivityRingsCard extends StatelessWidget {
  const ActivityRingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _RingsPainter(),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 5),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RingLabel(
                          label: "Steps",
                          value: "2.069",
                          subText: "/10k",
                          color: AppColors.accentBlue,
                        ),
                        _RingLabel(
                          label: "Sleep",
                          value: "8h 10m",
                          subText: "/8h",
                          color: AppColors.accentCyan,
                        ),
                        _RingLabel(
                          label: "Activity",
                          value: "20min",
                          subText: "/25min",
                          color: AppColors.accentGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: 15,
            right: 15,
            child: GestureDetector(
              onTap: () {},
              child: Icon(
                Icons.edit_outlined,
                size: 20,
                color: Colors.white70.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingLabel extends StatelessWidget {
  final String label;
  final String value;
  final String subText;
  final Color color;

  const _RingLabel({
    required this.label,
    required this.value,
    required this.subText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(subText, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final double radius = min(size.width / 2.2, size.height * 0.9);

    _drawArc(canvas, center, radius, AppColors.accentBlue, 0.4);
    _drawArc(canvas, center, radius * 0.85, AppColors.accentCyan, 0.6);
    _drawArc(canvas, center, radius * 0.70, AppColors.accentGreen, 0.75);
  }

  void _drawArc(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double percent,
  ) {
    final double strokeWidth = 11;

    final paintBg = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final paintFg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      paintBg,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * percent,
      false,
      paintFg,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
