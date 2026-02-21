class SleepData {
  final DateTime timestamp;
  final int stage;
  final int durationMinutes;

  SleepData({
    required this.timestamp,
    required this.stage,
    required this.durationMinutes,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'stage': stage,
    'durationMinutes': durationMinutes,
  };

  factory SleepData.fromJson(Map<String, dynamic> json) => SleepData(
    timestamp: DateTime.parse(json['timestamp']),
    stage: json['stage'] ?? 0,
    durationMinutes: json['durationMinutes'] ?? 0,
  );

  @override
  String toString() {
    return 'SleepData(time: ${timestamp.hour}:${timestamp.minute}, stage: $stage, duration: $durationMinutes minutes)';
  }
}
