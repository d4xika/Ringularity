import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:ringularity/services/user/storage_service.dart';
import 'package:ringularity/models/sleep_data_model.dart';
import 'package:ringularity/services/notifications_service.dart';

import '../health/vitals_storage_service.dart';
import 'ble_data_processor.dart';
import 'ble_logger.dart';

/// The central state container and orchestrator for all health and sensor data.
///
/// Implements [BleDataCallbacks] to receive and store decoded payloads from the
/// [BleDataProcessor]. It maintains both the live "today" values and the historical
/// datasets needed for rendering graphs. It also triggers UI updates (`notifyListeners`)
/// and persists completed data to the [VitalsStorageService].
class BleDataManager extends AccountService implements BleDataCallbacks {
  final BleLogger logger;

  VitalsStorageService? _storageService;
  final Map<DateTime, DailyVitals> _days = {};
  final Map<DateTime, Map<String, Set<int>>> _ringSlots = {};
  final Set<int> _ringSleepMinutes = {};
  Future<void> _storageReady = Future.value();

  /// Copies source metadata so asynchronous uploads cannot observe later mutations.
  Map<String, Set<int>> _sourceSnapshot(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final sources = _ringSlots[day] ?? _days[day]?.ringSlots ?? {};
    final start =
        DateTime(day.year, day.month, day.day - 1, 18).millisecondsSinceEpoch ~/
        60000;
    final end =
        DateTime(day.year, day.month, day.day, 18).millisecondsSinceEpoch ~/
        60000;
    return {
      for (final entry in sources.entries)
        entry.key: Set<int>.from(entry.value),
      'sleep': _ringSleepMinutes
          .where((minute) => minute >= start && minute < end)
          .toSet(),
    };
  }

  /// Marks an actual ring sample, keeping cached cloud slots replaceable.
  void _markRingSlot(DateTime date, String metric, int index) {
    final day = DateTime(date.year, date.month, date.day);
    final sources = _ringSlots.putIfAbsent(day, () => _sourceSnapshot(day));
    sources.putIfAbsent(metric, () => {}).add(index);
  }

  /// Waits until disk records have been merged with measurements already received.
  Future<void> get storageReady => _storageReady;

  /// Dates retained locally, including ring data waiting for a cloud retry.
  Set<DateTime> get cachedDates => _days.keys.toSet();

