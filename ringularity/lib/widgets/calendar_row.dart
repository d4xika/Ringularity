import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_activity_rings.dart';

class CalendarRow extends StatelessWidget {
  const CalendarRow({super.key});

  @override
  Widget build(BuildContext context) {
    // Beispielhafte Tage
    final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      // Logik ändern sobald Daten von Server geladen werden
      // Hier nehmen wir an, dass alle Tage aktiv bzw. TRUE sind.
      children: days.map((day) => _buildDayItem(day, true)).toList(),
    );
  }

  Widget _buildDayItem(String day, bool isActive) {
    // Wenn aktiv, alle Ringe voll (1.0), sonst leer (0.0)
    final double progress = isActive ? 1.0 : 0.0;

    return Column(
      children: [
        Text(
          day,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8), 

        MiniActivityRings(
          size: 28, // Größe zentral steuern
          stepsPercent: progress,
          sleepPercent: progress,
          activityPercent: progress,
        ),
      ],
    );
  }
}
