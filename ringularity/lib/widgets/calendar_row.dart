import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CalendarRow extends StatelessWidget {
  const CalendarRow({super.key});

  @override
  Widget build(BuildContext context) {
    // Beispielhafte Tage
    final List<String> days = ["M", "T", "W", "T", "F", "S", "S"];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      // Hier geben wir 'isActive: true' mit, damit man die Farben sieht.
      // In einer echten App würdest du das basierend auf Daten steuern.
      children: days.map((day) => _buildDayItem(day, true)).toList(),
    );
  }

  Widget _buildDayItem(String day, bool isActive) {
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
        const SizedBox(height: 4),

        // 1. Äußerer Ring (Blau) - Größe 24
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              // Wenn inaktiv, grau, sonst Blau
              color: isActive
                  ? AppColors.accentBlue
                  : AppColors.textSecondary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Center(
            // 2. Mittlerer Ring (Cyan) - Größe 16
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  // Wenn inaktiv, transparent, sonst Cyan
                  color: isActive ? AppColors.accentCyan : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                // 3. Innerer Ring (Grün) - Größe 8
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      // Wenn inaktiv, transparent, sonst Grün
                      color: isActive
                          ? AppColors.accentGreen
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