  /// Returns an immutable snapshot for a date without changing the displayed day.
  DailyVitals vitalsForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (_isSameDay(day, _selectedDate)) {
      return _activeSnapshot();
    }
    return _days[day] ??
        _storageService?.getVitalsForDate(day) ??
        DailyVitals.empty(day);
  }

  /// Waits until all received measurements have reached the local cache.
  Future<void> flush() async {
    await _storageReady;
    await _storageService?.flush();
  }

  Function(int)? onHeartRateReceivedCallback;
  Function(int)? onStressReceivedCallback;
  Function(int)? onHrvReceivedCallback;
  Function(int)? onNotificationCallback;
  Function()? onActivityReceivedCallback;

  /// Creates a new [BleDataManager] instance.
  BleDataManager({required this.logger}) {
    bindAccount();
  }

  @override
  void resetAccount() {
    _days.clear();
    _ringSlots.clear();
    _ringSleepMinutes.clear();
    _hrHistory.clear();
    _stressHistory.clear();
    _hrvHistory.clear();
    _stepsHistory.clear();
    _sleepHistory.clear();
    _hrMeasurementBuffer.clear();
    _isManualHrMeasurement = false;
    _protectedManualMinute = null;
    _batteryLevel = _heartRate = _stress = _hrv = _steps = _realTimeSteps =
        _distance = 0;
    _lastHrTime = _lastStressTime = _lastHrvTime = _lastStepsTime = null;
    _lastStressWarningTime = _lastSleepWarningDate = null;
    _activitySteps = _activityDuration = 0;
    _goalSteps = 10000;
    _goalSleep = 8;
    _goalActivity = 30;
    hrAutoEnabled = stressAutoEnabled = hrvAutoEnabled = false;
    hrInterval = 5;
    _selectedDate = DateTime.now();
    _storageReady = Future.value();
  }

  @override
  Future<void> loadAccount() async {
    final owner = StorageService.requireSession();
    await Future<void>.delayed(Duration.zero);
    if (!owner.isCurrent) {
      return;
    }
    final service = _storageService;
    if (service != null) {
      setStorageService(service);
      await _storageReady;
    }
  }

  /// Injects the local storage service used for caching historical vitals.
  void setStorageService(VitalsStorageService service) {
    _storageService = service;
    final owner = StorageService.currentSession;
    if (owner == null) {
      return;
    }
    _storageReady = service.ready.then((_) async {
      if (!owner.isCurrent) {
        return;
      }
      final retained = [...service.weeklyData, ...service.initialData];
      for (final day in retained) {
        mergeCloudData(day);
      }
      _saveDay(_activeSnapshot());
      for (final day in List<DailyVitals>.from(_days.values)) {
        if (!owner.isCurrent) {
          return;
        }
        await service.saveToday(day);
      }
      await service.flush();
    });
  }

  int _batteryLevel = 0;

  /// The current battery percentage of the connected ring (0-100).
  int get batteryLevel => _batteryLevel;

  int _heartRate = 0;
  DateTime? _lastHrTime;

  /// The most recent valid heart rate measurement (bpm).
  int get heartRate => _heartRate;

  /// The formatted timestamp of the last valid heart rate measurement.
  String get heartRateTime => _formatTime(_lastHrTime);

  int _stress = 0;
  DateTime? _lastStressTime;
  int get stress => _stress;
  String get stressTime => _formatTime(_lastStressTime);
  DateTime? _lastStressWarningTime;

  int _hrv = 0;
  DateTime? _lastHrvTime;
  int get hrv => _hrv;
  int get avgHrv => _calculateAvg(_hrvHistory);
  String get hrvTime => _formatTime(_lastHrvTime);

  int _steps = 0;
  DateTime? _lastStepsTime;
  int get steps => _steps;
  String get stepsTime => _formatTime(_lastStepsTime, isDaily: true);

  DateTime? _lastSleepWarningDate;

  int _realTimeSteps = 0;

  /// The highest step count observed today, independent of historical caching.
  int get realTimeSteps => _realTimeSteps;

  int _distance = 0;

  /// The calculated total distance covered today, in meters.
  int get distance => _distance;

  final int _activeMinutes = 0;
  int get activeMinutes => _activeMinutes;

  int _goalSteps = 10000;
  double _goalSleep = 8.0;
  int _goalActivity = 30;

  int get goalSteps => _goalSteps;
  double get goalSleep => _goalSleep;
  int get goalActivity => _goalActivity;

  /// Updates the daily targets for Steps, Sleep, and Activity Minutes.
  void setGoals({int? steps, double? sleep, int? activity}) {
    if (steps != null) _goalSteps = steps;
    if (sleep != null) _goalSleep = sleep;
    if (activity != null) _goalActivity = activity;
    notifyListeners();
  }

  final List<Point> _hrHistory = [];
  final List<Point> _stressHistory = [];
  final List<Point> _hrvHistory = [];
  final List<Point> _stepsHistory = [];
  final List<SleepData> _sleepHistory = [];

  final List<int> _hrMeasurementBuffer = [];
  bool _isManualHrMeasurement = false;
  int? _protectedManualMinute;

  List<Point> get hrHistory => List.unmodifiable(_hrHistory);
  List<Point> get stressHistory => List.unmodifiable(_stressHistory);
  List<Point> get hrvHistory => List.unmodifiable(_hrvHistory);
  List<Point> get stepsHistory => List.unmodifiable(_stepsHistory);
  List<SleepData> get sleepHistory => List.unmodifiable(_sleepHistory);

  /// Calculates the total duration of restful sleep (excluding awake times) for the selected date.
  int get totalSleepMinutes =>
      getSleepDataForDate(_selectedDate).fold(0, (sum, item) {
        if (item.stage == 0x02 || item.stage == 0x03 || item.stage == 0x04) {
          return sum + item.durationMinutes;
        }
        return sum;
      });

  /// Returns the total sleep duration formatted as "Xh YYmin".
  String get totalSleepTimeFormatted {
    if (totalSleepMinutes == 0) return "0h 00min";
    final int hours = totalSleepMinutes ~/ 60;
    final int minutes = totalSleepMinutes % 60;
    return "${hours}h ${minutes.toString().padLeft(2, '0')}min";
  }

  final StreamController<List<int>> _accelStreamController =
      StreamController<List<int>>.broadcast();
  Stream<List<int>> get accelStream => _accelStreamController.stream;

  final StreamController<List<int>> _ppgStreamController =
      StreamController<List<int>>.broadcast();
  Stream<List<int>> get ppgStream => _ppgStreamController.stream;

  DateTime _selectedDate = DateTime.now();

  /// The calendar date currently driving the UI and data queries.
  DateTime get selectedDate => _selectedDate;

  /// Changes the active context date, flushes volatile memory, and attempts to load cached historical data.
  void setSelectedDate(DateTime date) async {
    if (_isSameDay(date, _selectedDate)) return;

    _persistUpdate();

    _selectedDate = date;
    _clearMemory();
    _protectedManualMinute = null;

    final cached =
        _days[DateTime(date.year, date.month, date.day)] ??
        _storageService?.getVitalsForDate(date);

    if (cached != null) {
      _loadFromCachedObject(cached);
    } else {
      debugPrint("No Cache for $date found, waiting for API...");
    }

    notifyListeners();
  }

  /// Internal task bridging a cached [DailyVitals] object into active memory.
  void _loadFromCachedObject(DailyVitals cached) {
    _hrHistory.addAll(cached.hrTrace);
    _stepsHistory.addAll(cached.stepsTrace);
    _stressHistory.addAll(cached.stressTrace);
    _hrvHistory.addAll(cached.hrvTrace);

    final sleep = _mergeSleepTraces(
      _sleepHistory,
      cached.sleepTrace,
      protected: _ringSleepMinutes,
    );
    _ringSleepMinutes.addAll(cached.ringSlots['sleep'] ?? {});
    _ringSlots[DateTime(
      cached.date.year,
      cached.date.month,
      cached.date.day,
    )] = {
      for (final entry in cached.ringSlots.entries)
        entry.key: Set<int>.from(entry.value),
    };
    _sleepHistory.clear();
    _sleepHistory.addAll(sleep);

    _steps = cached.steps;
    _distance = cached.distance;

    _updateLatestFromHistory(_stressHistory, (v, t) => _stress = v);
    _updateLatestFromHistory(_hrvHistory, (v, t) => _hrv = v);
    _updateLatestFromHistory(_hrHistory, (v, t) => _heartRate = v);

    _hrHistory.removeWhere((p) => p.y <= 0);
    _stressHistory.removeWhere((p) => p.y <= 0);
    _hrvHistory.removeWhere((p) => p.y <= 0);

    _updateDerivedMetrics();
  }

  /// Reassembles overlapping sleep data chunks (often received across multiple syncs) into a clean, contiguous timeline.
  void _deleteduplicateSleepHistory() {
    final merged = _mergeSleepTraces(_sleepHistory, []);
    _sleepHistory.clear();
    _sleepHistory.addAll(merged);
  }

  /// Combines sleep stages minute by minute, keeping preferred ring stages on overlap.
  List<SleepData> _mergeSleepTraces(
    List<SleepData> preferred,
    List<SleepData> incoming, {
    Set<int>? protected,
  }) {
    final stages = <int, int>{};
    void add(List<SleepData> data, {required bool overwrite}) {
      for (final item in data) {
        final start = item.timestamp.millisecondsSinceEpoch ~/ 60000;
        for (var i = 0; i < item.durationMinutes; i++) {
          final minute = start + i;
          if (overwrite ||
              protected == null ||
              protected.contains(minute) ||
              !stages.containsKey(minute)) {
            stages[minute] = item.stage;
          }
        }
      }
    }

    add(incoming, overwrite: true);
    add(preferred, overwrite: false);
    final minutes = stages.keys.toList()..sort();
    final result = <SleepData>[];
    var index = 0;
    while (index < minutes.length) {
      final start = minutes[index];
      final stage = stages[start]!;
      var end = index + 1;
      while (end < minutes.length &&
          minutes[end] == minutes[end - 1] + 1 &&
          stages[minutes[end]] == stage) {
        end++;
      }
      result.add(
        SleepData(
          timestamp: DateTime.fromMillisecondsSinceEpoch(start * 60000),
          stage: stage,
          durationMinutes: end - index,
        ),
      );
      index = end;
    }
    return result;
  }

  /// Refreshes cloud-derived slots while protecting samples originating from the ring.
  List<Point> _mergePoints(
    List<Point> local,
    List<Point> cloud, {
    bool steps = false,
    Set<int>? protected,
  }) {
    final points = <num, Point>{
      for (final p in cloud)
        if (p.y > 0) p.x: p,
    };
    for (final p in local) {
      if (p.y > 0) {
        final other = points[p.x];
        if (steps && other != null) {
          points[p.x] = Point(p.x, max(p.y, other.y));
        } else if (other == null ||
            protected == null ||
            protected.contains(p.x.toInt())) {
          points[p.x] = p;
        }
      }
    }
    return points.values.toList()..sort((a, b) => a.x.compareTo(b.x));
  }

  /// Merges a dated cloud response without relying on the user's current selection.
  void mergeCloudData(DailyVitals incoming) {
    final local = vitalsForDate(incoming.date);
    final hr = _mergePoints(
      local.hrTrace,
      incoming.hrTrace,
      protected: local.ringSlots['hr'] ?? {},
    );
    final stress = _mergePoints(
      local.stressTrace,
      incoming.stressTrace,
      protected: local.ringSlots['stress'] ?? {},
    );
    final hrv = _mergePoints(
      local.hrvTrace,
      incoming.hrvTrace,
      protected: local.ringSlots['hrv'] ?? {},
    );
    final steps = _mergePoints(
      local.stepsTrace,
      incoming.stepsTrace,
      steps: true,
    );
    final sleep = _mergeSleepTraces(
      _sleepHistory,
      incoming.sleepTrace,
      protected: _ringSleepMinutes,
    );
    _ringSleepMinutes.addAll(incoming.ringSlots['sleep'] ?? {});
    final day = DateTime(
      incoming.date.year,
      incoming.date.month,
      incoming.date.day,
    );
    _ringSlots[day] = {
      for (final metric in {
        ...local.ringSlots.keys,
        ...incoming.ringSlots.keys,
      })
        metric: {...?local.ringSlots[metric], ...?incoming.ringSlots[metric]},
    };
    _sleepHistory.clear();
    _sleepHistory.addAll(sleep);
    final count = max(
      max(local.steps, incoming.steps),
      steps.fold<int>(0, (sum, p) => sum + p.y.toInt()),
    );
    final merged = DailyVitals(
      date: DateTime(
        incoming.date.year,
        incoming.date.month,
        incoming.date.day,
      ),
      ringSlots: _sourceSnapshot(incoming.date),
      steps: count,
      distance: max(
        max(local.distance, incoming.distance),
        (count * 0.762).toInt(),
      ),
      avgHr: _calculateAvg(hr),
      avgStress: _calculateAvg(stress),
      avgHrv: _calculateAvg(hrv),
      totalSleepMinutes: _calculateSleepMinutesForDate(incoming.date),
      hrTrace: hr,
      stressTrace: stress,
      hrvTrace: hrv,
      stepsTrace: steps,
      sleepTrace: getSleepDataForDate(incoming.date),
    );
    _saveDay(merged);
    if (_isSameDay(incoming.date, _selectedDate)) {
      _clearMemory();
      _loadFromCachedObject(merged);
    }
    notifyListeners();
  }

  /// Records history for an off-screen date instead of discarding its samples.
  void _recordHistoricalPoint(DateTime date, String metric, Point point) {
    final local = vitalsForDate(date);
    List<Point> replace(List<Point> data) =>
        [...data.where((p) => p.x != point.x), point]
          ..sort((a, b) => a.x.compareTo(b.x));
    final hr = metric == 'hr' ? replace(local.hrTrace) : local.hrTrace;
    final stress = metric == 'stress'
        ? replace(local.stressTrace)
        : local.stressTrace;
    final hrv = metric == 'hrv' ? replace(local.hrvTrace) : local.hrvTrace;
    final steps = metric == 'steps'
        ? replace(local.stepsTrace)
        : local.stepsTrace;
    final count = max(
      local.steps,
      steps.fold<int>(0, (sum, p) => sum + p.y.toInt()),
    );
    _saveDay(
      DailyVitals(
        date: DateTime(date.year, date.month, date.day),
        ringSlots: _sourceSnapshot(date),
        steps: count,
        distance: max(local.distance, (count * 0.762).toInt()),
        avgHr: _calculateAvg(hr),
        avgStress: _calculateAvg(stress),
        avgHrv: _calculateAvg(hrv),
        totalSleepMinutes: local.totalSleepMinutes,
        hrTrace: hr,
        stressTrace: stress,
        hrvTrace: hrv,
        stepsTrace: steps,
        sleepTrace: local.sleepTrace,
      ),
    );
    notifyListeners();
  }

  /// Retains a daily snapshot in memory and queues its durable disk write.
  void _saveDay(DailyVitals day) {
    _days[DateTime(day.date.year, day.date.month, day.date.day)] = day;
    final cutoff = DateTime.now();
    final limit = DateTime(cutoff.year, cutoff.month, cutoff.day - 7);
    _days.removeWhere((date, _) => date.isBefore(limit));
    _ringSlots.removeWhere((date, _) => date.isBefore(limit));
    final sleepLimit =
        DateTime(
          cutoff.year,
          cutoff.month,
          cutoff.day - 8,
        ).millisecondsSinceEpoch ~/
        60000;
    _ringSleepMinutes.removeWhere((minute) => minute < sleepLimit);
    _storageService?.saveToday(day).catchError((Object error) {
      logger.setLastLog('Local cache error: $error');
    });
  }

  /// Captures the displayed day before an asynchronous operation can change its context.
  DailyVitals _activeSnapshot() => DailyVitals(
    date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
    ringSlots: _sourceSnapshot(_selectedDate),
    steps: _steps,
    distance: _distance,
    avgHr: _calculateAvg(_hrHistory),
    avgStress: _calculateAvg(_stressHistory),
    avgHrv: _calculateAvg(_hrvHistory),
    totalSleepMinutes: totalSleepMinutes,
    hrTrace: List.from(_hrHistory),
    stepsTrace: List.from(_stepsHistory),
    stressTrace: List.from(_stressHistory),
    hrvTrace: List.from(_hrvHistory),
    sleepTrace: getSleepDataForDate(_selectedDate),
  );

  /// Extracts the most recent valid point from a history trace to display as the "live" value.
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
        onUpdate(avg, _dateFromMinutes(_selectedDate, history.last.x.toInt()));
      }
    } else {
      onUpdate(0, DateTime.now());
    }
  }

  /// Wipes all currently loaded high-resolution graph data from RAM.
  void _clearMemory() {
    _hrHistory.clear();
    _stressHistory.clear();
    _hrvHistory.clear();
    _stepsHistory.clear();
    _pruneSleepHistory();

    _steps = 0;
    _distance = 0;

    _stress = 0;
    _hrv = 0;
    _heartRate = 0;
  }

  /// Prevents the sleep history buffer from causing a memory leak by purging data older than 14 days.
  void _pruneSleepHistory() {
    if (_sleepHistory.isEmpty) return;
    final now = DateTime.now();
    final limit = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 14));
    _sleepHistory.removeWhere((s) => s.timestamp.isBefore(limit));
  }

  DateTime _dateFromMinutes(DateTime date, int minutes) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: minutes));
  }

  /// Compiles the current state into a [DailyVitals] block and commits it to local storage.
  /// Also triggers push notifications if critical thresholds (e.g., high stress) are breached.
  void _persistUpdate() {
    final int currentAvgStress = _calculateAvg(_stressHistory);

    if (currentAvgStress >= 50 && _isSameDay(_selectedDate, DateTime.now())) {
      final now = DateTime.now();
      if (_lastStressWarningTime == null ||
          now.difference(_lastStressWarningTime!).inHours >= 3) {
        debugPrint("📢 Stress avg high ($currentAvgStress), send warning!");
        NotificationService.showStressWarning(currentAvgStress);
        _lastStressWarningTime = now;
      }
    }

    _saveDay(_activeSnapshot());
  }

  int _calculateAvg(List<Point> points) {
    final validPoints = points.where((p) => p.y > 0).toList();
    if (validPoints.isEmpty) return 0;
    return (validPoints.fold<double>(0, (sum, p) => sum + p.y) /
            validPoints.length)
        .round();
  }

  /// Clips sleep stages to the selected night's 18:00-to-18:00 window.
  ///
  /// A stage crossing the boundary contributes only its overlapping minutes,
  /// rather than being lost or counted in full on two separate dates.
  List<SleepData> getSleepDataForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day - 1, 18);
    final end = DateTime(date.year, date.month, date.day, 18);
    final result = <SleepData>[];
    for (final stage in _sleepHistory) {
      final stageEnd = stage.timestamp.add(
        Duration(minutes: stage.durationMinutes),
      );
      final overlapStart = stage.timestamp.isBefore(start)
          ? start
          : stage.timestamp;
      final overlapEnd = stageEnd.isAfter(end) ? end : stageEnd;
      if (overlapEnd.isAfter(overlapStart)) {
        result.add(
          SleepData(
            timestamp: overlapStart,
            stage: stage.stage,
            durationMinutes: overlapEnd.difference(overlapStart).inMinutes,
          ),
        );
      }
    }
    return result;
  }

  /// Merges a batch of Heart Rate data into the active history buffer,
  /// ensuring it does not overwrite precise data already provided by the ring.
  void setHrHistory(List<Point> data) {
    final merged = _mergePoints(
      _hrHistory,
      data,
      protected: _sourceSnapshot(_selectedDate)['hr'] ?? {},
    );
    _hrHistory.clear();
    _hrHistory.addAll(merged);
    _updateLatestFromHistory(_hrHistory, (v, t) => _heartRate = v);
    _persistUpdate();
    notifyListeners();
  }

  /// Adds cloud stress slots while preserving measurements received from the ring.
  void setStressHistory(List<Point> data) {
    final merged = _mergePoints(
      _stressHistory,
      data,
      protected: _sourceSnapshot(_selectedDate)['stress'] ?? {},
    );
    _stressHistory.clear();
    _stressHistory.addAll(merged);
    _updateLatestFromHistory(_stressHistory, (v, t) => _stress = v);
    _persistUpdate();
    notifyListeners();
  }

  /// Adds cloud HRV slots while preserving measurements received from the ring.
  void setHrvHistory(List<Point> data) {
    final merged = _mergePoints(
      _hrvHistory,
      data,
      protected: _sourceSnapshot(_selectedDate)['hrv'] ?? {},
    );
    _hrvHistory.clear();
    _hrvHistory.addAll(merged);
    _updateLatestFromHistory(_hrvHistory, (v, t) => _hrv = v);
    _persistUpdate();
    notifyListeners();
  }

  /// Merges step buckets by quarter-hour without counting repeated syncs twice.
  void setStepsHistory(List<Point> data) {
    final merged = _mergePoints(_stepsHistory, data, steps: true);
    _stepsHistory.clear();
    _stepsHistory.addAll(merged);
    _steps = max(
      _steps,
      _stepsHistory.fold<int>(0, (sum, p) => sum + p.y.toInt()),
    );
    if (_isSameDay(_selectedDate, DateTime.now())) {
      _realTimeSteps = max(_realTimeSteps, _steps);
    }
    _updateDerivedMetrics();
    _persistUpdate();
    notifyListeners();
  }

  /// Fills gaps in recorded sleep without overwriting locally received stages.
  void setSleepHistory(List<SleepData> data) {
    final merged = _mergeSleepTraces(
      _sleepHistory,
      data,
      protected: _ringSleepMinutes,
    );
    _sleepHistory.clear();
    _sleepHistory.addAll(merged);
    onSleepSyncComplete();
    final now = DateTime.now();
    if (totalSleepMinutes > 0 &&
        totalSleepMinutes < 360 &&
        (_lastSleepWarningDate == null ||
            !_isSameDay(_lastSleepWarningDate!, now))) {
      NotificationService.showSleepWarning(totalSleepMinutes);
      _lastSleepWarningDate = now;
    }
  }

  @override
  void dispose() {
    _accelStreamController.close();
    _ppgStreamController.close();
    super.dispose();
  }

  /// Engages an internal buffer to record high-frequency heart rate data.
  void startManualHrMeasurement() {
    _hrMeasurementBuffer.clear();
    _isManualHrMeasurement = true;
  }

  /// Calculates the median value from a manual measurement buffer to discard noisy outliers,
  /// locking that minute so the background sync does not overwrite it.
  void stopManualHrMeasurement() {
    _isManualHrMeasurement = false;
    if (_hrMeasurementBuffer.isEmpty) return;

    final sorted = List<int>.from(_hrMeasurementBuffer)..sort();
    final mid = sorted.length ~/ 2;
    final int median = sorted.length.isOdd
        ? sorted[mid]
        : ((sorted[mid - 1] + sorted[mid]) / 2).round();

    _hrMeasurementBuffer.clear();

    final now = DateTime.now();
    if (median > 0 && _isSameDay(_selectedDate, now)) {
      final int minutes = now.hour * 60 + now.minute;
      _hrHistory.removeWhere((p) => p.x == minutes);
      _hrHistory.add(Point(minutes, median));
      _hrHistory.sort((a, b) => a.x.compareTo(b.x));
      _heartRate = median;
      _lastHrTime = now;

      _markRingSlot(now, 'hr', minutes);
      _protectedManualMinute = minutes;
      _persistUpdate();
      notifyListeners();
    }
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
  }

  @override
  void onHeartRate(int bpm) {
    if (bpm <= 0) return;

    if (_isManualHrMeasurement) {
      _hrMeasurementBuffer.add(bpm);
      _heartRate = bpm;
      notifyListeners();
      onHeartRateReceivedCallback?.call(bpm);
      return;
    }

    if (_isSameDay(_selectedDate, DateTime.now())) {
      _heartRate = bpm;
      _lastHrTime = DateTime.now();
    }

    notifyListeners();
    onHeartRateReceivedCallback?.call(bpm);
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
        _markRingSlot(now, 'hrv', minutes);
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
        _markRingSlot(now, 'stress', minutes);
        _stressHistory.removeWhere((p) => p.x == minutes);
        _stressHistory.add(Point(minutes, level));

        _persistUpdate();
      }

      notifyListeners();
      onStressReceivedCallback?.call(level);
    }
  }

  @override
  void onActivityUpdate({
    required int steps,
    required int bpm,
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

    if (level > 0 && level <= 30) {
      NotificationService.showBatteryWarning(level);
    }
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
    if (bpm < 30 || bpm > 220) {
      return;
    }
    _markRingSlot(timestamp, 'hr', timestamp.hour * 60 + timestamp.minute);
    if (!_isSameDay(timestamp, _selectedDate)) {
      _recordHistoricalPoint(
        timestamp,
        'hr',
        Point(timestamp.hour * 60 + timestamp.minute, bpm),
      );
      return;
    }
    if (bpm > 0 && _isSameDay(timestamp, _selectedDate)) {
      final int minutes = timestamp.hour * 60 + timestamp.minute;

      if (minutes == _protectedManualMinute) return;

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
    _markRingSlot(timestamp, 'steps', quarterIndex);
    if (!_isSameDay(timestamp, _selectedDate)) {
      _recordHistoricalPoint(timestamp, 'steps', Point(quarterIndex, steps));
      return;
    }
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
  void onStressHistoryPoint(DateTime timestamp, int level) {
    if (level <= 0) {
      return;
    }
    _markRingSlot(timestamp, 'stress', timestamp.hour * 60 + timestamp.minute);
    if (!_isSameDay(timestamp, _selectedDate)) {
      _recordHistoricalPoint(
        timestamp,
        'stress',
        Point(timestamp.hour * 60 + timestamp.minute, level),
      );
      return;
    }
    if (level > 0 && _isSameDay(timestamp, _selectedDate)) {
      final int minutes = timestamp.hour * 60 + timestamp.minute;

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
    if (val <= 0) {
      return;
    }
    _markRingSlot(timestamp, 'hrv', timestamp.hour * 60 + timestamp.minute);
    if (!_isSameDay(timestamp, _selectedDate)) {
      _recordHistoricalPoint(
        timestamp,
        'hrv',
        Point(timestamp.hour * 60 + timestamp.minute, val),
      );
      return;
    }
    if (val > 0) {
      if (_lastHrvTime == null || timestamp.isAfter(_lastHrvTime!)) {
        _hrv = val;
        _lastHrvTime = timestamp;
      }
    }

    if (_isSameDay(timestamp, _selectedDate)) {
      final int minutes = timestamp.hour * 60 + timestamp.minute;

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
    final firstMinute = timestamp.millisecondsSinceEpoch ~/ 60000;
    _ringSleepMinutes.addAll(
      List.generate(durationMinutes, (index) => firstMinute + index),
    );
    _sleepHistory.add(
      SleepData(
        timestamp: timestamp,
        stage: sleepStage,
        durationMinutes: durationMinutes,
      ),
    );
  }

  @override
  void onSleepSyncComplete() {
    _deleteduplicateSleepHistory();

    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      _persistSpecificDate(date);
    }

    notifyListeners();
  }

  void _persistSpecificDate(DateTime date) {
    if (_isSameDay(date, _selectedDate)) {
      _persistUpdate();
      return;
    }

    final existing = vitalsForDate(date);
    final sleepTrace = getSleepDataForDate(date);
    final updated = DailyVitals(
      date: existing.date,
      ringSlots: _sourceSnapshot(date),
      steps: existing.steps,
      distance: existing.distance,
      avgHr: existing.avgHr,
      avgStress: existing.avgStress,
      avgHrv: existing.avgHrv,
      totalSleepMinutes: _calculateSleepMinutesForDate(date),
      hrTrace: existing.hrTrace,
      stepsTrace: existing.stepsTrace,
      stressTrace: existing.stressTrace,
      hrvTrace: existing.hrvTrace,
      sleepTrace: sleepTrace,
    );
    _saveDay(updated);
  }

  int _calculateSleepMinutesForDate(DateTime date) {
    return getSleepDataForDate(date).fold(0, (sum, item) {
      if (item.stage == 0x02 || item.stage == 0x03 || item.stage == 0x04) {
        return sum + item.durationMinutes;
      }
      return sum;
    });
  }

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
    } else if (type == "Stress") {
      stressAutoEnabled = enabled;
    } else if (type == "HRV") {
      hrvAutoEnabled = enabled;
    }
    notifyListeners();
  }

  bool hrAutoEnabled = false;
  int hrInterval = 5;
  bool stressAutoEnabled = false;
  bool hrvAutoEnabled = false;

  /// Updates the local toggles representing the hardware's automated measurement settings.
  void updateAutoConfig(String type, bool enabled) {
    if (type == "HR") {
      hrAutoEnabled = enabled;
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
  void onGoalsRead(int steps, int distance, int sport, int sleep) {
    debugPrint(
      "Goals (Targets/Total): Steps=$steps Dist=$distance Sport=$sport Sleep=$sleep",
    );
  }

  void _updateDerivedMetrics() {
    _distance = (_steps * 0.762).toInt();
    notifyListeners();
  }

  @override
  void onMeasurementError(int type, int errorCode) {
    debugPrint("Measurement Error: Type=$type Code=$errorCode");
    logger.setLastLog("Error: T=$type C=$errorCode");
  }

  int _activitySteps = 0;
  int _activityDuration = 0;

  int get activitySteps => _activitySteps;
  int get activityDuration => _activityDuration;

  @override
  void onActivityPacketReceived() {
    onActivityReceivedCallback?.call();
  }

  /// Clears volatile activity states before a new workout session begins.
  void resetActivityStats() {
    _activitySteps = 0;
    _activityDuration = 0;
    notifyListeners();
  }
}
