import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:ringularity/models/sleep_data.dart';

import '../vitals_storage_service.dart';
import 'ble_data_processor.dart';
import 'ble_logger.dart';

/// Manages all the sensor data state (Current values, Histories).
/// Implements [BleDataCallbacks] to receive parsed data from the processor.
class BleDataManager extends ChangeNotifier implements BleDataCallbacks {
  final BleLogger logger;

  VitalsStorageService? _storageService;

  // Optional callbacks for controller logic
  Function(int)? onHeartRateReceivedCallback;
  Function(int)? onSpo2ReceivedCallback;
  Function(int)? onStressReceivedCallback;
  Function(int)? onHrvReceivedCallback;
  Function(int)? onNotificationCallback; // For sync logic
  Function()? onActivityReceivedCallback; // For detecting runaway activity

  BleDataManager({required this.logger});

  void setStorageService(VitalsStorageService service) {
    _storageService = service;
  }

  // --- UI State (Getters) ---
  // Exposes current sensor values and formatted logic for the UI to consume.
  // Notifies listeners whenever a value changes.
  int _batteryLevel = 0;
  int get batteryLevel => _batteryLevel;

  int _heartRate = 0;
  DateTime? _lastHrTime;
  int get heartRate => _heartRate;
  String get heartRateTime => _formatTime(_lastHrTime);

  int _spo2 = 0;
  DateTime? _lastSpo2Time;
  int get spo2 => _spo2;
  String get spo2Time => _formatTime(_lastSpo2Time);

  int _stress = 0;
  DateTime? _lastStressTime;
  int get stress => _stress;
  String get stressTime => _formatTime(_lastStressTime);

  int _hrv = 0;
  DateTime? _lastHrvTime;
  int get hrv => _hrv;
  String get hrvTime => _formatTime(_lastHrvTime);

  int _steps = 0;
  DateTime? _lastStepsTime;
  int get steps => _steps;
  String get stepsTime => _formatTime(_lastStepsTime, isDaily: true);

  int _distance = 0;
  int get distance => _distance;

  int _calories = 0;
  int get calories => _calories;

  final int _activeMinutes = 0;
  int get activeMinutes => _activeMinutes;

  // Goal State
  int _goalSteps = 10000;
  double _goalSleep = 8.0;
  int _goalActivity = 30;

  int get goalSteps => _goalSteps;
  double get goalSleep => _goalSleep;
  int get goalActivity => _goalActivity;

  void setGoals({int? steps, double? sleep, int? activity}) {
    if (steps != null) _goalSteps = steps;
    if (sleep != null) _goalSleep = sleep;
    if (activity != null) _goalActivity = activity;
    notifyListeners();
  }

  // History Data
  // Stores historical data points for graphs.
  // Each list corresponds to a specific metric's history for the selected date.
  final List<Point> _hrHistory = [];
  final List<Point> _spo2History = [];
  final List<Point> _stressHistory = [];
  final List<Point> _hrvHistory = [];
  final List<Point> _stepsHistory = [];
  final List<SleepData> _sleepHistory = [];

  List<Point> get hrHistory => List.unmodifiable(_hrHistory);
  List<Point> get spo2History => List.unmodifiable(_spo2History);
  List<Point> get stressHistory => List.unmodifiable(_stressHistory);
  List<Point> get hrvHistory => List.unmodifiable(_hrvHistory);
  List<Point> get stepsHistory => List.unmodifiable(_stepsHistory);
  List<SleepData> get sleepHistory => List.unmodifiable(_sleepHistory);

  // Computed Sleep
  int get totalSleepMinutes => _sleepHistory.fold(0, (sum, item) {
    return (item.stage != 5) ? sum + item.durationMinutes : sum;
  });

