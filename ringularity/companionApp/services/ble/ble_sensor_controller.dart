import 'dart:async';
import 'package:flutter/foundation.dart';
import 'packet_factory.dart';
import 'ble_logger.dart';

typedef SendCommandCallback = Future<void> Function(List<int> data);

class BleSensorController extends ChangeNotifier {
  SendCommandCallback? sendCommand;
  final BleLogger logger;

  BleSensorController({required this.logger, this.sendCommand});
  // Handles the logic for starting, stopping, and managing timers for specific sensor measurements.
  // It uses the `PacketFactory` to generate commands and `sendCommand` callback to transmit them.

  // --- Heart Rate ---
  bool _isMeasuringHeartRate = false;
  bool get isMeasuringHeartRate => _isMeasuringHeartRate;
  Timer? _hrDataTimer;

  Future<void> startHeartRate() async {
    if (sendCommand == null) return;
    _isMeasuringHeartRate = true;
    notifyListeners();
    // 0x69 0x01
    List<int> packet = PacketFactory.startHeartRate();
    final hex =
        packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    logger.addToProtocolLog("$hex (Start HR)", isTx: true);
    await sendCommand!(packet);
  }

  Future<void> stopHeartRate() async {
    if (sendCommand == null) return;
    _isMeasuringHeartRate = false;
    _hrDataTimer?.cancel();
    notifyListeners();
    List<int> packet = PacketFactory.stopHeartRate();
    final hex =
        packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    logger.addToProtocolLog("$hex (Stop HR)", isTx: true);
    await sendCommand!(packet);
  }

  // Auto-stop logic:
  // If we don't receive data for 3 seconds, we assume the ring stopped or connection failed.
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
  bool get isMeasuringSpo2 => _isMeasuringSpo2;

  Future<void> startSpo2() async {
    if (sendCommand == null) return;
    _isMeasuringSpo2 = true;
    notifyListeners();
    List<int> packet = PacketFactory.startSpo2();
    final hex =
        packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    logger.addToProtocolLog("$hex (Start SpO2)", isTx: true);
    await sendCommand!(packet);
  }

  Future<void> stopSpo2() async {
    if (sendCommand == null) return;
    _isMeasuringSpo2 = false;
    notifyListeners();
    // Use stopRealTimeSpo2
    List<int> packet = PacketFactory.stopRealTimeSpo2();
    final hex =
        packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    logger.addToProtocolLog("$hex (Stop SpO2)", isTx: true);
    await sendCommand!(packet);
  }

  void onSpo2Received(int percent) {
    if (_isMeasuringSpo2) {
      stopSpo2(); // Auto-stop immediately on first reading
    }
  }

  // --- Stress ---
  bool _isMeasuringStress = false;
  bool get isMeasuringStress => _isMeasuringStress;
  Timer? _stressDataTimer;

  Future<void> startStressTest() async {
    if (sendCommand == null) return;
    _isMeasuringStress = true;
    notifyListeners();
    List<int> packet = PacketFactory.startStress();
    final hex =
        packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    logger.addToProtocolLog("$hex (Start Stress)", isTx: true);
    await sendCommand!(packet);
  }

  Future<void> stopStressTest() async {
    if (sendCommand == null) return;
    _isMeasuringStress = false;
    _stressDataTimer?.cancel();
    notifyListeners();
    List<int> packet = PacketFactory.stopStress();
    final hex =
        packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    logger.addToProtocolLog("$hex (Stop Stress)", isTx: true);
    await sendCommand!(packet);
  }

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

  Future<void> startRealTimeHrv() async {
    if (sendCommand == null) return;
    _isMeasuringHrv = true;
    notifyListeners();
    // Manual Start: 69 0A 00
    // Using PacketFactory.createPacket if no method exists.
    // Based on BleService line 1358: createPacket(command: 0x69, data: [0x0A, 0x00])
    List<int> packet =
        PacketFactory.createPacket(command: 0x69, data: [0x0A, 0x00]);
    final hex =
        packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    logger.addToProtocolLog("$hex (Start HRV)", isTx: true);
    await sendCommand!(packet);
  }

  Future<void> stopRealTimeHrv() async {
    if (sendCommand == null) return;
    _isMeasuringHrv = false;
    _hrvDataTimer?.cancel();
    notifyListeners();
    // Manual Stop: 6A 0A 00
    List<int> packet =
        PacketFactory.createPacket(command: 0x6A, data: [0x0A, 0x00]);
    final hex =
        packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    logger.addToProtocolLog("$hex (Stop HRV)", isTx: true);
    await sendCommand!(packet);
  }

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

  Future<void> startRawPPG() async {
    if (sendCommand == null) return;
    _isMeasuringRawPPG = true;
    notifyListeners();
    List<int> packet = PacketFactory.startRawPPG();
    logger.addToProtocolLog("TX: ... (Start PPG)", isTx: true);
    await sendCommand!(packet);
  }

  Future<void> stopRawPPG() async {
    if (sendCommand == null) return;
    _isMeasuringRawPPG = false;
    notifyListeners();
    List<int> packet = PacketFactory.stopRawPPG();
    logger.addToProtocolLog("TX: ... (Stop PPG)", isTx: true);
    await sendCommand!(packet);
  }
}
