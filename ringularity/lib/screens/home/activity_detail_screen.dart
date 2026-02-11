import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_model.dart';
import '../../theme/app_colors.dart';

class ActivityDetailScreen extends StatelessWidget {
  final ActivityModel activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat(
      'HH:mm',
    ).format(activity.date.subtract(activity.duration));
    final endTime = DateFormat('HH:mm').format(activity.date);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Activity Details",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mainColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_run,
                    color: AppColors.mainColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.typeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('d. MMMM yyyy').format(activity.date),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildDetailStat("Time", "$startTime - $endTime"),
                _buildDetailStat(
                  "Duration",
                  "${activity.duration.inMinutes} min",
                ),
                _buildDetailStat(
                  "Distance",
                  "${activity.distanceKm.toStringAsFixed(2)} km",
                ),
                _buildDetailStat("Avg Pace", "5'36'' /km"), // Mock calculation
                _buildDetailStat("Avg HR", "${activity.avgHeartRate} bpm"),
                _buildDetailStat("Calories", "320 kcal"),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              "Heart Rate",
              style: TextStyle(
                color: AppColors.mainColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("Max: 168", style: TextStyle(color: Colors.red)),
                      Text("Avg: 153", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    height: 100,
                    color: Colors.white.withOpacity(0.05),
                    child: const Center(
                      child: Text(
                        "Chart Placeholder",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Map Section
            const Text(
              "Map",
              style: TextStyle(
                color: AppColors.mainColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[800],
                child: Stack(
                  children: [
                    // Hier würde das GoogleMap Widget hinkommen
                    const Center(
                      child: Icon(Icons.map, color: Colors.white54, size: 50),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: Colors.black54,
                        child: const Text(
                          "Zinsenwang",
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
