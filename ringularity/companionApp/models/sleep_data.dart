class SleepData {
  final DateTime timestamp;
  final int stage; // 2=Light, 3=Deep, 5=Awake
  final int durationMinutes;

  SleepData({
    required this.timestamp,
    required this.stage,
    required this.durationMinutes,
  });

  @override
  String toString() {
    return 'SleepData(time: \${timestamp.hour}:\${timestamp.minute}, stage: \$stage)';
  }
}
