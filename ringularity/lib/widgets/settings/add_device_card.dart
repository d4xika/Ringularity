import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

class AddDeviceCard extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final IconData icon;

  const AddDeviceCard({
    super.key,
    required this.onTap,
    this.title = "Connect Device",
    this.icon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.mainColor, size: 40),
            const SizedBox(height: 8),
            Text(title, style: AppTextStyles.subsubtitle),
          ],
        ),
      ),
    );
  }
}
