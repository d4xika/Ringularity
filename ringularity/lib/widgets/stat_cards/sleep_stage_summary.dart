import 'package:flutter/material.dart';
import 'package:ringularity/models/sleep_data_model.dart';

class SleepStageSummary extends StatelessWidget {
  final List<SleepData> sleepHistory;

  const SleepStageSummary({super.key, required this.sleepHistory});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Durations
    int awakeMinutes = 0;
    int remMinutes = 0;
    int lightMinutes = 0;
    int deepMinutes = 0;

    for (var s in sleepHistory) {
      if (s.stage == 0x05) awakeMinutes += s.durationMinutes;
      if (s.stage == 0x04) remMinutes += s.durationMinutes;
      if (s.stage == 0x02) lightMinutes += s.durationMinutes;
      // 0x03 is DEEP, not 0x01
      if (s.stage == 0x03) deepMinutes += s.durationMinutes;
    }

    final int totalMinutes =
        awakeMinutes + remMinutes + lightMinutes + deepMinutes;

    if (totalMinutes == 0) return const SizedBox.shrink();

    return Column(
      children: [
        _buildStageRow(
          "Total awake time",
          awakeMinutes,
          totalMinutes,
          const Color(0xFFFF9B9B),
        ),
        const SizedBox(height: 12),
        _buildStageRow(
          "REM duration",
          remMinutes,
          totalMinutes,
          const Color(0xFF9D4BF5),
        ),
        const SizedBox(height: 12),
        _buildStageRow(
          "Total light sleep duration",
          lightMinutes,
          totalMinutes,
          const Color(0xFF4B98F5),
        ),
        const SizedBox(height: 12),
        _buildStageRow(
          "Total deep sleep duration",
          deepMinutes,
          totalMinutes,
          const Color(0xFF1E4578),
        ),
      ],
    );
  }

  Widget _buildStageRow(
    String label,
    int minutes,
    int totalMinutes,
    Color color,
  ) {
    double percentage = 0.0;
    if (totalMinutes > 0) {
      percentage = minutes / totalMinutes;
    }
    final int percentageInt = (percentage * 100).round();
    final String timeString =
        "${(minutes ~/ 60).toString().padLeft(2, '0')}h ${(minutes % 60).toString().padLeft(2, '0')}min";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  children: [
                    TextSpan(
                      text: "$label ",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    TextSpan(
                      text: "$timeString ",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: "$percentageInt%",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Bar Stack
        Stack(
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white10, // Background track
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percentage > 0 ? percentage : 0.01,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
