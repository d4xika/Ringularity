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

  /// Creates a new [BleSensorController] instance.
  BleSensorController({required this.logger, this.sendCommand});

  // --- Heart Rate ---
  bool _isMeasuringHeartRate = false;

  /// Indicates if a live, on-demand heart rate query is currently active.
  bool get isMeasuringHeartRate => _isMeasuringHeartRate;
  Timer? _hrDataTimer;

  /// Commands the ring's optical sensors to initiate a continuous heart rate stream.
  Future<void> startHeartRate() async {
    if (sendCommand == null) return;
    _isMeasuringHeartRate = true;
    notifyListeners();
    final List<int> packet = PacketFactory.startHeartRate();
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Start HR)", isTx: true);
    await sendCommand!(packet);
  }

  /// Commands the ring to shut down the active heart rate optical sensor.
  Future<void> stopHeartRate() async {
    if (sendCommand == null) return;
    _isMeasuringHeartRate = false;
    _hrDataTimer?.cancel();
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
      _hrDataTimer?.cancel();
      _hrDataTimer = Timer(const Duration(seconds: 3), () {
        if (_isMeasuringHeartRate) {
          debugPrint("HR Silence Detected - Stopping...");
          stopHeartRate();
        }
      });
    }
  }

  // --- SpO2 ---
  bool _isMeasuringSpo2 = false;

  /// Indicates if a live, on-demand blood oxygen query is currently active.
  bool get isMeasuringSpo2 => _isMeasuringSpo2;

  /// Commands the ring to pulse red/IR LEDs to determine blood oxygenation.
  Future<void> startSpo2() async {
    if (sendCommand == null) return;
    _isMeasuringSpo2 = true;
    notifyListeners();
    final List<int> packet = PacketFactory.startSpo2();
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Start SpO2)", isTx: true);
    await sendCommand!(packet);
  }

  /// Disables the SpO2 LEDs.
  Future<void> stopSpo2() async {
    if (sendCommand == null) return;
    _isMeasuringSpo2 = false;
    notifyListeners();
    final List<int> packet = PacketFactory.stopRealTimeSpo2();
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Stop SpO2)", isTx: true);
    await sendCommand!(packet);
  }

  /// SpO2 tests typically auto-terminate after the first successful reading.
  void onSpo2Received(int percent) {
    if (_isMeasuringSpo2) {
      stopSpo2();
    }
  }

  // --- Stress ---
  bool _isMeasuringStress = false;
  bool get isMeasuringStress => _isMeasuringStress;
  Timer? _stressDataTimer;

  /// Triggers a live stress computation cycle on the hardware.
  Future<void> startStressTest() async {
    if (sendCommand == null) return;
    _isMeasuringStress = true;
    notifyListeners();
    final List<int> packet = PacketFactory.startStress();
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Start Stress)", isTx: true);
    await sendCommand!(packet);
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
      _stressDataTimer?.cancel();
      _stressDataTimer = Timer(const Duration(seconds: 3), () {
        if (_isMeasuringStress) {
          stopStressTest();
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
    if (sendCommand == null) return;
    _isMeasuringHrv = true;
    notifyListeners();
    final List<int> packet = PacketFactory.createPacket(
      command: 0x69,
      data: [0x0A, 0x00],
    );
    final hex = packet
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    logger.addToProtocolLog("$hex (Start HRV)", isTx: true);
    await sendCommand!(packet);
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
      _hrvDataTimer?.cancel();
      _hrvDataTimer = Timer(const Duration(seconds: 3), () {
        if (_isMeasuringHrv) stopRealTimeHrv();
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
