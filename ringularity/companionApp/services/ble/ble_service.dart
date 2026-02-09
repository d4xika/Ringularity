import 'dart:async';
import 'dart:io';
import 'dart:math'; // For Point

import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // For BluetoothDevice types
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'packet_factory.dart';

import 'ble_data_processor.dart';
import 'package:flutter_application_1/models/sleep_data.dart';
// New Components
import 'ble_logger.dart';
import 'ble_scanner.dart';
import 'ble_sensor_controller.dart';
import 'ble_connection_manager.dart';
import 'ble_data_manager.dart';
import 'package:flutter_application_1/services/api/api_service.dart';

import 'package:flutter/widgets.dart'; // For WidgetsBindingObserver

/// The central service that coordinates Bluetooth actions.
/// Now refactored to delegate logic to [BleConnectionManager] and [BleDataManager].
/// This class acts as a Facade, providing a simplified interface to the UI.
class BleService extends ChangeNotifier with WidgetsBindingObserver {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;

  BleService._internal() {
    _logger = BleLogger();
    _scanner = BleScanner();

    // Initialize Data Manager
    _dataManager = BleDataManager(logger: _logger);

    // Initialize Processor (feeds data into DataManager)
    _processor = BleDataProcessor(_dataManager);

    // Initialize Connection Manager
    _connectionManager = BleConnectionManager(
      logger: _logger,
      onDataReceived: (data) async {
        await _processor.processData(data);
      },
    );

    // Initialize Sensor Controller
    _sensorController = BleSensorController(logger: _logger);

    // Wire up listeners
    _scanner.addListener(notifyListeners); // Scan results update
    _logger.addListener(notifyListeners); // Log updates
    _sensorController.addListener(
        notifyListeners); // Controller overrides (e.g. measuring state)

    // Propagate changes from managers
    _connectionManager.addListener(notifyListeners);
    _dataManager.addListener(notifyListeners);

    // Wire up DataManager -> SensorController callbacks
    _dataManager.onHeartRateReceivedCallback =
        _sensorController.onHeartRateReceived;
    _dataManager.onSpo2ReceivedCallback = _sensorController.onSpo2Received;
    _dataManager.onStressReceivedCallback = _sensorController.onStressReceived;
    _dataManager.onHrvReceivedCallback = _sensorController.onHrvReceived;
    _dataManager.onNotificationCallback =
        _onNotificationReceived; // Handle sync triggers

    WidgetsBinding.instance.addObserver(this);
  }

  // --- Components ---
  // Responsible for logging BLE protocol events
  late final BleLogger _logger;
  // Responsible for scanning for devices
  late final BleScanner _scanner;
  // Responsible for sending sensor control commands (start/stop measurement)
  late final BleSensorController _sensorController;
  // Responsible for managing the BLE connection lifecycle (connect, disconnect, auto-reconnect)
  late final BleConnectionManager _connectionManager;
  // Responsible for storing and notifying about received sensor data
  late final BleDataManager _dataManager;
  // Responsible for parsing raw bytes into meaningful data and updating DataManager
  late final BleDataProcessor _processor;

  final ApiService _apiService = ApiService();
  ApiService get apiService => _apiService;

  // --- Facade: Expose properties for UI ---

  // Logger
  List<String> get protocolLog => _logger.protocolLog;
  String get lastLog => _logger.lastLog;
  void addToProtocolLog(String message, {bool isTx = false}) =>
      _logger.addToProtocolLog(message, isTx: isTx);

  // Scanner
  bool get isScanning => _scanner.isScanning;
  List<ScanResult> get scanResults => _scanner.scanResults;
  List<BluetoothDevice> get bondedDevices => _scanner.bondedDevices;
  Future<void> startScan() => _scanner.startScan();
  Future<void> stopScan() => _scanner.stopScan();
  Future<void> loadBondedDevices() => _scanner.loadBondedDevices();

  // Connection
  String get status => _connectionManager.status;
  bool get isConnected => _connectionManager.isConnected;
  String? get currentDeviceId => _connectionManager.currentDeviceId;

  // Sensor Status
  bool get isMeasuringHeartRate => _sensorController.isMeasuringHeartRate;
  bool get isMeasuringSpo2 => _sensorController.isMeasuringSpo2;
  bool get isMeasuringStress => _sensorController.isMeasuringStress;
  bool get isMeasuringHrv => _sensorController.isMeasuringHrv;
  bool get isMeasuringRawPPG => _sensorController.isMeasuringRawPPG;

