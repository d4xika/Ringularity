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
  int get avgHrv => _calculateAvg(_hrvHistory);
  String get hrvTime => _formatTime(_lastHrvTime);

  int _steps = 0;
  DateTime? _lastStepsTime;
  int get steps => _steps;
  String get stepsTime => _formatTime(_lastStepsTime, isDaily: true);

  // Track live steps for TODAY independently of history view
  int _realTimeSteps = 0;
  int get realTimeSteps => _realTimeSteps;

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
  int get totalSleepMinutes =>
      getSleepDataForDate(_selectedDate).fold(0, (sum, item) {
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
      _hrvHistory.addAll(cached.hrvTrace);

      // FIX: Remove existing sleep data for the target date to avoid duplicates
      // We want to replace any existing data for this date with the cached version
      _sleepHistory.removeWhere((s) => _isSleepDataForDate(s, date));
      _sleepHistory.addAll(cached.sleepTrace);

      _steps = cached.steps;
      _distance = cached.distance;

      // Update current values from loaded history
      _updateLatestFromHistory(_stressHistory, (v, t) {
        _stress = v;
        _lastStressTime = t;
      });
      _updateLatestFromHistory(_hrvHistory, (v, t) {
        _hrv = v;
        _lastHrvTime = t;
      });
      _updateLatestFromHistory(_spo2History, (v, t) {
        _spo2 = v;
        _lastSpo2Time = t;
      });
      _updateLatestFromHistory(_hrHistory, (v, t) {
        _heartRate = v;
        _lastHrTime = t;
      });

      // Filter out invalid 0 values from history to prevent skewing averages
      _hrHistory.removeWhere((p) => p.y <= 0);
      _stressHistory.removeWhere((p) => p.y <= 0);
      _spo2History.removeWhere((p) => p.y <= 0);
      _hrvHistory.removeWhere((p) => p.y <= 0);

      _deleteduplicateSleepHistory();
      _updateDerivedMetrics();
    }

    notifyListeners();
  }

  void _deleteduplicateSleepHistory() {
    final seen = <String>{};
    final unique = <SleepData>[];

    // Sort to keep inconsistent duplicates deterministic usually,
    // but here we just want to remove exact same timestamp/stage entries
    // that might have accumulated.
    for (final item in _sleepHistory) {
      final key = "${item.timestamp.millisecondsSinceEpoch}_${item.stage}";
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(item);
      }
    }
    _sleepHistory.clear();
    _sleepHistory.addAll(unique);
    _sleepHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _updateLatestFromHistory(
    List<Point> history,
    Function(int value, DateTime time) onUpdate,
  ) {
    if (history.isNotEmpty) {
      history.sort((a, b) => a.x.compareTo(b.x));

      if (_isSameDay(_selectedDate, DateTime.now())) {
        final last = history.last;
        onUpdate(
          last.y.toInt(),
          _dateFromMinutes(_selectedDate, last.x.toInt()),
        );
      } else {
        final int avg = _calculateAvg(history);
        // For average, time isn't "live", so maybe just use noon or last point time?
        // Let's use last point time for consistency in display if it shows "Last Updated..."
        onUpdate(avg, _dateFromMinutes(_selectedDate, history.last.x.toInt()));
      }
    } else {
      onUpdate(0, DateTime.now());
    }
  }

  void _clearMemory() {
    _hrHistory.clear();
    _spo2History.clear();
    _stressHistory.clear();
    _hrvHistory.clear();
    _stepsHistory.clear();
    // _sleepHistory.clear(); // Keep sleep history to allow browsing between days (0xBC returns multi-day)
    _steps = 0;
    _distance = 0;
    _calories = 0;

    _stress = 0;
    _hrv = 0;
    _spo2 = 0;
    _heartRate = 0;
  }

  DateTime _dateFromMinutes(DateTime date, int minutes) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: minutes));
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
      avgHrv: _calculateAvg(_hrvHistory),
      totalSleepMinutes: totalSleepMinutes,
      hrTrace: List.from(_hrHistory),
      stepsTrace: List.from(_stepsHistory),
      spo2Trace: List.from(_spo2History),
      stressTrace: List.from(_stressHistory),
      hrvTrace: List.from(_hrvHistory),
      sleepTrace: getSleepDataForDate(_selectedDate),
    );

    _storageService!.saveToday(data);
  }

  int _calculateAvg(List<Point> points) {
    // Filter out invalid/zero values first
    final validPoints = points.where((p) => p.y > 0).toList();
    if (validPoints.isEmpty) return 0;
    return (validPoints.fold<double>(0, (sum, p) => sum + p.y) /
            validPoints.length)
        .round();
  }

  // Filter sleep history for a specific date (Night of 'date')
  List<SleepData> getSleepDataForDate(DateTime date) {
    return _sleepHistory.where((s) => _isSleepDataForDate(s, date)).toList();
  }

  // Helper determining if a sleep record belongs to the "night" of [date]
  // Logic: Sleep Day ends at 18:00 (6 PM) of the target date.
  // So 'date' covers the period from [date-1 18:00] to [date 18:00].
  bool _isSleepDataForDate(SleepData s, DateTime date) {
    final timestamp = s.timestamp;

    // Define the window for "Sleep Day X":
    // Starts: Yesterday at 18:00:00.001
    // Ends: Today at 18:00:00.000
    final startOfSleepDay = DateTime(date.year, date.month, date.day - 1, 18);
    final endOfSleepDay = DateTime(date.year, date.month, date.day, 18);

    // Check if timestamp is strictly within this window
    // (We use likely inclusive start / exclusive end logic for clarity,
    // though minute-precision makes boundary hits rare)
    return timestamp.isAfter(startOfSleepDay) &&
        (timestamp.isBefore(endOfSleepDay) ||
            timestamp.isAtSameMomentAs(endOfSleepDay));
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

    final int calculatedSteps = _stepsHistory.fold<int>(
      0,
      (sum, p) => sum + p.y.toInt(),
    );

    _steps = max(_steps, calculatedSteps);

    if (_isSameDay(_selectedDate, DateTime.now())) {
      _realTimeSteps = max(_realTimeSteps, _steps);
    }

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
    debugPrint(message);
    // Explicitly print to console to ensure visibility in Flutter logs
    // debugPrint("RAW: $message");
  }

  @override
  void onHeartRate(int bpm) {
    if (bpm > 0) {
      if (_isSameDay(_selectedDate, DateTime.now())) {
        _heartRate = bpm;
        _lastHrTime = DateTime.now();
      }

      notifyListeners();
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

    if (steps > _realTimeSteps) {
      _realTimeSteps = steps;
    }

    if (_isSameDay(_selectedDate, DateTime.now())) {
      if (bpm > 0) _heartRate = bpm;

      if (steps > _steps) {
        _steps = steps;
        _lastStepsTime = DateTime.now();
        _updateDerivedMetrics();
        _persistUpdate();
      }
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

      // Remove existing point at same minute to prevent duplicates
      _hrHistory.removeWhere((p) => p.x == minutes);

      _hrHistory.add(Point(minutes, bpm));
      _hrHistory.sort((a, b) => a.x.compareTo(b.x));

      if (_isSameDay(_selectedDate, DateTime.now())) {
        if (_lastHrTime == null ||
            timestamp.isAfter(_lastHrTime!) ||
            timestamp.isAtSameMomentAs(_lastHrTime!)) {
          _heartRate = bpm;
          _lastHrTime = timestamp;
        }
      } else {
        _heartRate = _calculateAvg(_hrHistory);
      }

      _persistUpdate();
      notifyListeners();
    }
  }

  @override
  void onStepsHistoryPoint(DateTime timestamp, int steps, int quarterIndex) {
    if (_isSameDay(timestamp, _selectedDate)) {
      _stepsHistory.removeWhere((p) => p.x == quarterIndex);
      _stepsHistory.add(Point(quarterIndex, steps));

      final int calculatedSteps = _stepsHistory.fold<int>(
        0,
        (sum, p) => sum + p.y.toInt(),
      );

      _steps = max(_steps, calculatedSteps);

      if (_isSameDay(_selectedDate, DateTime.now())) {
        _realTimeSteps = max(_realTimeSteps, _steps);
      }

      _updateDerivedMetrics();
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

      if (_isSameDay(_selectedDate, DateTime.now())) {
        if (_lastSpo2Time == null ||
            timestamp.isAfter(_lastSpo2Time!) ||
            timestamp.isAtSameMomentAs(_lastSpo2Time!)) {
          _spo2 = percent;
          _lastSpo2Time = timestamp;
        }
      } else {
        _spo2 = _calculateAvg(_spo2History);
      }

      _persistUpdate();
      notifyListeners();
    }
  }

  @override
  void onStressHistoryPoint(DateTime timestamp, int level) {
    if (level > 0 && _isSameDay(timestamp, _selectedDate)) {
      final int minutes = timestamp.hour * 60 + timestamp.minute;

      // Remove existing point at same minute to prevent duplicates
      _stressHistory.removeWhere((p) => p.x == minutes);

      _stressHistory.add(Point(minutes, level));
      _stressHistory.sort((a, b) => a.x.compareTo(b.x));

      if (_isSameDay(_selectedDate, DateTime.now())) {
        if (_lastStressTime == null ||
            timestamp.isAfter(_lastStressTime!) ||
            timestamp.isAtSameMomentAs(_lastStressTime!)) {
          _stress = level;
          _lastStressTime = timestamp;
        }
      } else {
        _stress = _calculateAvg(_stressHistory);
      }

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

    if (_isSameDay(timestamp, _selectedDate)) {
      final int minutes = timestamp.hour * 60 + timestamp.minute;

      // Check if we need to add/update
      // Remove existing point at same minute to prevent duplicates
      _hrvHistory.removeWhere((p) => p.x == minutes);

      _hrvHistory.add(Point(minutes, val));
      _hrvHistory.sort((a, b) => a.x.compareTo(b.x));

      if (_isSameDay(_selectedDate, DateTime.now())) {
        if (_lastHrvTime == null ||
            timestamp.isAfter(_lastHrvTime!) ||
            timestamp.isAtSameMomentAs(_lastHrvTime!)) {
          _hrv = val;
          _lastHrvTime = timestamp;
        }
      } else {
        _hrv = _calculateAvg(_hrvHistory);
      }

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
    // Remove existing entry with same timestamp to avoid duplicates
    _sleepHistory.removeWhere((item) => item.timestamp == timestamp);

    // Store ALL sleep data (filtered only on retrieval)
    _sleepHistory.add(
      SleepData(
        timestamp: timestamp,
        stage: sleepStage,
        durationMinutes: durationMinutes,
      ),
    );
    _sleepHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _persistUpdate(); // Ensure we save the update
    notifyListeners();
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
  void onAutoConfigRead(String type, bool enabled, {int interval = 0}) {
    debugPrint(
      "AutoConfigRead: Type=$type Enabled=$enabled Interval=$interval",
    );
    if (type == "HR") {
      hrAutoEnabled = enabled;
      if (interval > 0) {
        hrInterval = interval;
      }
    } else if (type == "SpO2") {
      spo2AutoEnabled = enabled;
    } else if (type == "Stress") {
      stressAutoEnabled = enabled;
    } else if (type == "HRV") {
      hrvAutoEnabled = enabled;
    }
    notifyListeners();
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
