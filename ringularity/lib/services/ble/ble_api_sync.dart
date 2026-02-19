import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:ringularity/models/sleep_data.dart';
import 'package:ringularity/services/api/api_service.dart';
import 'package:ringularity/services/ble/ble_data_manager.dart';
import 'package:ringularity/services/ble/ble_logger.dart';
import 'package:ringularity/services/storage_service.dart';

/// Handles API-related data synchronization independent from Bluetooth.
/// - Downloads historical data for a given date and populates a provided BleDataManager
/// - Uploads locally stored data from a provided BleDataManager to the backend
///
/// This allows fetching data (e.g., from Splash Screen) without initializing BLE.
class BleApiSync extends ChangeNotifier {
  final ApiService _apiService;
  final BleLogger _logger;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  BleApiSync({ApiService? apiService, required BleLogger logger})
    : _apiService = apiService ?? ApiService(),
      _logger = logger;

  // ---- Public API ----

  /// Download cloud data for [date] and push into [dataManager].
  Future<void> downloadForDate({
    required DateTime date,
    required BleDataManager dataManager,
  }) async {
    _isSyncing = true;
    notifyListeners();
    try {
      await _performDownload(date, dataManager);
      _logger.setLastLog("Cloud DL Success");
    } catch (e) {
      debugPrint("Download Failed: $e");
      _logger.setLastLog("Cloud DL Err: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Upload data from [dataManager] for [date] to the cloud.
  /// Uses user_id for identification instead of device_id.
  Future<void> uploadForDate({
    required DateTime date,
    required BleDataManager dataManager,
  }) async {
    _isSyncing = true;
    notifyListeners();
    try {
      await _performUpload(date, dataManager);
      _logger.setLastLog("Cloud Sync Success");
    } catch (e) {
      debugPrint(e.toString());
      _logger.setLastLog("Cloud Err: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> syncWithCloud({
    required DateTime date,
    required BleDataManager dataManager,
  }) async {
    _isSyncing = true;
    notifyListeners();
    try {
      _logger.setLastLog("Cloud Syncing...");
      await _performUpload(date, dataManager);
      await _performDownload(date, dataManager);
      _logger.setLastLog("Cloud Sync Success");
      return true;
    } catch (e) {
      debugPrint("Sync Failed: $e");
      _logger.setLastLog("Cloud Sync Err: $e");
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _performDownload(
    DateTime date,
    BleDataManager dataManager,
  ) async {
    // Heart Rate
    final hrList = await _apiService.getHeartRate(date);
    final Map<int, Point> hrMap = {};
    for (var item in hrList) {
      final dt = DateTime.parse(item['recorded_at']).toLocal();
      if (_isSameDay(dt, date)) {
        final int minutes = dt.hour * 60 + dt.minute;
        hrMap[minutes] = Point(minutes, item['bpm'] as int);
      }
    }
    dataManager.setHrHistory(hrMap.values.toList());

    // Stress
    final stressList = await _apiService.getStress(date);
    final Map<int, Point> stressMap = {};
    for (var item in stressList) {
      final dt = DateTime.parse(item['recorded_at']).toLocal();
      if (_isSameDay(dt, date)) {
        final int minutes = dt.hour * 60 + dt.minute;
        stressMap[minutes] = Point(minutes, item['stress_level'] as int);
      }
    }
    dataManager.setStressHistory(stressMap.values.toList());

    // HRV
    final hrvList = await _apiService.getHrv(date);
    final Map<int, Point> hrvMap = {};
    for (var item in hrvList) {
      final dt = DateTime.parse(item['recorded_at']).toLocal();
      if (_isSameDay(dt, date)) {
        final int minutes = dt.hour * 60 + dt.minute;
        hrvMap[minutes] = Point(minutes, item['hrv_val'] as int);
      }
    }
    dataManager.setHrvHistory(hrvMap.values.toList());

    // Steps (aggregated by quarter hour as in original)
    final stepsList = await _apiService.getSteps(date);
    final Map<int, Point> stepsMap = {};
    for (var item in stepsList) {
      final dt = DateTime.parse(item['recorded_at']).toLocal();
      if (_isSameDay(dt, date)) {
        final int minutes = dt.hour * 60 + dt.minute;
        final int quarter = minutes ~/ 15;
        // Steps might be cumulative or delta?
        // Ring logs are deltas per 15 mins. API saves them as such.
        // If we have duplicates for the same quarter, it's likely the same sync payload uploaded twice.
        // So we should OVERWRITE (dedup), not sum.
        stepsMap[quarter] = Point(quarter, item['steps'] as int);
      }
    }
    dataManager.setStepsHistory(stepsMap.values.toList());

    // Sleep (do not strictly filter by date)
    final sleepList = await _apiService.getSleep(date);
    final Map<String, SleepData> sleepMap = {};
    for (var item in sleepList) {
      final dt = DateTime.parse(item['recorded_at']).toLocal();
      // Dedup key: Timestamp + Stage
      final key = "${dt.millisecondsSinceEpoch}_${item['sleep_stage']}";
      sleepMap[key] = SleepData(
        timestamp: dt,
        stage: item['sleep_stage'] as int,
        durationMinutes: item['duration_minutes'] as int,
      );
    }
    dataManager.setSleepHistory(sleepMap.values.toList());
  }

  Future<void> _performUpload(DateTime date, BleDataManager dataManager) async {
    final session = await StorageService.getUserSession();
    final String userId = session['user_id'].toString();

    // Fix: Normalize date to start of day (00:00:00) to ensure aligned timestamps
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);

    final hrData = dataManager.hrHistory
        .map(
          (p) => {
            "recorded_at": _pointToTime(
              normalizedDate,
              p.x,
            ).toUtc().toIso8601String(), // Fix: Send UTC
            "bpm": p.y.toInt(),
            "user_id": userId,
          },
        )
        .toList();
    await _apiService.saveHeartRate(hrData);

    final stressData = dataManager.stressHistory
        .map(
          (p) => {
            "recorded_at": _pointToTime(
              normalizedDate,
              p.x,
            ).toUtc().toIso8601String(), // Fix: Send UTC
            "stress_level": p.y.toInt(),
            "user_id": userId,
          },
        )
        .toList();
    await _apiService.saveStress(stressData);

    final hrvData = dataManager.hrvHistory
        .map(
          (p) => {
            "recorded_at": _pointToTime(
              normalizedDate,
              p.x,
            ).toUtc().toIso8601String(), // Fix: Send UTC
            "hrv_val": p.y.toInt(),
            "user_id": userId,
          },
        )
        .toList();
    await _apiService.saveHrv(hrvData);

    final stepsData = dataManager.stepsHistory.map((p) {
      final int totalMinutes = p.x.toInt() * 15;
      final time = normalizedDate.add(Duration(minutes: totalMinutes));
      return {
        "recorded_at": time.toUtc().toIso8601String(), // Fix: Send UTC
        "steps": p.y.toInt(),
        "user_id": userId,
      };
    }).toList();
    await _apiService.saveSteps(stepsData);

    final sleepData = dataManager.sleepHistory
        .map(
          (s) => {
            "recorded_at": s.timestamp
                .toUtc()
                .toIso8601String(), // Fix: Send UTC
            "sleep_stage": s.stage,
            "duration_minutes": s.durationMinutes,
            "user_id": userId,
          },
        )
        .toList();
    await _apiService.saveSleep(sleepData);
  }

  // ---- Helpers ----

  DateTime _pointToTime(DateTime baseDate, num x) {
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      x ~/ 60,
      x.toInt() % 60,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