  // Data (Delegated to DataManager)
  int get batteryLevel => _dataManager.batteryLevel;
  int get heartRate => _dataManager.heartRate;
  String get heartRateTime => _dataManager.heartRateTime;
  int get spo2 => _dataManager.spo2;
  String get spo2Time => _dataManager.spo2Time;
  int get stress => _dataManager.stress;
  String get stressTime => _dataManager.stressTime;
  int get hrv => _dataManager.hrv;
  String get hrvTime => _dataManager.hrvTime;
  int get steps => _dataManager.steps;
  String get stepsTime => _dataManager.stepsTime;

  List<Point> get hrHistory => _dataManager.hrHistory;
  List<Point> get spo2History => _dataManager.spo2History;
  List<Point> get stressHistory => _dataManager.stressHistory;
  List<Point> get hrvHistory => _dataManager.hrvHistory;
  List<Point> get stepsHistory => _dataManager.stepsHistory;
  List<SleepData> get sleepHistory => _dataManager.sleepHistory;

  String get totalSleepTimeFormatted => _dataManager.totalSleepTimeFormatted;

  // Streams
  Stream<List<int>> get accelStream => _dataManager.accelStream;
  Stream<List<int>> get ppgStream => _dataManager.ppgStream;

  // Config Delegate
  DateTime get selectedDate => _dataManager.selectedDate;
  void setSelectedDate(DateTime date) => _dataManager.setSelectedDate(date);

  // Auto Config (Now mirrored in DataManager for display, but Service manages logic?
  // Actually Service logic sets it. DataManager just holds 'enabled' variables for UI).
  bool get hrAutoEnabled => _dataManager.hrAutoEnabled;
  int get hrInterval => _dataManager.hrInterval;
  bool get spo2AutoEnabled => _dataManager.spo2AutoEnabled;
  bool get stressAutoEnabled => _dataManager.stressAutoEnabled;
  bool get hrvAutoEnabled => _dataManager.hrvAutoEnabled;

