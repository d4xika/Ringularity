import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:ringularity/models/sleep_data_model.dart';
import 'package:ringularity/services/api/api_service.dart';
import 'package:ringularity/services/ble/ble_data_manager.dart';
import 'package:ringularity/services/ble/ble_logger.dart';
import 'package:ringularity/services/network_status_service.dart';
import 'package:ringularity/services/user/storage_service.dart';

/// Handles API-related data synchronization independently from the active Bluetooth connection.
///
/// Responsible for formatting local metrics and pushing them to the backend,
/// as well as pulling historical data from the cloud and injecting it into the [BleDataManager]
/// to power the UI charts. This architecture allows the app to display data without an active ring connection.
class BleApiSync extends ChangeNotifier {
  final ApiService _apiService;
  final BleLogger _logger;
  final NetworkStatusService _networkStatus;

  bool _isSyncing = false;

  /// Indicates if an upload or download process is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Creates a new [BleApiSync] instance.
  BleApiSync({
    ApiService? apiService,
    required BleLogger logger,
    required NetworkStatusService networkStatus,
  }) : _apiService = apiService ?? ApiService(),
       _logger = logger,
       _networkStatus = networkStatus;

  /// Downloads cloud data for the specified [date] and populates the [dataManager].
  /// Silently aborts if the device is currently offline.
  Future<void> downloadForDate({
    required DateTime date,
    required BleDataManager dataManager,
  }) async {
    if (!_networkStatus.isOnline) {
      debugPrint('BleApiSync.downloadForDate: offline, skipping.');
      _logger.setLastLog('Cloud DL Skipped (offline)');
      return;
    }
    _isSyncing = true;
    notifyListeners();
    try {
      await _performDownload(date, dataManager);
      _networkStatus.setOnline(true);
      _logger.setLastLog('Cloud DL Success');
    } catch (e) {
      debugPrint('Download Failed: $e');
      _logger.setLastLog('Cloud DL Err: $e');
      await _networkStatus.checkNow();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Uploads cached data from the [dataManager] for a given [date] to the cloud.
  /// Converts all local timestamps to UTC before transmission.
  Future<void> uploadForDate({
    required DateTime date,
    required BleDataManager dataManager,
  }) async {
    if (!_networkStatus.isOnline) {
      debugPrint('BleApiSync.uploadForDate: offline, skipping.');
      _logger.setLastLog('Cloud Upload Skipped (offline)');
      return;
    }
    _isSyncing = true;
    notifyListeners();
    try {
      await _performUpload(date, dataManager);
      _networkStatus.setOnline(true);
      _logger.setLastLog('Cloud Upload Success');
    } catch (e) {
      debugPrint(e.toString());
      _logger.setLastLog('Cloud Err: $e');
      await _networkStatus.checkNow();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Executes a full, bidirectional synchronization sequence (Upload, then Download).
  Future<bool> syncWithCloud({
    required DateTime date,
    required BleDataManager dataManager,
  }) async {
    if (!_networkStatus.isOnline) {
      debugPrint('BleApiSync.syncWithCloud: offline, skipping.');
      _logger.setLastLog('Cloud Sync Skipped (offline)');
      return false;
    }
    _isSyncing = true;
    notifyListeners();
    try {
      _logger.setLastLog('Cloud Syncing...');
      await _performUpload(date, dataManager);
      await _performDownload(date, dataManager);
      _networkStatus.setOnline(true);
      _logger.setLastLog('Cloud Sync Success');
      return true;
    } catch (e) {
      debugPrint('Sync Failed: $e');
      _logger.setLastLog('Cloud Sync Err: $e');
      await _networkStatus.checkNow();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Internal task pulling metrics from the [ApiService] and structuring them into Points for the UI.
  Future<void> _performDownload(
    DateTime date,
    BleDataManager dataManager,
  ) async {
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

    final stepsList = await _apiService.getSteps(date);
    final Map<int, Point> stepsMap = {};
    for (var item in stepsList) {
      final dt = DateTime.parse(item['recorded_at']).toLocal();
      if (_isSameDay(dt, date)) {
        final int minutes = dt.hour * 60 + dt.minute;
        final int quarter = minutes ~/ 15;
        // API logs are deltas per 15 mins. Overwrite duplicates instead of summing to prevent inflation.
        stepsMap[quarter] = Point(quarter, item['steps'] as int);
      }
    }
    dataManager.setStepsHistory(stepsMap.values.toList());

    final sleepList = await _apiService.getSleep(date);
    final Map<String, SleepData> sleepMap = {};
    for (var item in sleepList) {
      final dt = DateTime.parse(item['recorded_at']).toLocal();
      final key = "${dt.millisecondsSinceEpoch}_${item['sleep_stage']}";
      sleepMap[key] = SleepData(
        timestamp: dt,
        stage: item['sleep_stage'] as int,
        durationMinutes: item['duration_minutes'] as int,
      );
    }
    dataManager.setSleepHistory(sleepMap.values.toList());
  }

  /// Internal task parsing raw Points from [BleDataManager] into JSON lists and posting them to the [ApiService].
  Future<void> _performUpload(DateTime date, BleDataManager dataManager) async {
    final session = await StorageService.getUserSession();
    final String userId = session['user_id'].toString();

    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);

    final hrData = dataManager.hrHistory
        .map(
          (p) => {
            "recorded_at": _pointToTime(
              normalizedDate,
              p.x,
            ).toUtc().toIso8601String(),
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
            ).toUtc().toIso8601String(),
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
            ).toUtc().toIso8601String(),
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
        "recorded_at": time.toUtc().toIso8601String(),
        "steps": p.y.toInt(),
        "user_id": userId,
      };
    }).toList();
    await _apiService.saveSteps(stepsData);

    final sleepData = dataManager.sleepHistory
        .map(
          (s) => {
            "recorded_at": s.timestamp.toUtc().toIso8601String(),
            "sleep_stage": s.stage,
            "duration_minutes": s.durationMinutes,
            "user_id": userId,
          },
        )
        .toList();
    await _apiService.saveSleep(sleepData);
  }

  /// Converts a conceptual graph X-coordinate (representing minutes) back into a concrete timestamp.
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
