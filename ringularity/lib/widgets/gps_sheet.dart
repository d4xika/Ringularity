import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class GpsSheet extends StatelessWidget {
  final VoidCallback onYes;
  final VoidCallback onNo;

  const GpsSheet({super.key, required this.onYes, required this.onNo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 30),

          const Text(
            "GPS Tracking",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Do you want to use GPS from your phone for this session?",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 30),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onNo,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  child: const Text(
                    "No",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: ElevatedButton(
                  onPressed: onYes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mainColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Yes",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