  String get totalSleepTimeFormatted {
    if (totalSleepMinutes == 0) return "0h 0m";
    final int hours = totalSleepMinutes ~/ 60;
    final int minutes = totalSleepMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  // Raw Streams
  final StreamController<List<int>> _accelStreamController =
      StreamController<List<int>>.broadcast();
  Stream<List<int>> get accelStream => _accelStreamController.stream;

  final StreamController<List<int>> _ppgStreamController =
      StreamController<List<int>>.broadcast();
  Stream<List<int>> get ppgStream => _ppgStreamController.stream;

  // Selected Date context
  // Controls which date's data is currently being viewed/stored.
  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  void setSelectedDate(DateTime date) {
    if (_isSameDay(date, _selectedDate)) return;
    _selectedDate = date;

    _clearMemory();

    final cached = _storageService?.getVitalsForDate(date);
    if (cached != null) {
      _hrHistory.addAll(cached.hrTrace);
      _stepsHistory.addAll(cached.stepsTrace);
      _spo2History.addAll(cached.spo2Trace);
      _stressHistory.addAll(cached.stressTrace);
      _sleepHistory.addAll(cached.sleepTrace);

      _steps = cached.steps;
      _distance = cached.distance;
      _updateDerivedMetrics();
    }

    notifyListeners();
  }

  void _clearMemory() {
    _hrHistory.clear();
    _spo2History.clear();
    _stressHistory.clear();
    _hrvHistory.clear();
    _stepsHistory.clear();
    _sleepHistory.clear();
    _steps = 0;
    _distance = 0;
    _calories = 0;
  }

  void _persistUpdate() {
    if (_storageService == null) return;

    final data = DailyVitals(
      date: _selectedDate,
      steps: _steps,
      distance: _distance,
      avgHr: _calculateAvg(_hrHistory),
      avgStress: _calculateAvg(_stressHistory),
      avgSpo2: _calculateAvg(_spo2History),
      totalSleepMinutes: totalSleepMinutes,
      hrTrace: List.from(_hrHistory),
      stepsTrace: List.from(_stepsHistory),
      spo2Trace: List.from(_spo2History),
      stressTrace: List.from(_stressHistory),
      sleepTrace: List.from(_sleepHistory),
    );

    _storageService!.saveToday(data);
  }

  int _calculateAvg(List<Point> points) {
    if (points.isEmpty) return 0;
    return (points.fold<double>(0, (sum, p) => sum + p.y) / points.length)
        .round();
  }

  // Methods to manually populate history (e.g. from API/DB)
  void setHrHistory(List<Point> data) {
    _hrHistory.clear();
    _hrHistory.addAll(data);
    notifyListeners();
  }

  void setSpo2History(List<Point> data) {
    _spo2History.clear();
    _spo2History.addAll(data);
    notifyListeners();
  }

  void setStressHistory(List<Point> data) {
    _stressHistory.clear();
    _stressHistory.addAll(data);
    notifyListeners();
  }

  void setHrvHistory(List<Point> data) {
    _hrvHistory.clear();
    _hrvHistory.addAll(data);
    notifyListeners();
  }

  void setStepsHistory(List<Point> data) {
    _stepsHistory.clear();
    _stepsHistory.addAll(data);
    _steps = _stepsHistory.fold<int>(0, (sum, p) => sum + p.y.toInt());
    _updateDerivedMetrics();
    notifyListeners();
  }

  void setSleepHistory(List<SleepData> data) {
    _sleepHistory.clear();
    _sleepHistory.addAll(data);
    notifyListeners();
  }

  @override
  void dispose() {
    _accelStreamController.close();
    _ppgStreamController.close();
    super.dispose();
  }

  // --- BleDataCallbacks Implementation ---

  @override
  void onProtocolLog(String message) {
    logger.addToProtocolLog(message);
  }

  @override
  void onRawLog(String message) {
    logger.setLastLog(message);
  }

  @override
  void onHeartRate(int bpm) {
    if (bpm > 0) {
      _heartRate = bpm;
      _lastHrTime = DateTime.now();
      notifyListeners();
      // Forward to other listeners (e.g., UI controllers that need instantaneous updates)
      onHeartRateReceivedCallback?.call(bpm);
    }
  }

  @override
  void onHrv(int val) {
    if (val > 0) {
      _hrv = val;
      _lastHrvTime = DateTime.now();
      onHrvReceivedCallback?.call(val);

      final now = DateTime.now();
      if (_isSameDay(_selectedDate, now)) {
        final int minutes = now.hour * 60 + now.minute;
        _hrvHistory.removeWhere((p) => p.x == minutes);
        _hrvHistory.add(Point(minutes, val));
        _hrvHistory.sort((a, b) => a.x.compareTo(b.x));

        _persistUpdate();
      }
      notifyListeners();
    }
  }

  @override
  void onStress(int level) {
    if (level > 0) {
      _stress = level;
      _lastStressTime = DateTime.now();

      final now = DateTime.now();
      if (_isSameDay(_selectedDate, now)) {
        final int minutes = now.hour * 60 + now.minute;
        _stressHistory.add(Point(minutes, level));

        _persistUpdate();
      }

      notifyListeners();
      onStressReceivedCallback?.call(level);
    }
  }

  @override
  void onSpo2(int percent) {
    if (percent > 0) {
      _spo2 = percent;
      _lastSpo2Time = DateTime.now();

      final now = DateTime.now();
      if (_isSameDay(_selectedDate, now)) {
        final int minutes = now.hour * 60 + now.minute;
        _spo2History.add(Point(minutes, percent));

        _persistUpdate();
      }

      notifyListeners();
      onSpo2ReceivedCallback?.call(percent);
    }
  }

  @override
  void onActivityUpdate({
    required int steps,
    required int bpm,
    required int calories,
    required int distance,
    required int duration,
  }) {
    _activitySteps = steps;
    _activityDuration = duration;
    if (bpm > 0) _heartRate = bpm;

    if (steps > _steps) {
      _steps = steps;
      _lastStepsTime = DateTime.now();
      _updateDerivedMetrics();

      _persistUpdate();
    }

    notifyListeners();
    onActivityReceivedCallback?.call();
  }

  @override
  void onBattery(int level) {
    _batteryLevel = level;
    notifyListeners();
  }

  @override
  void onRawAccel(List<int> data) {
    _accelStreamController.add(data);
  }

  @override
  void onRawPPG(List<int> data) {
    _ppgStreamController.add(data);
  }

  @override
  void onHeartRateHistoryPoint(DateTime timestamp, int bpm) {
    if (bpm > 0 && _isSameDay(timestamp, _selectedDate)) {
      final int minutes = timestamp.hour * 60 + timestamp.minute;
      _hrHistory.add(Point(minutes, bpm));
      _persistUpdate();
      notifyListeners();
    }
  }

  @override
  void onStepsHistoryPoint(DateTime timestamp, int steps, int quarterIndex) {
    if (_isSameDay(timestamp, _selectedDate)) {
      _stepsHistory.removeWhere((p) => p.x == quarterIndex);
      _stepsHistory.add(Point(quarterIndex, steps));
      _steps = _stepsHistory.fold<int>(0, (sum, p) => sum + p.y.toInt());
      _updateDerivedMetrics();
      _persistUpdate();
      notifyListeners();
    }
  }

  @override
  void onSleepHistoryPoint(
    DateTime timestamp,
    int sleepStage, {
    int durationMinutes = 0,
  }) {
    _sleepHistory.removeWhere((item) => item.timestamp == timestamp);

    final bool match =
        _isSameDay(timestamp, _selectedDate) ||
        (_isSameDay(
              timestamp,
              _selectedDate.subtract(const Duration(days: 1)),
            ) &&
            timestamp.hour >= 12);

    if (match) {
      _sleepHistory.add(
        SleepData(
          timestamp: timestamp,
          stage: sleepStage,
          durationMinutes: durationMinutes,
        ),
      );
      _sleepHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _persistUpdate();
      notifyListeners();
    }
  }

  @override
  void onSpo2HistoryPoint(DateTime timestamp, int percent) {
    if (percent > 0 && _isSameDay(timestamp, _selectedDate)) {
      final int minutes = timestamp.hour * 60 + timestamp.minute;
      _spo2History.removeWhere((p) => p.x == minutes);
      _spo2History.add(Point(minutes, percent));
      _persistUpdate();
      notifyListeners();
    }
  }

  @override
  void onStressHistoryPoint(DateTime timestamp, int level) {
    if (level > 0 && _isSameDay(timestamp, _selectedDate)) {
      final int minutes = timestamp.hour * 60 + timestamp.minute;
      _stressHistory.add(Point(minutes, level));
      _persistUpdate();
      notifyListeners();
    }
  }

  @override
  void onHrvHistoryPoint(DateTime timestamp, int val) {
    if (val > 0) {
      if (_lastHrvTime == null || timestamp.isAfter(_lastHrvTime!)) {
        _hrv = val;
        _lastHrvTime = timestamp;
      }
    }

    final bool exists = _hrvHistory.any((p) {
      final int minutes = timestamp.hour * 60 + timestamp.minute;
      return p.x == minutes && p.y == val;
    });
    if (!exists) {
      final int minutes = timestamp.hour * 60 + timestamp.minute;
      _hrvHistory.add(Point(minutes, val));
      _hrvHistory.sort((a, b) => a.x.compareTo(b.x));
      notifyListeners();
    }
  }

  // --- Helpers ---
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTime(DateTime? dt, {bool isDaily = false}) {
    if (dt == null) return "No Data";
    if (isDaily) return "Today";
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else {
      return "${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
  }

  // --- Other Callbacks ---
  @override
  void onAutoConfigRead(String type, bool enabled) {
    // This probably belongs in Service or Controller to manage the switch state
    // But DataManager receives it. We can just log it or expose it.
    // Let's assume BleService asks 'Controller' to query, so Controller should handle this?
    // Unclear separation. For now, we will ignore here or pass up?
    // BleService had config state: _hrAutoEnabled etc.
    // We should probably keep that state here too.
  }

  // Auto-Monitor Config State (Moved from Service)
  bool hrAutoEnabled = false;
  int hrInterval = 5;
  bool spo2AutoEnabled = false;
  bool stressAutoEnabled = false;
  bool hrvAutoEnabled = false;

  void updateAutoConfig(String type, bool enabled) {
    if (type == "HR") {
      hrAutoEnabled = enabled;
    } else if (type == "SpO2") {
      spo2AutoEnabled = enabled;
    } else if (type == "Stress") {
      stressAutoEnabled = enabled;
    } else if (type == "HRV") {
      hrvAutoEnabled = enabled;
    }
    notifyListeners();
  }

  @override
  void onNotification(int type) {
    debugPrint("Notification Type: ${type.toRadixString(16)}");
    onNotificationCallback?.call(type);
  }

  @override
  void onFindDevice() {
    debugPrint("Ring requested FIND DEVICE");
    logger.setLastLog("Ring Find Device Request");
  }

  @override
  void onGoalsRead(
    int steps,
    int calories,
    int distance,
    int sport,
    int sleep,
  ) {
    debugPrint(
      "Goals (Targets/Total): Steps=$steps Cals=$calories Dist=$distance Sport=$sport Sleep=$sleep",
    );
    // 0x21 appears to be "Goals" or "Device Totals" which don't match our history.
    // We will NOT overwrite our calculated/history-based values with these.
    // If we wanted to show "Daily Goal: 5000", we would store this in separate variable.
    // For now, ignoring to prevent data corruption on dashboard.
  }

  void _updateDerivedMetrics() {
    // Average stride length ~0.762 meters
    _distance = (_steps * 0.762).toInt();

    // Average calories per step ~0.04 kcal
    _calories = (_steps * 0.04).toInt();

    notifyListeners();
  }

  @override
  void onMeasurementError(int type, int errorCode) {
    debugPrint("Measurement Error: Type=$type Code=$errorCode");
    logger.setLastLog("Error: T=$type C=$errorCode");
  }

  // --- Activity Data ---
  int _activitySteps = 0;
  int _activityDuration = 0;

  int get activitySteps => _activitySteps;
  int get activityDuration => _activityDuration;

  @override
  void onActivityPacketReceived() {
    onActivityReceivedCallback?.call();
  }

  void resetActivityStats() {
    _activitySteps = 0;
    _activityDuration = 0;
    notifyListeners();
  }
}
