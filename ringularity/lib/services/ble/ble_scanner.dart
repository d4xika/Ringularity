import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_constants.dart';

/// Handles the discovery of nearby Bluetooth Low Energy devices.
///
/// Uses the `flutter_blue_plus` package to scan for active advertisements, filtering
/// the results to only expose devices whose names match a predefined hardware whitelist
/// (e.g., "Colmi", "R10"). Also manages retrieving pre-paired system devices.
class BleScanner extends ChangeNotifier {
  List<ScanResult> _scanResults = [];

  /// A filtered list of actively broadcasting devices discovered during the current scan.
  List<ScanResult> get scanResults => _scanResults;

  List<BluetoothDevice> _bondedDevices = [];

  /// Devices that are already known to the operating system's internal Bluetooth manager.
  List<BluetoothDevice> get bondedDevices => _bondedDevices;

  bool _isScanning = false;

  /// Indicates whether the radio is currently actively listening for advertisements.
  bool get isScanning => _isScanning;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  /// Queries the host OS (iOS/Android) for devices that have already formed a secure bond
  /// or are persistently connected at the system level.
  Future<void> loadBondedDevices({bool notify = true}) async {
    try {
      final bonded = await FlutterBluePlus.bondedDevices;

      final system = await FlutterBluePlus.systemDevices([
        Guid(BleConstants.serviceUuid),
        Guid(BleConstants.serviceUuidV2),
      ]);

      final Set<BluetoothDevice> allDevices = {...bonded, ...system};

      _bondedDevices = allDevices.where((d) {
        final String name = d.platformName;
        return BleConstants.targetDeviceNames.any(
          (target) => name.toLowerCase().contains(target.toLowerCase()),
        );
      }).toList();
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint("Error loading bonded/system devices: $e");
    }
  }

  /// Instructs the Bluetooth radio to begin discovering nearby devices without a timeout.
  Future<void> startScan() async {
    if (_isScanning) {
      debugPrint("BleScanner: Already scanning");
      return;
    }

    _isScanning = true;
    notifyListeners();

    debugPrint("BleScanner: Starting scan...");

    _scanResults.clear();

    try {
      await _scanSubscription?.cancel();
      await _isScanningSubscription?.cancel();

      await FlutterBluePlus.startScan(withServices: []);

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results.where((r) {
          String name = r.device.platformName;
          if (name.isEmpty) name = r.advertisementData.advName;

          final bool match = BleConstants.targetDeviceNames.any(
            (target) => name.toLowerCase().contains(target.toLowerCase()),
          );
          return match;
        }).toList();
        notifyListeners();
      });

      _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
        if (_isScanning != scanning) {
          _isScanning = scanning;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint("Scan Error: $e");
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Halts the active radio discovery process and disposes of listening streams.
  Future<void> stopScan() async {
    debugPrint("BleScanner: Stopping scan...");
    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      await _isScanningSubscription?.cancel();
      _scanSubscription = null;
      _isScanningSubscription = null;
      _isScanning = false;
      notifyListeners();
      debugPrint("BleScanner: Scan stopped");
    } catch (e) {
      debugPrint("BleScanner: Stop Scan Error: $e");
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }
}
