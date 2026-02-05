import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

class DeviceCard extends StatelessWidget {
  final String deviceName;
  final String batteryLevel;
  final VoidCallback onUnbind;
  final VoidCallback onEditFrequency;

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
                  "unbind",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: onEditFrequency,
            child: const Text(
              "Edit track Frequency",
              style: TextStyle(color: AppColors.mainColor),
            ),
          ),
        ],
      ),
    );
  }
}
