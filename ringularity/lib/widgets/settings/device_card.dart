import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/text_styles.dart';

/// A stylized dashboard card displaying the status of an actively connected smart ring.
///
/// Features the device name, battery percentage, an "Unbind" action, and a quick link
/// to modify the ring's background monitoring intervals.
class DeviceCard extends StatelessWidget {
  /// The human-readable name or MAC address of the connected ring.
  final String deviceName;

  /// A formatted string representing the current battery level (e.g., "75%").
  final String batteryLevel;

  /// Callback triggered to sever the BLE bond and disconnect the device.
  final VoidCallback onUnbind;

  /// Callback triggered to open the monitoring configuration bottom sheet.
  final VoidCallback onEditFrequency;

  /// Creates a new [DeviceCard] instance.
  const DeviceCard({
    super.key,
    required this.deviceName,
    required this.batteryLevel,
    required this.onUnbind,
    required this.onEditFrequency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deviceName, style: AppTextStyles.subsubtitle),
                  const Text(
                    "Connected",
                    style: TextStyle(
                      color: AppColors.mainColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Battery: $batteryLevel",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: onUnbind,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mainColor,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Unbind",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: onEditFrequency,
            child: const Text(
              "Edit monitoring settings",
              style: TextStyle(color: AppColors.mainColor),
            ),
          ),
        ],
      ),
    );
  }
}
