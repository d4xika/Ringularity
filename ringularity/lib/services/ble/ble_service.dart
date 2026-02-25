import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ringularity/models/activity_model.dart';
import 'package:ringularity/models/sleep_data_model.dart';
import 'package:ringularity/services/health/vitals_storage_service.dart';
import 'package:ringularity/services/network_status_service.dart';
import 'package:ringularity/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_api_sync.dart';
import 'ble_connection_manager.dart';
import 'ble_data_manager.dart';
import 'ble_data_processor.dart';
import 'ble_logger.dart';
import 'ble_scanner.dart';
import 'ble_sensor_controller.dart';
import 'packet_factory.dart';

/// The central Facade service orchestrating all BLE interactions and state.
///
/// Designed as a Singleton, it simplifies access for the UI layer by delegating
/// specific domains (Scanning, Connecting, Processing, Logging) to dedicated sub-managers.
/// Also handles application lifecycle events to trigger "Smart Syncs" when the app opens.
class BleService extends ChangeNotifier with WidgetsBindingObserver {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  /// Exposes the physical state of the phone's Bluetooth chip (On, Off, Unauthorized).
  BluetoothAdapterState get adapterState => _adapterState;

  static final BleService _instance = BleService._internal();

  /// Returns the singleton instance of the [BleService].
  factory BleService() => _instance;

  BleService._internal() {
    _logger = BleLogger();
    _scanner = BleScanner();
    _networkStatus = NetworkStatusService();
    _apiSync = BleApiSync(logger: _logger, networkStatus: _networkStatus);

    _dataManager = BleDataManager(logger: _logger);

    _processor = BleDataProcessor(_dataManager);

    _connectionManager = BleConnectionManager(
      logger: _logger,
      onDataReceived: (data) async {
        await _processor.processData(data);
      },
    );

    _sensorController = BleSensorController(logger: _logger);

    _scanner.addListener(notifyListeners);
    _logger.addListener(notifyListeners);
    _sensorController.addListener(notifyListeners);

    _connectionManager.addListener(notifyListeners);
    _dataManager.addListener(notifyListeners);

    _dataManager.onHeartRateReceivedCallback =
        _sensorController.onHeartRateReceived;
    _dataManager.onSpo2ReceivedCallback = _sensorController.onSpo2Received;
    _dataManager.onStressReceivedCallback = _sensorController.onStressReceived;
    _dataManager.onHrvReceivedCallback = _sensorController.onHrvReceived;
    _dataManager.onNotificationCallback = _onNotificationReceived;
    _dataManager.onActivityReceivedCallback = _checkForRunawayActivity;

    WidgetsBinding.instance.addObserver(this);
  }

  late final BleLogger _logger;
  late final BleScanner _scanner;
  late final BleSensorController _sensorController;
  late final BleConnectionManager _connectionManager;
  late final BleDataManager _dataManager;
  late final BleDataProcessor _processor;
  late BleApiSync _apiSync;
  late NetworkStatusService _networkStatus;

  /// Replaces the temporary network status tracker with the global one from the Provider tree.
  void initNetworkStatus(NetworkStatusService networkStatus) {
    _networkStatus = networkStatus;
    _apiSync = BleApiSync(logger: _logger, networkStatus: _networkStatus);
  }

  // --- Facade: Expose properties for UI ---

  List<String> get protocolLog => _logger.protocolLog;
  String get lastLog => _logger.lastLog;
  void addToProtocolLog(String message, {bool isTx = false}) =>
      _logger.addToProtocolLog(message, isTx: isTx);

  bool get isScanning => _scanner.isScanning;
  List<ScanResult> get scanResults => _scanner.scanResults;
  List<BluetoothDevice> get bondedDevices => _scanner.bondedDevices;
  Future<void> startScan() => _scanner.startScan();
  Future<void> stopScan() => _scanner.stopScan();
  Future<void> loadBondedDevices() => _scanner.loadBondedDevices();

  String get status => _connectionManager.status;
  bool get isConnected => _connectionManager.isConnected;
  bool get isConnecting => _connectionManager.isConnecting;
  String? get currentDeviceId => _connectionManager.currentDeviceId;
  String? get currentDeviceName => _connectionManager.currentDeviceName;
  String? get lastKnownId => _connectionManager.lastDeviceId;

