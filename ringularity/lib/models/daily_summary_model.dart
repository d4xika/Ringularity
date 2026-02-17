class DailySummaryModel {
  final DateTime date;

  final int steps;
  final double sleepHours;
  final int activityMinutes;

  final int goalSteps;
  final double goalSleep;
  final int goalActivity;

  DailySummaryModel({
    required this.date,
    required this.steps,
    required this.sleepHours,
    required this.activityMinutes,
    required this.goalSteps,
    required this.goalSleep,
    required this.goalActivity,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'steps': steps,
      'sleepHours': sleepHours,
      'activityMinutes': activityMinutes,
      'goalSteps': goalSteps,
      'goalSleep': goalSleep,
      'goalActivity': goalActivity,
    };
  }

  factory DailySummaryModel.fromJson(Map<String, dynamic> json) {
    return DailySummaryModel(
      date: DateTime.parse(json['date']),
      steps: json['steps'] ?? 0,
      sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 0.0,
      activityMinutes: json['activityMinutes'] ?? 0,
      goalSteps: json['goalSteps'] ?? 10000,
      goalSleep: (json['goalSleep'] as num?)?.toDouble() ?? 8.0,
      goalActivity: json['goalActivity'] ?? 30,
    );
  }
}
