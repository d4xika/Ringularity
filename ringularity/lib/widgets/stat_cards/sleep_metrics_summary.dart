import 'package:flutter/material.dart';
import 'package:ringularity/utils/sleep_score_calculator.dart';

import 'metric_row.dart';

class SleepMetricsSummary extends StatelessWidget {
  final SleepMetrics sleepMetrics;

  const SleepMetricsSummary({super.key, required this.sleepMetrics});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Column(
        children: [
          MetricRow(
            label: "Sleep Score",
            value: "${sleepMetrics.score}",
            icon: Icons.speed,
          ),
          const SizedBox(height: 12),
          MetricRow(
            label: "Efficiency",
            value: "${sleepMetrics.efficiency}%",
            icon: Icons.rocket_launch,
          ),
          const SizedBox(height: 12),
          MetricRow(
            label: "Quality",
            value: sleepMetrics.rating,
            icon: Icons.shield_moon,
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
        ],
      ),
    );
  }
}