  bool get isMeasuringHeartRate => _sensorController.isMeasuringHeartRate;
  bool get isMeasuringSpo2 => _sensorController.isMeasuringSpo2;
  bool get isMeasuringStress => _sensorController.isMeasuringStress;
  bool get isMeasuringHrv => _sensorController.isMeasuringHrv;
  bool get isMeasuringRawPPG => _sensorController.isMeasuringRawPPG;

  BleDataManager get dataManager => _dataManager;
  int get batteryLevel => _dataManager.batteryLevel;
  int get heartRate => _dataManager.heartRate;
  String get heartRateTime => _dataManager.heartRateTime;
  int get spo2 => _dataManager.spo2;
  String get spo2Time => _dataManager.spo2Time;
  int get stress => _dataManager.stress;
  String get stressTime => _dataManager.stressTime;
  int get hrv => _dataManager.hrv;
  int get avgHrv => _dataManager.avgHrv;
  String get hrvTime => _dataManager.hrvTime;
  int get steps => _dataManager.steps;
  int get realTimeSteps => _dataManager.realTimeSteps;
  String get stepsTime => _dataManager.stepsTime;
  int get distance => _dataManager.distance;
  int get calories => _dataManager.calories;
  int get activeMinutes => _dataManager.activeMinutes;
  int get totalSleepMinutes => _dataManager.totalSleepMinutes;

  int get goalSteps => _dataManager.goalSteps;
  double get goalSleep => _dataManager.goalSleep;
  int get goalActivity => _dataManager.goalActivity;

