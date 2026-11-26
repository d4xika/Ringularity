import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ble_logger.dart';
import 'packet_factory.dart';

typedef SendCommandCallback = Future<void> Function(List<int> data);

/// A discrete controller managing the state and timeouts of live sensor requests.
///
/// Uses the [PacketFactory] to generate action commands and funnels them through
/// the injected [sendCommand] callback. Implements safety timers to gracefully auto-stop
/// measurements if the hardware stops responding.
class BleSensorController extends ChangeNotifier {
  SendCommandCallback? sendCommand;
  final BleLogger logger;
  VoidCallback? onHeartRateStopped;
  int? _heartRateReading;
  int? _stressReading;
  int? _hrvReading;

  int? get heartRateReading => _heartRateReading;
  int? get stressReading => _stressReading;
  int? get hrvReading => _hrvReading;

  Future<void> _stopOnTimeout(Future<void> Function() stop) async {
    try {
      await stop();
    } catch (error) {
      logger.setLastLog('Measurement stop failed: $error');
    }
  }

  void onMeasurementError(int type, int errorCode) {
    switch (type) {
      case 0x01:
        _hrDataTimer?.cancel();
        _isMeasuringHeartRate = false;
        onHeartRateStopped?.call();
        break;
      case 0x08:
        _stressDataTimer?.cancel();
        _isMeasuringStress = false;
        break;
      case 0x0A:
        _hrvDataTimer?.cancel();
        _isMeasuringHrv = false;
        break;
    }
    notifyListeners();
  }

  /// Creates a new [BleSensorController] instance.
  BleSensorController({required this.logger, this.sendCommand});

  /// Detaches the old connection and cancels measurement timers and active sensor state.
  void resetAccount() {
    sendCommand = null;
    _heartRateReading = _stressReading = _hrvReading = null;
    _hrDataTimer?.cancel();
    _stressDataTimer?.cancel();
    _hrvDataTimer?.cancel();
    _isMeasuringHeartRate = _isMeasuringStress = _isMeasuringHrv =
        _isMeasuringRawPPG = false;
    notifyListeners();
  }

  @override
  void dispose() {
    resetAccount();
    super.dispose();
  }

  // --- Heart Rate ---
  bool _isMeasuringHeartRate = false;

  /// Indicates if a live, on-demand heart rate query is currently active.
  bool get isMeasuringHeartRate => _isMeasuringHeartRate;
  Timer? _hrDataTimer;

  /// Commands the ring's optical sensors to initiate a continuous heart rate stream.
  Future<void> startHeartRate() async {
    if (sendCommand == null) {
      throw StateError('Ring is not connected');
    }
    _heartRateReading = null;
    _hrDataTimer?.cancel();
    _isMeasuringHeartRate = true;
    _hrDataTimer = Timer(
      const Duration(seconds: 60),
      () => _stopOnTimeout(stopHeartRate),
    );
    notifyListeners();
    final List<int> packet = PacketFactory.startHeartRate();
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Start HR)", isTx: true);
    try {
      await sendCommand!(packet);
    } catch (_) {
      _hrDataTimer?.cancel();
      _isMeasuringHeartRate = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Commands the ring to shut down the active heart rate optical sensor.
  Future<void> stopHeartRate() async {
    if (sendCommand == null) return;
    _isMeasuringHeartRate = false;
    _hrDataTimer?.cancel();
    onHeartRateStopped?.call();
    notifyListeners();
    final List<int> packet = PacketFactory.stopHeartRate();
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Stop HR)", isTx: true);
    await sendCommand!(packet);
  }

  /// Called upon receiving a valid HR data point. Resets the inactivity kill-switch.
  void onHeartRateReceived(int bpm) {
    if (_isMeasuringHeartRate) {
      _heartRateReading = bpm;
      notifyListeners();
      _hrDataTimer?.cancel();
      _hrDataTimer = Timer(const Duration(seconds: 3), () {
        if (_isMeasuringHeartRate) {
          debugPrint("HR Silence Detected - Stopping...");
          _stopOnTimeout(stopHeartRate);
        }
      });
    }
  }

  // --- Stress ---
  bool _isMeasuringStress = false;
  bool get isMeasuringStress => _isMeasuringStress;
  Timer? _stressDataTimer;

