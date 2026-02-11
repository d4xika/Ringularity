enum ActivityType {
  walk,
  run,
  cycling,
  hiking,
  swimming,
  gym,
  yoga,
  dance,
  pilates,
  individual,
}

class ActivityModel {
  final ActivityType type;
  final String? customTitle;
  final DateTime date;
  final Duration duration;
  final double distanceKm;
  final int avgHeartRate;
  final int steps;

  ActivityModel({
    required this.type,
    this.customTitle,
    required this.date,
    required this.duration,
    required this.distanceKm,
    required this.avgHeartRate,
    this.steps = 0,
  });

  String get typeName {
    if (type == ActivityType.individual &&
        customTitle != null &&
        customTitle!.isNotEmpty) {
      return customTitle!;
    }
    return type.toString().split('.').last.toUpperCase();
  }
}
