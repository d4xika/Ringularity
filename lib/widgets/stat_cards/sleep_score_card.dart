import 'package:flutter/material.dart';
import 'package:ringularity/theme/app_colors.dart';

import '../../theme/text_styles.dart';

/// Legacy/Alternative Widget for displaying a prominent, circular sleep score.
/// Currently supplanted by [SleepMetricsSummary] in the main history view,
/// but kept for dashboard or summary usage.
class SleepScoreCard extends StatelessWidget {
  final int score;
  final int efficiency;
  final String quality;
  final Duration totalDuration;
  final String startTime;
  final String endTime;

  /// Creates a new [SleepScoreCard] instance.
  const SleepScoreCard({
    super.key,
    required this.score,
    required this.efficiency,
    required this.quality,
    required this.totalDuration,
    required this.startTime,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    if (score >= 85) {
      scoreColor = AppColors.mainColor;
    } else if (score >= 70) {
      scoreColor = const Color(0xFF4B98F5);
    } else if (score >= 50) {
      scoreColor = Colors.orangeAccent;
    } else {
      scoreColor = Colors.redAccent;
    }

    final int hours = totalDuration.inHours;
    final int minutes = totalDuration.inMinutes.remainder(60);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Duration",
                      style: AppTextStyles.bodygrey.copyWith(fontSize: 14),),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "$hours",
                          style: AppTextStyles.subsubtitle.copyWith(fontSize: 32),
                        ),
                        Text(
                          " h ",
                          style: AppTextStyles.bodygrey.copyWith(fontSize: 14),
                        ),
                        Text(
                          "$minutes",
                          style: AppTextStyles.subsubtitle.copyWith(fontSize: 32),
                        ),
                        Text(
                          " min",
                          style: AppTextStyles.bodygrey.copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$startTime - $endTime",
                      style: AppTextStyles.bodygrey.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),

              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: score / 100.0,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$score",
                        style: AppTextStyles.subsubtitle.copyWith(fontSize: 22),
                      ),
                      Text(
                        "Score",
                        style: AppTextStyles.bodygrey.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.rocket_launch,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "$efficiency%",
                          style: AppTextStyles.subsubtitle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Sleep Efficiency",
                      style: AppTextStyles.bodygrey.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),

              Container(width: 1, height: 30, color: Colors.white10),

              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield_moon,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          quality,
                          style: AppTextStyles.subsubtitle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Sleep Quality",
                      style: AppTextStyles.bodygrey.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
