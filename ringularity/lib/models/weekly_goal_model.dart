/// A customizable fitness target set by the user for a rolling week.
class WeeklyGoal {
  final String id;

  /// The identifier of the targeted metric (e.g., 'steps', 'running').
  final String activityType;

  final double targetValue;

  /// The unit of measurement (e.g., 'steps', 'hours').
  final String unit;

  WeeklyGoal({
    required this.id,
    required this.activityType,
    required this.targetValue,
    required this.unit,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityType': activityType,
      'targetValue': targetValue,
      'unit': unit,
    };
  }

  factory WeeklyGoal.fromJson(Map<String, dynamic> json) {
    return WeeklyGoal(
      id: json['id'],
      activityType: json['activityType'],
      targetValue: json['targetValue'] is int
          ? (json['targetValue'] as int).toDouble()
          : json['targetValue'],
      unit: json['unit'],
    );
  }

  WeeklyGoal copyWith({
    String? id,
    String? activityType,
    double? targetValue,
    String? unit,
  }) {
    return WeeklyGoal(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
    );
  }
}
