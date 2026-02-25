import 'package:ringularity/models/sleep_data_model.dart';

/// A data model containing the finalized computations of a sleep session.
class SleepMetrics {
  /// The absolute global rating from 0 to 100.
  final int score;

  /// The percentage of time in bed that was actually spent sleeping (0 to 100).
  final int efficiency;

  /// A human-readable quality label (e.g., "Excellent").
  final String rating;

  final Duration totalDuration;
  final Duration awakeDuration;
  final Duration lightDuration;
  final Duration deepDuration;
  final Duration remDuration;

  /// Creates a new [SleepMetrics] snapshot.
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

/// Utility containing algorithmic logic to grade the user's night of sleep based on clinical baselines.
class SleepScoreCalculator {
  /// Consumes raw granular [sleepData] segments and returns a cohesive [SleepMetrics] summary.
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
      // Hardware codes: 5 = Awake, 4 = REM, 3 = Deep, 2 = Light
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
        lightMinutes += duration;
      }
    }

    final int sleepMinutes = lightMinutes + deepMinutes + remMinutes;
    int efficiency = 0;
    if (totalMinutes > 0) {
      efficiency = ((sleepMinutes / totalMinutes) * 100).round();
    }

    const double wDuration = 0.35;
    const double wEfficiency = 0.25;
    const double wDeep = 0.20;
    const double wRem = 0.20;

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

    if (finalScore > 100) finalScore = 100;
    if (finalScore < 0) finalScore = 0;

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
      totalDuration: Duration(minutes: sleepMinutes),
      awakeDuration: Duration(minutes: awakeMinutes),
      lightDuration: Duration(minutes: lightMinutes),
      deepDuration: Duration(minutes: deepMinutes),
      remDuration: Duration(minutes: remMinutes),
    );
  }

  /// Grades total duration on a curve peaking between 7 and 9 hours.
  static double _calculateDurationScore(int sleepMinutes) {
    if (sleepMinutes >= 420 && sleepMinutes <= 540) return 100;
    if (sleepMinutes < 240) return 0;
    if (sleepMinutes > 600) return 80;

    if (sleepMinutes < 420) {
      return ((sleepMinutes - 240) / (420 - 240)) * 100;
    }
    return 100 - ((sleepMinutes - 540) / (600 - 540)) * 20;
  }

  /// Grades efficiency heavily penalizing values below 90%.
  static double _calculateEfficiencyScore(int efficiency) {
    if (efficiency >= 90) return 100;
    if (efficiency < 50) return 0;
    return ((efficiency - 50) / (90 - 50)) * 100;
  }

  /// Calculates a score based on how well a specific phase ratio aligns with clinical ideals.
  static double _calculateStageScore(
    int stageMinutes,
    int totalSleepMinutes,
    double minPct,
    double maxPct,
  ) {
    if (totalSleepMinutes == 0) return 0;
    final double pct = stageMinutes / totalSleepMinutes;

    if (pct >= minPct && pct <= maxPct) return 100;

    if (pct < minPct) {
      return (pct / minPct) * 100;
    }

    if (pct > maxPct) {
      return 100;
    }
    return 0;
  }
}