  /// Triggers a live stress computation cycle on the hardware.
  Future<void> startStressTest() async {
    if (sendCommand == null) {
      throw StateError('Ring is not connected');
    }
    _stressReading = null;
    _stressDataTimer?.cancel();
    _isMeasuringStress = true;
    _stressDataTimer = Timer(
      const Duration(seconds: 60),
      () => _stopOnTimeout(stopStressTest),
    );
    notifyListeners();
    final List<int> packet = PacketFactory.startStress();
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Start Stress)", isTx: true);
    try {
      await sendCommand!(packet);
    } catch (_) {
      _stressDataTimer?.cancel();
      _isMeasuringStress = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Halts the active stress computation cycle.
  Future<void> stopStressTest() async {
    if (sendCommand == null) return;
    _isMeasuringStress = false;
    _stressDataTimer?.cancel();
    notifyListeners();
    final List<int> packet = PacketFactory.stopStress();
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Stop Stress)", isTx: true);
    await sendCommand!(packet);
  }

  /// Resets the stress inactivity kill-switch.
  void onStressReceived(int level) {
    if (_isMeasuringStress) {
      _stressReading = level;
      notifyListeners();
      _stressDataTimer?.cancel();
      _stressDataTimer = Timer(const Duration(seconds: 3), () {
        if (_isMeasuringStress) {
          _stopOnTimeout(stopStressTest);
        }
      });
    }
  }

  // --- HRV ---
  bool _isMeasuringHrv = false;
  bool get isMeasuringHrv => _isMeasuringHrv;
  Timer? _hrvDataTimer;

  /// Commands the ring to stream Heart Rate Variability (HRV) computations.
  Future<void> startRealTimeHrv() async {
    if (sendCommand == null) {
      throw StateError('Ring is not connected');
    }
    _hrvReading = null;
    _hrvDataTimer?.cancel();
    _isMeasuringHrv = true;
    _hrvDataTimer = Timer(
      const Duration(seconds: 60),
      () => _stopOnTimeout(stopRealTimeHrv),
    );
    notifyListeners();
    final List<int> packet = PacketFactory.createPacket(
      command: 0x69,
      data: [0x0A, 0x00],
    );
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Start HRV)", isTx: true);
    try {
      await sendCommand!(packet);
    } catch (_) {
      _hrvDataTimer?.cancel();
      _isMeasuringHrv = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Shuts down the HRV stream.
  Future<void> stopRealTimeHrv() async {
    if (sendCommand == null) return;
    _isMeasuringHrv = false;
    _hrvDataTimer?.cancel();
    notifyListeners();
    final List<int> packet = PacketFactory.createPacket(
      command: 0x6A,
      data: [0x0A, 0x00],
    );
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Stop HRV)", isTx: true);
    await sendCommand!(packet);
  }

  /// Resets the HRV inactivity kill-switch.
  void onHrvReceived(int val) {
    if (_isMeasuringHrv) {
      _hrvReading = val;
      notifyListeners();
      _hrvDataTimer?.cancel();
      _hrvDataTimer = Timer(const Duration(seconds: 3), () {
        if (_isMeasuringHrv) {
          _stopOnTimeout(stopRealTimeHrv);
        }
      });
    }
  }

  // --- Raw PPG ---
  bool _isMeasuringRawPPG = false;
  bool get isMeasuringRawPPG => _isMeasuringRawPPG;

  /// Triggers an unparsed, high-frequency dump of raw Photoplethysmography (PPG) sensor data.
  Future<void> startRawPPG() async {
    if (sendCommand == null) return;
    _isMeasuringRawPPG = true;
    notifyListeners();
    final List<int> packet = PacketFactory.startRawPPG();
    logger.addToProtocolLog("TX: ... (Start PPG)", isTx: true);
    await sendCommand!(packet);
  }

  /// Terminates the raw PPG data dump.
  Future<void> stopRawPPG() async {
    if (sendCommand == null) return;
    _isMeasuringRawPPG = false;
    notifyListeners();
    final List<int> packet = PacketFactory.stopRawPPG();
    logger.addToProtocolLog("TX: ... (Stop PPG)", isTx: true);
    await sendCommand!(packet);
  }
}
