import 'package:ringularity/models/sleep_data_model.dart';

class SleepMetrics {
  final int score;
  final int efficiency;
  final String rating;
  final Duration totalDuration;
  final Duration awakeDuration;
  final Duration lightDuration;
  final Duration deepDuration;
  final Duration remDuration;

  SleepMetrics({
    required this.score,
    required this.efficiency,
    required this.rating,
    required this.totalDuration,
    required this.awakeDuration,
    required this.lightDuration,
    required this.deepDuration,
    required this.remDuration,
  });
}

class SleepScoreCalculator {
  static SleepMetrics calculate(List<SleepData> sleepData) {
    if (sleepData.isEmpty) {
      return SleepMetrics(
        score: 0,
        efficiency: 0,
        rating: "No Data",
        totalDuration: Duration.zero,
        awakeDuration: Duration.zero,
        lightDuration: Duration.zero,
        deepDuration: Duration.zero,
        remDuration: Duration.zero,
      );
    }

    int totalMinutes = 0;
    int awakeMinutes = 0;
    int lightMinutes = 0;
    int deepMinutes = 0;
    int remMinutes = 0;

    for (var data in sleepData) {
      // 5 = Awake, 4 = REM, 2 = Light, 3 = Deep
      final stage = data.stage;
      final duration = data.durationMinutes;

      totalMinutes += duration;

      if (stage == 5) {
        awakeMinutes += duration;
      } else if (stage == 4) {
        remMinutes += duration;
      } else if (stage == 3) {
        deepMinutes += duration;
      } else {
        // Fallback to Light (2)
        lightMinutes += duration;
      }
    }

    // --- 1. Efficiency Calculation ---
    // Efficiency = (Total Time Asleep / Total Time in Bed) * 100
    // Total Time Asleep = Light + Deep + REM
    // Total Time in Bed = Total Sleep Data Duration (which includes awake periods tracked *during* the session)
    // Note: If the ring tracks pure "in bed but not sleeping" separately, we'd add that.
    // Assuming 'totalMinutes' from the list covers the session duration including awake gaps.

    final int sleepMinutes = lightMinutes + deepMinutes + remMinutes;
    int efficiency = 0;
    if (totalMinutes > 0) {
      efficiency = ((sleepMinutes / totalMinutes) * 100).round();
    }

    // --- 2. Score Calculation (Simplified weighted model) ---
    // Factors:
    // - Duration (0-100): Ideal 7-9 hours (420-540 mins)
    // - Efficiency (0-100): Ideal > 85%
    // - Deep Sleep (0-100): Ideal 15-20%
    // - REM Sleep (0-100): Ideal 20-25%

    // Weights
    const double wDuration = 0.35;
    const double wEfficiency = 0.25;
    const double wDeep = 0.20;
    const double wRem = 0.20;

    // Score Components
    final double sDuration = _calculateDurationScore(sleepMinutes);
    final double sEfficiency = _calculateEfficiencyScore(efficiency);
    final double sDeep = _calculateStageScore(
      deepMinutes,
      sleepMinutes,
      0.15,
      0.20,
    );
    final double sRem = _calculateStageScore(
      remMinutes,
      sleepMinutes,
      0.20,
      0.25,
    );

    int finalScore =
        ((sDuration * wDuration) +
                (sEfficiency * wEfficiency) +
                (sDeep * wDeep) +
                (sRem * wRem))
            .round();

    // Clamp
    if (finalScore > 100) finalScore = 100;
    if (finalScore < 0) finalScore = 0;

    // Rating
    String rating;
    if (finalScore >= 85) {
      rating = "Excellent";
    } else if (finalScore >= 70) {
      rating = "Good";
    } else if (finalScore >= 50) {
      rating = "Fair";
    } else {
      rating = "Poor";
    }

    return SleepMetrics(
      score: finalScore,
      efficiency: efficiency,
      rating: rating,
      totalDuration: Duration(
        minutes: sleepMinutes,
      ), // "Total Duration" usually refers to sleep time
      awakeDuration: Duration(minutes: awakeMinutes),
      lightDuration: Duration(minutes: lightMinutes),
      deepDuration: Duration(minutes: deepMinutes),
      remDuration: Duration(minutes: remMinutes),
    );
  }

  static double _calculateDurationScore(int sleepMinutes) {
    // 7h (420m) to 9h (540m) = 100
    // < 4h (240m) = 0
    if (sleepMinutes >= 420 && sleepMinutes <= 540) return 100;
    if (sleepMinutes < 240) return 0;
    if (sleepMinutes > 600) return 80; // Oversleeping penalty?

    // Linear ramp up 4h->7h
    if (sleepMinutes < 420) {
      return ((sleepMinutes - 240) / (420 - 240)) * 100;
    }
    // Linear ramp down 9h->10h
    return 100 - ((sleepMinutes - 540) / (600 - 540)) * 20;
  }

  static double _calculateEfficiencyScore(int efficiency) {
    if (efficiency >= 90) return 100;
    if (efficiency < 50) return 0;
    // Linear 50->90
    return ((efficiency - 50) / (90 - 50)) * 100;
  }

  static double _calculateStageScore(
    int stageMinutes,
    int totalSleepMinutes,
    double minPct,
    double maxPct,
  ) {
    if (totalSleepMinutes == 0) return 0;
    final double pct = stageMinutes / totalSleepMinutes;

    if (pct >= minPct && pct <= maxPct) return 100;

    // Penalize if too low
    if (pct < minPct) {
      return (pct / minPct) * 100;
    }

    // Penalize if too high (rare)
    if (pct > maxPct) {
      // e.g. double max is still ok, but maybe 80?
      // For simplicity, cap at 100 if higher.
      return 100;
    }
    return 0;
  }
}