  // --- Smart Sync State ---
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  Timer? _periodicSyncTimer;
  final Duration _syncInterval = const Duration(minutes: 60);
  final Duration _minSyncDelay = const Duration(minutes: 15);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicSyncTimer?.cancel();
    _scanner.removeListener(_checkAutoConnect);
    _connectionManager.dispose();
    _dataManager.dispose();
    _logger.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("App Resumed - Checking Smart Sync...");
      triggerSmartSync();
    }
  }

  /// Initializes the service, requesting necessary permissions and setting up listeners.
  Future<void> init() async {
    // Check permissions
    if (Platform.isAndroid) {
      await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
    }
    // Load bonded devices
    await _scanner.loadBondedDevices();

    // Load last device ID for auto-reconnect
    await _connectionManager.loadLastDeviceId();

    // Listen for scan results using the combined check
    _scanner.addListener(_checkAutoConnect);

    // Attempt immediate connection if device is already bonded
    _checkAutoConnect();
  }

  // Logic to check if we should automatically connect to a known device.
  void _checkAutoConnect() {
    // Delegate check to scanner and connection manager state
    // Don't auto-connect if already connected or connecting, or if we don't have a last known device.
    if (_connectionManager.isConnected ||
        _connectionManager.status.startsWith("Connecting") ||
        _connectionManager.lastDeviceId == null) {
      return;
    }

    BluetoothDevice? target;

    // 1. Check Bonded Devices (already paired at system level)
    try {
      target = _scanner.bondedDevices.firstWhere(
        (d) => d.remoteId.str == _connectionManager.lastDeviceId,
      );
      debugPrint("Auto-Connect: Found in Bonded Devices");
    } catch (_) {}

    // 2. Check Scan Results (devices currently advertising)
    if (target == null) {
      try {
        final match = _scanner.scanResults.firstWhere(
          (r) => r.device.remoteId.str == _connectionManager.lastDeviceId,
        );
        target = match.device;
        debugPrint("Auto-Connect: Found in Scan Results");
        stopScan(); // handled by scanner
      } catch (_) {}
    }

    if (target != null) {
      debugPrint("Triggering Auto-Connect to: ${target.remoteId.str}");
      connectToDevice(target);
    }
  }

  // Helper to connect to a specific device and initialize the session.
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // Connect
      await _connectionManager.connectToDevice(device);

      // Wire up Controller for sending commands
      _sensorController.sendCommand = _connectionManager.sendData;

      // Start Logic
      await startPairing(); // Initial Handshake sequence

      // Restore Settings
      await syncSettingsToRing();

      _startPeriodicSyncTimer();
      triggerSmartSync();
    } catch (e) {
      // Error handled in manager, but we might want to ensure cleanup here if needed
    }
  }

  Future<void> disconnect() async {
    await _connectionManager.disconnect();
    _stopPeriodicSyncTimer();
    _sensorController.sendCommand = null;
  }

  // --- Sync Logic (Coordinator) ---

  void _onNotificationReceived(int type) {
    // Protocol callback from DataManager
    if (type == 0x01) {
      syncHeartRateHistory();
    } else if (type == 0x03 || type == 0x2C) {
      // Chain syncs
      Future.delayed(Duration.zero, () async {
        await syncHeartRateHistory();
        await Future.delayed(const Duration(milliseconds: 500));
        await syncSpo2History();
        await Future.delayed(const Duration(milliseconds: 500));
        await syncStressHistory();
      });
    }
  }

  /// Triggers a "smart sync" which only syncs if enough time has passed since the last sync.
  Future<void> triggerSmartSync({bool force = false}) async {
    if (!isConnected) return;
    final now = DateTime.now();
    if (!force && _lastSyncTime != null) {
      final elapsed = now.difference(_lastSyncTime!);
      if (elapsed < _minSyncDelay) {
        debugPrint("Smart Sync Throttled");
        return;
      }
    }
    await startFullSyncSequence();
    _lastSyncTime = DateTime.now();
  }

  Future<void> syncAllData() async {
    await triggerSmartSync(force: true);
  }

  void _startPeriodicSyncTimer() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(_syncInterval, (timer) {
      triggerSmartSync();
    });
  }

  void _stopPeriodicSyncTimer() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  // --- API Sync Logic ---
  // Logic to download historical data from the API and allow the user to view it.

  Future<void> downloadFromCloud() async {
    if (_connectionManager.lastDeviceId == null) {
      return;
    }
    _isSyncing = true;
    notifyListeners();
    try {
      final date = _dataManager.selectedDate;
      String deviceId = _connectionManager.lastDeviceId!;

      // Fetch and Populate DataManager
      // 1. Heart Rate
      final hrList = await _apiService.getHeartRate(deviceId, date);
      List<Point> hrPoints = [];
      for (var item in hrList) {
        final dt = DateTime.parse(item['recorded_at']);
        if (_isSameDay(dt, date)) {
          hrPoints.add(Point(dt.hour * 60 + dt.minute, item['bpm'] as int));
        }
      }
      _dataManager.setHrHistory(hrPoints);

      // ... (Repeating pattern for other sensors, keeping logic similar to before)
      // For brevity in refactor, mapping explicitly

      final spo2List = await _apiService.getSpo2(deviceId, date);
      List<Point> spo2Points = [];
      for (var item in spo2List) {
        final dt = DateTime.parse(item['recorded_at']);
        if (_isSameDay(dt, date)) {
          spo2Points.add(
              Point(dt.hour * 60 + dt.minute, item['spo2_percent'] as int));
        }
      }
      _dataManager.setSpo2History(spo2Points);

      final stressList = await _apiService.getStress(deviceId, date);
      List<Point> stressPoints = [];
      for (var item in stressList) {
        final dt = DateTime.parse(item['recorded_at']);
        if (_isSameDay(dt, date)) {
          stressPoints.add(
              Point(dt.hour * 60 + dt.minute, item['stress_level'] as int));
        }
      }
      _dataManager.setStressHistory(stressPoints);

      final hrvList = await _apiService.getHrv(deviceId, date);
      List<Point> hrvPoints = [];
      for (var item in hrvList) {
        final dt = DateTime.parse(item['recorded_at']);
        if (_isSameDay(dt, date)) {
          hrvPoints
              .add(Point(dt.hour * 60 + dt.minute, item['hrv_val'] as int));
        }
      }
      _dataManager.setHrvHistory(hrvPoints);

      final stepsList = await _apiService.getSteps(deviceId, date);
      List<Point> stepsPoints = [];
      for (var item in stepsList) {
        final dt = DateTime.parse(item['recorded_at']);
        if (_isSameDay(dt, date)) {
          int minutes = dt.hour * 60 + dt.minute;
          int quarter = minutes ~/ 15;
          stepsPoints.add(Point(quarter, item['steps'] as int));
        }
      }
      _dataManager.setStepsHistory(stepsPoints);

      final sleepList = await _apiService.getSleep(deviceId, date);
      List<SleepData> sleepData = [];
      for (var item in sleepList) {
        final dt = DateTime.parse(item['recorded_at']);
        // Sleep doesn't strict check date usually
        sleepData.add(SleepData(
            timestamp: dt,
            stage: item['sleep_stage'] as int,
            durationMinutes: item['duration_minutes'] as int));
      }
      _dataManager.setSleepHistory(sleepData);

      _logger.setLastLog("Cloud DL Success");
    } catch (e) {
      debugPrint("Download Failed: $e");
      _logger.setLastLog("Cloud DL Err: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Logic to upload local data to the API.
  Future<void> syncToCloud() async {
    _isSyncing = true;
    notifyListeners();
    try {
      // Map DataManager data to JSON
      final date = _dataManager.selectedDate;
      String deviceId = _connectionManager.lastDeviceId ?? "unknown";

      final hrData = _dataManager.hrHistory
          .map((p) => {
                "recorded_at": _pointToTime(date, p.x).toIso8601String(),
                "bpm": p.y.toInt(),
                "device_id": deviceId
              })
          .toList();
      await _apiService.saveHeartRate(hrData);

      // ... (Repeat for others)
      final spo2Data = _dataManager.spo2History
          .map((p) => {
                "recorded_at": _pointToTime(date, p.x).toIso8601String(),
                "spo2_percent": p.y.toInt(),
                "device_id": deviceId
              })
          .toList();
      await _apiService.saveSpo2(spo2Data);

      final stressData = _dataManager.stressHistory
          .map((p) => {
                "recorded_at": _pointToTime(date, p.x).toIso8601String(),
                "stress_level": p.y.toInt(),
                "device_id": deviceId
              })
          .toList();
      await _apiService.saveStress(stressData);

      final hrvData = _dataManager.hrvHistory
          .map((p) => {
                "recorded_at": _pointToTime(date, p.x).toIso8601String(),
                "hrv_val": p.y.toInt(),
                "device_id": deviceId
              })
          .toList();
      await _apiService.saveHrv(hrvData);

      final stepsData = _dataManager.stepsHistory.map((p) {
        int totalMinutes = p.x.toInt() * 15;
        final time = date.add(Duration(minutes: totalMinutes));
        return {
          "recorded_at": time.toIso8601String(),
          "steps": p.y.toInt(),
          "device_id": deviceId
        };
      }).toList();
      await _apiService.saveSteps(stepsData);

      final sleepData = _dataManager.sleepHistory
          .map((s) => {
                "recorded_at": s.timestamp.toIso8601String(),
                "sleep_stage": s.stage,
                "duration_minutes": s.durationMinutes,
                "device_id": deviceId
              })
          .toList();
      await _apiService.saveSleep(sleepData);

      _logger.setLastLog("Cloud Sync Success");
    } catch (e) {
      debugPrint(e.toString());
      _logger.setLastLog("Cloud Err: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  DateTime _pointToTime(DateTime baseDate, num x) {
    return DateTime(
        baseDate.year, baseDate.month, baseDate.day, x ~/ 60, x.toInt() % 60);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // --- Commands (Delegated to ConnectionManager or constructed here) ---

  Future<void> startPairing() async {
    // Initial commands sequence
    addToProtocolLog("TX: 04 ... (Set Name)", isTx: true);
    await _connectionManager.sendData(PacketFactory.createSetPhoneNamePacket());
    await Future.delayed(const Duration(milliseconds: 200));

    addToProtocolLog("TX: 01 ... (Set Time)", isTx: true);
    await _connectionManager.sendData(PacketFactory.createSetTimePacket());
    await Future.delayed(const Duration(milliseconds: 200));

    // ...
    addToProtocolLog("TX: Battery", isTx: true);
    await getBatteryLevel();
  }

  Future<void> syncTime() => normalizeTime();

  Future<void> normalizeTime() async {
    await _connectionManager.sendData(PacketFactory.createSetTimePacket());
  }

  // Specific Sync Commands
  Future<void> startFullSyncSequence() async {
    if (!isConnected) return;
    _isSyncing = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final difference = now.difference(selectedDate).inDays;
      int offset = difference < 0 ? 0 : difference;

      await _connectionManager
          .sendData(PacketFactory.getStepsPacket(dayOffset: offset));
      await Future.delayed(const Duration(seconds: 2));
      await syncHeartRateHistory();
      await Future.delayed(const Duration(seconds: 2));
      await syncSpo2History();
      await Future.delayed(const Duration(seconds: 4));
      await syncStressHistory();
      await Future.delayed(const Duration(seconds: 2));
      await syncHrvHistory();
      await Future.delayed(const Duration(seconds: 2));
      await syncSleepHistory();
      _logger.setLastLog("Full Sync Completed");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncHeartRateHistory() async {
    final startOfDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    await _connectionManager
        .sendData(PacketFactory.getHeartRateLogPacket(startOfDay));
  }

  Future<void> syncSpo2History() async =>
      await _connectionManager.sendData(PacketFactory.getSpo2LogPacketNew());
  Future<void> syncStressHistory() async =>
      await _connectionManager.sendData(PacketFactory.getStressHistoryPacket());
  Future<void> syncHrvHistory() async =>
      await _connectionManager.sendData(PacketFactory.getHrvLogPacket());

  Future<void> syncSleepHistory() async {
    // Logic copied from original (Bind, Set Name, etc... sequence before Sleep Request)
    // This seems complex, usually managed by packet factory or just direct sends
    // For brevity, calling the requests directly as in original flow logic
    // But using _connectionManager.sendData
    try {
      // ... (bind requests reuse)
      await _connectionManager.sendData(PacketFactory.createBindRequest());
      await Future.delayed(const Duration(milliseconds: 300));
      // ...
      if (_connectionManager.hasV2Service) {
        await _connectionManager
            .sendDataV2(PacketFactory.createSleepRequestPacket());
      } else {
        await _connectionManager
            .sendData(PacketFactory.createSleepRequestPacket());
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> getBatteryLevel() async =>
      await _connectionManager.sendData(PacketFactory.getBatteryPacket());

  // Auto Settings
  Future<void> setAutoHrInterval(int minutes) async {
    _dataManager.updateAutoConfig("HR", minutes > 0);
    if (minutes > 0)
      _dataManager.hrInterval =
          minutes; // Should expose setter or update method

    int enabledVal = minutes > 0 ? 0x01 : 0x00;
    int intervalVal = minutes > 0 ? minutes : 0;
    await _connectionManager.sendData(PacketFactory.createPacket(
        command: 0x16, data: [0x02, enabledVal, intervalVal]));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hrInterval', minutes);
  }

  Future<void> setAutoSpo2(bool enabled) async {
    _dataManager.updateAutoConfig("SpO2", enabled);
    await _connectionManager.sendData(PacketFactory.createPacket(
        command: 0x2C, data: [0x02, enabled ? 1 : 0]));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('spo2Enabled', enabled);
  }

  Future<void> setAutoStress(bool enabled) async {
    _dataManager.updateAutoConfig("Stress", enabled);
    await _connectionManager.sendData(PacketFactory.createPacket(
        command: 0x36, data: [0x02, enabled ? 1 : 0]));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('stressEnabled', enabled);
  }

  Future<void> setAutoHrv(bool enabled) async {
    _dataManager.updateAutoConfig("HRV", enabled);
    await _connectionManager.sendData(PacketFactory.createPacket(
        command: 0x38, data: [0x02, enabled ? 1 : 0]));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hrvEnabled', enabled);
  }

  Future<void> syncSettingsToRing() async {
    await normalizeTime();
    final prefs = await SharedPreferences.getInstance();
    int? hr = prefs.getInt('hrInterval');
    if (hr != null) await setAutoHrInterval(hr);
    bool? spo2 = prefs.getBool('spo2Enabled');
    if (spo2 != null) await setAutoSpo2(spo2);
    bool? stress = prefs.getBool('stressEnabled');
    if (stress != null) await setAutoStress(stress);
    bool? hrv = prefs.getBool('hrvEnabled');
    if (hrv != null) await setAutoHrv(hrv);
  }

  // Wrappers
  Future<void> setHeartRateMonitoring(bool enabled) =>
      setAutoHrInterval(enabled ? 5 : 0);
  Future<void> setSpo2Monitoring(bool enabled) => setAutoSpo2(enabled);
  Future<void> setStressMonitoring(bool enabled) => setAutoStress(enabled);

  Future<void> factoryReset() async => await _connectionManager
      .sendData(PacketFactory.createPacket(command: 0xFF, data: [0x66, 0x66]));
  Future<void> rebootRing() async => await _connectionManager
      .sendData(PacketFactory.createPacket(command: 0x08, data: [0x05]));
  Future<void> sendRawPacket(List<int> packet) async =>
      await _connectionManager.sendData(packet);

  Future<void> enableRawData() async =>
      await _connectionManager.sendData(PacketFactory.enableRawDataPacket());
  Future<void> disableRawData() async =>
      await _connectionManager.sendData(PacketFactory.disableRawDataPacket());

  Future<void> unpairRing() async {
    await _scanner.loadBondedDevices();
    if (_connectionManager.connectedDevice != null) {
      try {
        await _connectionManager.connectedDevice!.removeBond();
      } catch (e) {}
    }
  }

  // --- Aliases for compatibility ---
  Future<void> startRealTimeHeartRate() => startHeartRate();
  Future<void> stopRealTimeHeartRate() => stopHeartRate();
  Future<void> startRealTimeSpo2() => startSpo2();
  Future<void> stopRealTimeSpo2() => stopSpo2();

  // Sensor Commands (Delegate to Controller)
  Future<void> startHeartRate() async {
    if (_sensorController.isMeasuringSpo2) await _sensorController.stopSpo2();
    await _sensorController.startHeartRate();
  }

  Future<void> stopHeartRate() => _sensorController.stopHeartRate();
  Future<void> startSpo2() async {
    if (_sensorController.isMeasuringHeartRate)
      await _sensorController.stopHeartRate();
    await _sensorController.startSpo2();
  }

  Future<void> stopSpo2() => _sensorController.stopSpo2();
  Future<void> startRawPPG() => _sensorController.startRawPPG();
  Future<void> stopRawPPG() => _sensorController.stopRawPPG();
  Future<void> startStressTest() async {
    if (_sensorController.isMeasuringHeartRate)
      await _sensorController.stopHeartRate();
    await _sensorController.startStressTest();
  }

  Future<void> stopStressTest() => _sensorController.stopStressTest();
  Future<void> startRealTimeHrv() => _sensorController.startRealTimeHrv();
  Future<void> stopRealTimeHrv() => _sensorController.stopRealTimeHrv();

  Future<void> readAutoSettings() async {
    if (!_connectionManager.isConnected) return;
    await _connectionManager.sendData([0x16, 0x01]);
    await Future.delayed(const Duration(milliseconds: 300));
    await _connectionManager.sendData([0x2C, 0x01]);
    await Future.delayed(const Duration(milliseconds: 300));
    await _connectionManager.sendData([0x36, 0x01]);
    await Future.delayed(const Duration(milliseconds: 300));
    await _connectionManager.sendData([0x38, 0x01]);
  }

  Future<void> findDevice() async {
    if (!_connectionManager.isConnected) return;
    await _connectionManager.sendData(PacketFactory.createFindDevicePacket());
  }

  Future<void> syncStepsHistory() async {
    if (!_connectionManager.isConnected) return;
    final now = DateTime.now();
    final difference = now.difference(selectedDate).inDays;
    int offset = difference < 0 ? 0 : difference;
    await _connectionManager
        .sendData(PacketFactory.getStepsPacket(dayOffset: offset));
  }

  Future<void> forceStopEverything() async {
    try {
      await disableRawData();
      if (_sensorController.isMeasuringHeartRate)
        await _sensorController.stopHeartRate();
      if (_sensorController.isMeasuringSpo2) await _sensorController.stopSpo2();
      if (_sensorController.isMeasuringStress)
        await _sensorController.stopStressTest();
      if (_sensorController.isMeasuringHrv)
        await _sensorController.stopRealTimeHrv();
      if (_sensorController.isMeasuringRawPPG)
        await _sensorController.stopRawPPG();

      await _connectionManager.sendData(PacketFactory.disableHeartRate());
      await _connectionManager.sendData(PacketFactory.disableSpo2());
    } catch (e) {
      debugPrint("Error force stopping: $e");
    }
  }
}
