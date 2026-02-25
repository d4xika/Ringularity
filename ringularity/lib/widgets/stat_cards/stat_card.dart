import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// A generic, tappable square card used to display a single top-level metric on the dashboard.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;
  final VoidCallback? onTap;

  /// Creates a new [StatCard] instance.
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor ?? Colors.white70, size: 28),
                const SizedBox(height: 12),
                Text(value, style: AppTextStyles.subsubtitle),
                const SizedBox(height: 4),
                Text(label, style: AppTextStyles.bodygrey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
