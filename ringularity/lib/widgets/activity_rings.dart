import 'package:flutter/material.dart';
import 'dart:math';
import '../theme/app_colors.dart';
import '../widgets/daily_goals_dialog.dart';

class ActivityRingsCard extends StatelessWidget {
  const ActivityRingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final String goalSteps = "10000";
    final String goalSleep = "8";
    final String goalActivity = "25";

    // Beispielwerte für den aktuellen Fortschritt (nur zur Anzeige)
    final String currentStepsValue = "2069"; 
    final String currentSleepValue = "8h 10m";
    final String currentActivityValue = "20min";    

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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RingLabel(
                          label: "Steps",
                          value: currentStepsValue,
                          subText: "/$goalSteps steps",
                          color: AppColors.accentBlue,
                        ),
                        _RingLabel(
                          label: "Sleep",
                          value: currentSleepValue,
                          subText: "/$goalSleep h",
                          color: AppColors.accentCyan,
                        ),
                        _RingLabel(
                          label: "Activity",
                          value: currentActivityValue,
                          subText: "/$goalActivity min",
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
              onTap: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    return DailyGoalsDialog(
                      currentSteps: goalSteps,       // Übergibt "10000"
                      currentSleep: goalSleep,       // Übergibt "8"
                      currentActivity: goalActivity, // Übergibt "25"
                    );
                  },
              );
             },
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
    const double strokeWidth = 12.0;
    const double spacing = 6.0;

    final center = Offset(size.width / 2, size.height);
    final double baseRadius = min(size.width / 2.2, size.height * 0.9);

    _drawArc(
      canvas,
      center,
      baseRadius,
      AppColors.accentBlue,
      0.4,
      strokeWidth,
    );

    _drawArc(
      canvas,
      center,
      baseRadius - strokeWidth - spacing,
      AppColors.accentCyan,
      0.6,
      strokeWidth,
    );

    _drawArc(
      canvas,
      center,
      baseRadius - (2 * (strokeWidth + spacing)),
      AppColors.accentGreen,
      0.75,
      strokeWidth,
    );
  }

  void _drawArc(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double percent,
    double strokeWidth,
  ) {
    final paintBg = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final paintFg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, pi, pi, false, paintBg);

    canvas.drawArc(rect, pi, pi * percent, false, paintFg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
