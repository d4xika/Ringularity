import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/models/sleep_data.dart';
import 'ble_data_processor.dart';
import 'ble_logger.dart';

/// Manages all the sensor data state (Current values, Histories).
/// Implements [BleDataCallbacks] to receive parsed data from the processor.
class BleDataManager extends ChangeNotifier implements BleDataCallbacks {
  final BleLogger logger;

  // Optional callbacks for controller logic
  Function(int)? onHeartRateReceivedCallback;
  Function(int)? onSpo2ReceivedCallback;
  Function(int)? onStressReceivedCallback;
  Function(int)? onHrvReceivedCallback;
  Function(int)? onNotificationCallback; // For sync logic

  BleDataManager({required this.logger});

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
    int hours = totalSleepMinutes ~/ 60;
    int minutes = totalSleepMinutes % 60;
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
    if (date == _selectedDate) return;
    _selectedDate = date;

    // Clear history for the new view (or load from DB in future)
    // For now, adhering to original behavior: clear memory
    _hrHistory.clear();
    _spo2History.clear();
    _stressHistory.clear();
    _hrvHistory.clear();
    _stepsHistory.clear();
    _sleepHistory.clear();
    _steps = 0;

    notifyListeners();
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
  void onSpo2(int percent) {
    if (percent > 0) {
      _spo2 = percent;
      _lastSpo2Time = DateTime.now();
      logger.setLastLog("SpO2 Success: $percent");

      onSpo2ReceivedCallback?.call(percent);

      // Live "Polyfill" to Graph
      final now = DateTime.now();
      if (_isSameDay(_selectedDate, now)) {
        int minutes = now.hour * 60 + now.minute;
        _spo2History.removeWhere((p) => p.x == minutes);
        _spo2History.add(Point(minutes, percent));
        _spo2History.sort((a, b) => a.x.compareTo(b.x));
      }
      notifyListeners();
    }
  }

  @override
  void onStress(int level) {
    if (level > 0) {
      _stress = level;
      _lastStressTime = DateTime.now();
      notifyListeners();
      onStressReceivedCallback?.call(level);
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
        int minutes = now.hour * 60 + now.minute;
        _hrvHistory.removeWhere((p) => p.x == minutes);
        _hrvHistory.add(Point(minutes, val));
        _hrvHistory.sort((a, b) => a.x.compareTo(b.x));
      }
      notifyListeners();
    }
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
    if (bpm > 0) {
      if (_lastHrTime == null || timestamp.isAfter(_lastHrTime!)) {
        _heartRate = bpm;
        _lastHrTime = timestamp;
      }
    }

    if (_isSameDay(timestamp, _selectedDate)) {
      int minutes = timestamp.hour * 60 + timestamp.minute;
      _hrHistory.add(Point(minutes, bpm));
      notifyListeners();
    }
  }

  @override
  void onSpo2HistoryPoint(DateTime timestamp, int percent) {
    if (percent > 0) {
      if (_lastSpo2Time == null || timestamp.isAfter(_lastSpo2Time!)) {
        _spo2 = percent;
        _lastSpo2Time = timestamp;
      }
    }
    if (_isSameDay(timestamp, _selectedDate)) {
      int minutes = timestamp.hour * 60 + timestamp.minute;
      _spo2History.removeWhere((p) => p.x == minutes);
      _spo2History.add(Point(minutes, percent));
      notifyListeners();
    }
  }

  @override
  void onStressHistoryPoint(DateTime timestamp, int level) {
    if (level > 0) {
      if (_lastStressTime == null || timestamp.isAfter(_lastStressTime!)) {
        _stress = level;
        _lastStressTime = timestamp;
      }
    }
    int minutes = timestamp.hour * 60 + timestamp.minute;
    _stressHistory.add(Point(minutes, level));
    notifyListeners();
  }

  @override
  void onStepsHistoryPoint(DateTime timestamp, int steps, int quarterIndex) {
    if (_isSameDay(timestamp, _selectedDate)) {
      _stepsHistory.removeWhere((p) => p.x == quarterIndex);
      _stepsHistory.add(Point(quarterIndex, steps));
      _steps = _stepsHistory.fold<int>(0, (sum, p) => sum + p.y.toInt());
      _lastStepsTime = DateTime.now();
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

    bool exists = _hrvHistory.any((p) {
      int minutes = timestamp.hour * 60 + timestamp.minute;
      return p.x == minutes && p.y == val;
    });
    if (!exists) {
      int minutes = timestamp.hour * 60 + timestamp.minute;
      _hrvHistory.add(Point(minutes, val));
      _hrvHistory.sort((a, b) => a.x.compareTo(b.x));
      notifyListeners();
    }
  }

  @override
  void onSleepHistoryPoint(DateTime timestamp, int sleepStage,
      {int durationMinutes = 0}) {
    // Remove existing entry with same timestamp to avoid duplicates
    _sleepHistory.removeWhere((item) => item.timestamp == timestamp);

    if (_isSameDay(timestamp, _selectedDate)) {
      _sleepHistory.add(SleepData(
        timestamp: timestamp,
        stage: sleepStage,
        durationMinutes: durationMinutes,
      ));
      _sleepHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
      int steps, int calories, int distance, int sport, int sleep) {
    debugPrint(
        "Goals: Steps=$steps Cals=$calories Dist=$distance Sport=$sport Sleep=$sleep");
  }

  @override
  void onMeasurementError(int type, int errorCode) {
    debugPrint("Measurement Error: Type=$type Code=$errorCode");
    logger.setLastLog("Error: T=$type C=$errorCode");
  }
}
