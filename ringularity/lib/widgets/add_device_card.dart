import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

class AddDeviceCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddDeviceCard({super.key, required this.onTap});

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
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.mainColor, size: 40),
            SizedBox(height: 8),
            Text("Connect Device", style: AppTextStyles.subsubtitle),
          ],
        ),
      ),
    );
  }
}