  /// Loads locally cached user fitness goals into the data manager.
  Future<void> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final int steps = prefs.getInt('targetSteps') ?? 10000;
    final double sleep = prefs.getDouble('targetSleep') ?? 8.0;
    final int activity = prefs.getInt('targetActivity') ?? 30;
    _dataManager.setGoals(steps: steps, sleep: sleep, activity: activity);
  }

  /// Persists new fitness goals locally and applies them to the current session.
  Future<void> updateGoals(int steps, double sleep, int activity) async {
    _dataManager.setGoals(steps: steps, sleep: sleep, activity: activity);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('targetSteps', steps);
    await prefs.setDouble('targetSleep', sleep);
    await prefs.setInt('targetActivity', activity);
  }

  int get activitySteps => _dataManager.activitySteps;
  int get activityDuration => _dataManager.activityDuration;

  List<Point> get hrHistory => _dataManager.hrHistory;
  List<Point> get spo2History => _dataManager.spo2History;
  List<Point> get stressHistory => _dataManager.stressHistory;
  List<Point> get hrvHistory => _dataManager.hrvHistory;
  List<Point> get stepsHistory => _dataManager.stepsHistory;
  List<SleepData> get sleepHistory => _dataManager.sleepHistory;
  List<SleepData> getSleepDataForDate(DateTime date) =>
      _dataManager.getSleepDataForDate(date);

  String get totalSleepTimeFormatted => _dataManager.totalSleepTimeFormatted;

  Stream<List<int>> get accelStream => _dataManager.accelStream;
  Stream<List<int>> get ppgStream => _dataManager.ppgStream;

  DateTime get selectedDate => _dataManager.selectedDate;

  /// Requests the underlying data manager to swap context to a new date, triggering API downloads if necessary.
  void setSelectedDate(DateTime date) async {
    _dataManager.setSelectedDate(date);

    if (!DateUtils.isSameDay(date, DateTime.now())) {
      await _apiSync.downloadForDate(date: date, dataManager: _dataManager);
    }
  }

  bool get hrAutoEnabled => _dataManager.hrAutoEnabled;
  int get hrInterval => _dataManager.hrInterval;
  bool get spo2AutoEnabled => _dataManager.spo2AutoEnabled;
  bool get stressAutoEnabled => _dataManager.stressAutoEnabled;
  bool get hrvAutoEnabled => _dataManager.hrvAutoEnabled;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  Timer? _periodicSyncTimer;
  final Duration _syncInterval = const Duration(minutes: 60);
  final Duration _minSyncDelay = const Duration(minutes: 15);

  bool _isActivitySessionActive = false;
  bool get isActivitySessionActive => _isActivitySessionActive;

  DateTime? _lastRunawayStopTimestamp;

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
      debugPrint(
        "App Resumed - Checking Smart Sync... Connected: $isConnected",
      );

      if (isConnected) {
        getBatteryLevel();
      }

      if (!isConnected) {
        _scanner.loadBondedDevices(notify: false).then((_) {
          _checkAutoConnect();
        });
      }

      triggerSmartSync();
    }
  }

  /// Bootstraps the BLE architecture by requesting OS permissions and configuring baseline tracking logic.
  Future<void> init() async {
    _dataManager.onActivityReceivedCallback = _checkForRunawayActivity;

    if (Platform.isAndroid) {
      await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.notification,
      ].request();
    }

    FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      notifyListeners();
      debugPrint("Bluetooth Adapter State: $state");
    });

    await _scanner.loadBondedDevices();
    await _connectionManager.loadLastDeviceId();
    await loadGoals();

    _scanner.removeListener(_checkAutoConnect);
    _scanner.addListener(_checkAutoConnect);

    _checkAutoConnect();
  }

  /// Wires the  storage engine directly into the fast-moving memory manager.
  void initVitalsStorage(VitalsStorageService storage) {
    _dataManager.setStorageService(storage);
    debugPrint("BleService: VitalsStorageService connected with DataManager.");
  }

  bool _isAutoConnecting = false;
  DateTime? _lastAutoConnectAttempt;
  final Duration _autoConnectCooldown = const Duration(seconds: 30);

  /// Evaluates whether the system should silently attempt to reconnect to the most recent ring.
  void _checkAutoConnect() {
    if (_connectionManager.isConnected ||
        _connectionManager.status.startsWith("Connecting") ||
        _isAutoConnecting) {
      return;
    }

    if (_lastAutoConnectAttempt != null &&
        DateTime.now().difference(_lastAutoConnectAttempt!) <
            _autoConnectCooldown) {
      return;
    }

    if (_connectionManager.lastDeviceId == null) {
      return;
    }

    final String targetId = _connectionManager.lastDeviceId!;

    BluetoothDevice? target;

    try {
      target = _scanner.bondedDevices.firstWhere(
        (d) => d.remoteId.toString() == targetId,
      );
    } catch (_) {}

    if (target == null) {
      try {
        final match = _scanner.scanResults.firstWhere(
          (r) => r.device.remoteId.toString() == targetId,
        );
        target = match.device;

        if (isScanning) {
          stopScan();
        }
      } catch (_) {}
    }

    if (target != null) {
      _isAutoConnecting = true;
      _lastAutoConnectAttempt = DateTime.now();
      debugPrint("Triggering Auto-Connect to: ${target.remoteId.toString()}");
      connectToDevice(target)
          .then((_) {
            _isAutoConnecting = false;
          })
          .catchError((e) {
            _isAutoConnecting = false;
          });
    } else {
      if (!isScanning) {
        debugPrint(
          "Auto-Connect: Device not visible, starting scan to find $targetId...",
        );
        startScan();
      }
    }
  }

  /// Attaches the service layer to a physical device and executes initial handshake protocols.
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await _connectionManager.connectToDevice(device);

      _sensorController.sendCommand = _connectionManager.sendData;

      await startPairing();

      await syncSettingsToRing();

      _startPeriodicSyncTimer();
      triggerSmartSync();
    } catch (e) {
      // Errors bubbled up from Manager
    }
  }

  /// Terminates the BLE link cleanly.
  Future<void> disconnect() async {
    await _connectionManager.disconnect();
    _stopPeriodicSyncTimer();
    _sensorController.sendCommand = null;
  }

  /// Routes asynchronous notifications (like sync completion triggers) to the correct processing logic.
  void _onNotificationReceived(int type) {
    if (type == 0x01) {
      syncHeartRateHistory();
    } else if (type == 0x03 || type == 0x2C) {
      Future.delayed(Duration.zero, () async {
        await syncHeartRateHistory();
        await Future.delayed(const Duration(milliseconds: 500));
        await syncSpo2History();
        await Future.delayed(const Duration(milliseconds: 500));
        await syncStressHistory();
      });
    }
  }

  /// Detects if the ring enters a workout state without the app's consent and forcefully terminates it.
  void _checkForRunawayActivity() {
    if (!_isActivitySessionActive) {
      final now = DateTime.now();

      if (_lastRunawayStopTimestamp != null &&
          now.difference(_lastRunawayStopTimestamp!) <
              const Duration(seconds: 15)) {
        return;
      }

      debugPrint("Runaway Activity Detected! Sending FORCE STOP...");
      addToProtocolLog("Runaway Activity - Force Stopping", isTx: true);

      _lastRunawayStopTimestamp = now;

      _connectionManager.sendData(PacketFactory.endActivity());

      Future.delayed(const Duration(milliseconds: 300), () {
        _connectionManager.sendData(
          PacketFactory.createPacket(command: 0x77, data: [0x02]),
        );
      });
    }
  }

  /// Evaluates timing constraints before allowing a full sequential sync with both the ring and the cloud.
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

  /// Bypasses timing locks and forces an immediate data pull.
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

  /// Submits the initial setup properties required to register the phone as a master device to the ring.
  Future<void> startPairing() async {
    addToProtocolLog("TX: 04 ... (Set Name)", isTx: true);
    await _connectionManager.sendData(PacketFactory.createSetPhoneNamePacket());
    await Future.delayed(const Duration(milliseconds: 200));

    addToProtocolLog("TX: 01 ... (Set Time)", isTx: true);
    await _connectionManager.sendData(PacketFactory.createSetTimePacket());
    await Future.delayed(const Duration(milliseconds: 200));

    addToProtocolLog("TX: Battery", isTx: true);
    await getBatteryLevel();
  }

  Future<void> syncTime() => normalizeTime();

  /// Forces the ring's internal clock to match the local timezone of the phone.
  Future<void> normalizeTime() async {
    await _connectionManager.sendData(PacketFactory.createSetTimePacket());
  }

  /// Orchestrates the delicate dance of querying various metrics sequentially, avoiding buffer overflows on the ring.
  Future<void> startFullSyncSequence() async {
    if (!isConnected) return;
    _isSyncing = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final difference = now.difference(selectedDate).inDays;
      final int offset = difference < 0 ? 0 : difference;

      await _connectionManager.sendData(
        PacketFactory.getStepsPacket(dayOffset: offset),
      );
      await Future.delayed(const Duration(seconds: 2));
      await syncGoals();
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

      await uploadDataToCloud();
      await Future.delayed(const Duration(seconds: 2));
      await downloadDataFromCloud();

      _logger.setLastLog("Full Sync Completed");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // --- Cloud Data Sync Methods ---

  Future<void> uploadDataToCloud() async {
    await _apiSync.uploadForDate(date: selectedDate, dataManager: _dataManager);
  }

  Future<void> downloadDataFromCloud() async {
    await _apiSync.downloadForDate(
      date: selectedDate,
      dataManager: _dataManager,
    );
  }

  Future<void> syncGoals() async {
    await _connectionManager.sendData(PacketFactory.requestGoals());
  }

  Future<void> syncHeartRateHistory() async {
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    await _connectionManager.sendData(
      PacketFactory.getHeartRateLogPacket(startOfDay),
    );
  }

  Future<void> syncSpo2History() async =>
      await _connectionManager.sendData(PacketFactory.getSpo2LogPacketNew());
  Future<void> syncStressHistory() async =>
      await _connectionManager.sendData(PacketFactory.getStressHistoryPacket());
  Future<void> syncHrvHistory() async =>
      await _connectionManager.sendData(PacketFactory.getHrvLogPacket());

  Future<void> syncSleepHistory() async {
    try {
      await _connectionManager.sendData(PacketFactory.createBindRequest());
      await Future.delayed(const Duration(milliseconds: 300));
      if (_connectionManager.hasV2Service) {
        await _connectionManager.sendDataV2(
          PacketFactory.createSleepRequestPacket(),
        );
      } else {
        await _connectionManager.sendData(
          PacketFactory.createSleepRequestPacket(),
        );
      }
    } catch (e) {
      debugPrint("$e");
    }
  }

  Future<void> getBatteryLevel() async =>
      await _connectionManager.sendData(PacketFactory.getBatteryPacket());

  // Auto Settings
  Future<void> setAutoHrInterval(int minutes) async {
    _dataManager.updateAutoConfig("HR", minutes > 0);
    if (minutes > 0) {
      _dataManager.hrInterval = minutes;
    }

    final int enabledVal = minutes > 0 ? 0x01 : 0x00;
    final int intervalVal = minutes > 0 ? minutes : 0;
    await _connectionManager.sendData(
      PacketFactory.createPacket(
        command: 0x16,
        data: [0x02, enabledVal, intervalVal],
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hrInterval', minutes);
  }

  Future<void> setAutoSpo2(bool enabled) async {
    _dataManager.updateAutoConfig("SpO2", enabled);
    await _connectionManager.sendData(
      PacketFactory.createPacket(command: 0x2C, data: [0x02, enabled ? 1 : 0]),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('spo2Enabled', enabled);
  }

  Future<void> setAutoStress(bool enabled) async {
    _dataManager.updateAutoConfig("Stress", enabled);
    await _connectionManager.sendData(
      PacketFactory.createPacket(command: 0x36, data: [0x02, enabled ? 1 : 0]),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('stressEnabled', enabled);
  }

  Future<void> setAutoHrv(bool enabled) async {
    _dataManager.updateAutoConfig("HRV", enabled);
    await _connectionManager.sendData(
      PacketFactory.createPacket(command: 0x38, data: [0x02, enabled ? 1 : 0]),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hrvEnabled', enabled);
  }

  /// Pushes all locally persisted automated measurement interval preferences to the hardware ring.
  Future<void> syncSettingsToRing() async {
    await normalizeTime();
    final prefs = await SharedPreferences.getInstance();
    final int? hr = prefs.getInt('hrInterval');
    if (hr != null) await setAutoHrInterval(hr);
    final bool? spo2 = prefs.getBool('spo2Enabled');
    if (spo2 != null) await setAutoSpo2(spo2);
    final bool? stress = prefs.getBool('stressEnabled');
    if (stress != null) await setAutoStress(stress);
    final bool? hrv = prefs.getBool('hrvEnabled');
    if (hrv != null) await setAutoHrv(hrv);

    await Future.delayed(const Duration(milliseconds: 500));
    await readAutoSettings();
  }

  Future<void> setHeartRateMonitoring(bool enabled) =>
      setAutoHrInterval(enabled ? 5 : 0);
  Future<void> setSpo2Monitoring(bool enabled) => setAutoSpo2(enabled);
  Future<void> setStressMonitoring(bool enabled) => setAutoStress(enabled);

  Future<void> factoryReset() async => await _connectionManager.sendData(
    PacketFactory.createPacket(command: 0xFF, data: [0x66, 0x66]),
  );
  Future<void> rebootRing() async => await _connectionManager.sendData(
    PacketFactory.createPacket(command: 0x08, data: [0x05]),
  );

  Future<void> turnOnBluetooth() async {
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }
  }

  Future<void> sendRawPacket(List<int> packet) async =>
      await _connectionManager.sendData(packet);

  Future<void> enableRawData() async =>
      await _connectionManager.sendData(PacketFactory.enableRawDataPacket());
  Future<void> disableRawData() async =>
      await _connectionManager.sendData(PacketFactory.disableRawDataPacket());

  /// Completely severs the tie to the current ring, clearing caches and breaking the native OS bond.
  Future<void> unpairRing() async {
    debugPrint("Unpairing Ring...");

    BluetoothDevice? deviceToUnpair = _connectionManager.connectedDevice;

    if (deviceToUnpair == null && _connectionManager.lastDeviceId != null) {
      await _scanner.loadBondedDevices();
      try {
        deviceToUnpair = _scanner.bondedDevices.firstWhere(
          (d) => d.remoteId.toString() == _connectionManager.lastDeviceId,
        );
      } catch (_) {}
    }

    if (deviceToUnpair != null) {
      try {
        await deviceToUnpair.removeBond();
        debugPrint("Unpairing: Bond removed for ${deviceToUnpair.remoteId}");
      } catch (e) {
        debugPrint("Unpairing Error: $e");
      }
    } else {
      debugPrint("Unpairing: No device found to unbond.");
    }

    await disconnect();
    await _connectionManager.clearLastDeviceId();
  }

  Future<void> startRealTimeHeartRate() => startHeartRate();
  Future<void> stopRealTimeHeartRate() => stopHeartRate();
  Future<void> startRealTimeSpo2() => startSpo2();
  Future<void> stopRealTimeSpo2() => stopSpo2();

  Future<void> startHeartRate() async {
    if (_sensorController.isMeasuringSpo2) await _sensorController.stopSpo2();
    _dataManager.startManualHrMeasurement();
    await _sensorController.startHeartRate();
  }

  Future<void> stopHeartRate() {
    _dataManager.stopManualHrMeasurement();
    return _sensorController.stopHeartRate();
  }

  Future<void> startSpo2() async {
    if (_sensorController.isMeasuringHeartRate) {
      await _sensorController.stopHeartRate();
    }
    await _sensorController.startSpo2();
  }

  Future<void> stopSpo2() => _sensorController.stopSpo2();
  Future<void> startRawPPG() => _sensorController.startRawPPG();
  Future<void> stopRawPPG() => _sensorController.stopRawPPG();
  Future<void> startStressTest() async {
    if (_sensorController.isMeasuringHeartRate) {
      await _sensorController.stopHeartRate();
    }
    await _sensorController.startStressTest();
  }

  Future<void> stopStressTest() => _sensorController.stopStressTest();
  Future<void> startRealTimeHrv() => _sensorController.startRealTimeHrv();
  Future<void> stopRealTimeHrv() => _sensorController.stopRealTimeHrv();

  Future<void> readAutoSettings() async {
    if (!_connectionManager.isConnected) return;
    await _connectionManager.sendData(
      PacketFactory.createPacket(command: 0x16, data: [0x01]),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    await _connectionManager.sendData(
      PacketFactory.createPacket(command: 0x2C, data: [0x01]),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    await _connectionManager.sendData(
      PacketFactory.createPacket(command: 0x36, data: [0x01]),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    await _connectionManager.sendData(
      PacketFactory.createPacket(command: 0x38, data: [0x01]),
    );
  }

  Future<void> findDevice() async {
    if (!_connectionManager.isConnected) return;
    await _connectionManager.sendData(PacketFactory.createFindDevicePacket());
  }

  Future<void> syncStepsHistory() async {
    if (!_connectionManager.isConnected) return;
    final now = DateTime.now();
    final difference = now.difference(selectedDate).inDays;
    final int offset = difference < 0 ? 0 : difference;
    await _connectionManager.sendData(
      PacketFactory.getStepsPacket(dayOffset: offset),
    );
  }

  /// Sends termination commands for every possible live measurement, useful for error recovery.
  Future<void> forceStopEverything() async {
    try {
      await disableRawData();
      if (_sensorController.isMeasuringHeartRate) {
        await _sensorController.stopHeartRate();
      }
      if (_sensorController.isMeasuringSpo2) await _sensorController.stopSpo2();
      if (_sensorController.isMeasuringStress) {
        await _sensorController.stopStressTest();
      }
      if (_sensorController.isMeasuringHrv) {
        await _sensorController.stopRealTimeHrv();
      }
      if (_sensorController.isMeasuringRawPPG) {
        await _sensorController.stopRawPPG();
      }

      await _connectionManager.sendData(PacketFactory.disableHeartRate());
      await _connectionManager.sendData(PacketFactory.disableSpo2());
    } catch (e) {
      debugPrint("Error force stopping: $e");
    }
  }

  // --- Activity Control ---

  /// Prepares the ring to track high-fidelity data suitable for a workout session.
  Future<void> startActivity(ActivityType type) async {
    _isActivitySessionActive = true;
    notifyListeners();

    int typeId = 0x01;
    switch (type) {
      case ActivityType.walk:
        typeId = 0x01;
        break;
      case ActivityType.run:
        typeId = 0x02;
        break;
      case ActivityType.cycling:
        typeId = 0x03;
        break;
      case ActivityType.hiking:
        typeId = 0x04;
        break;
      case ActivityType.swimming:
        typeId = 0x05;
        break;
      case ActivityType.gym:
        typeId = 0x06;
        break;
      case ActivityType.yoga:
        typeId = 0x07;
        break;
      default:
        typeId = 0x01;
    }

    addToProtocolLog("Activity Start: $type ($typeId)", isTx: true);

    _dataManager.resetActivityStats();

    await _connectionManager.sendData(PacketFactory.startActivity(typeId));

    await Future.delayed(const Duration(seconds: 1));
    await startHeartRate();
  }

  /// Finalizes the workout session, stops high-frequency scanning, and clears UI lock states.
  Future<void> stopActivity() async {
    _isActivitySessionActive = false;
    notifyListeners();

    addToProtocolLog("Activity Stop Sequence Initiated", isTx: true);

    await _connectionManager.sendData(
      PacketFactory.createPacket(command: 0x77, data: [0x02]),
    );

    await Future.delayed(const Duration(milliseconds: 200));
    await stopHeartRate();
    if (_sensorController.isMeasuringSpo2) await stopSpo2();
    await disableRawData();

    await Future.delayed(const Duration(milliseconds: 300));
    await _connectionManager.sendData(PacketFactory.endActivity());

    addToProtocolLog("Activity Stop Sequence Completed", isTx: true);

    NotificationService.showActivityCelebration();
  }
}
