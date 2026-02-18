class WeeklyGoal {
  final String id;
  final String activityType;
  final double targetValue;
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
