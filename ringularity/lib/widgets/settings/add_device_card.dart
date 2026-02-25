import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// A prominent call-to-action card encouraging the user to initiate a BLE scan.
///
/// Displayed prominently on the settings screen when no device is currently paired or connected.
class AddDeviceCard extends StatelessWidget {
  /// Callback triggered when the card is tapped.
  final VoidCallback onTap;

  /// The primary instructional text. Defaults to "Connect Device".
  final String title;

  /// The visual icon displayed above the title. Defaults to [Icons.add_rounded].
  final IconData icon;

  /// Creates a new [AddDeviceCard] instance.
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
