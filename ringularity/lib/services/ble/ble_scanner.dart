import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_constants.dart';

class BleScanner extends ChangeNotifier {
  List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => _scanResults;

  List<BluetoothDevice> _bondedDevices = [];
  List<BluetoothDevice> get bondedDevices => _bondedDevices;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  Future<void> loadBondedDevices() async {
    try {
      final devices = await FlutterBluePlus.bondedDevices;
      // Filter bonded devices to only those matching our target names (Colmi, R02, etc.)
      _bondedDevices = devices.where((d) {
        String name = d.platformName;
        // Check platform name against our whitelist in BleConstants
        return BleConstants.targetDeviceNames.any(
          (target) => name.toLowerCase().contains(target.toLowerCase()),
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading bonded devices: $e");
    }
  }

  Future<void> startScan() async {
    if (_isScanning) {
      debugPrint("BleScanner: Already scanning");
      return;
    }

    debugPrint("BleScanner: Starting scan...");
    await loadBondedDevices();

    _scanResults.clear();
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(
        withServices: [], // Scan all
        // timeout: const Duration(seconds: 10), // DEBUG: Removed timeout
      );
      _isScanning = true;
      debugPrint("BleScanner: Scan started");
      notifyListeners();

      FlutterBluePlus.scanResults.listen((results) {
        // debugPrint("BleScanner: Received ${results.length} scan results"); // DEBUG
        _scanResults = results.where((r) {
          String name = r.device.platformName;
          if (name.isEmpty) name = r.advertisementData.advName;

          // debugPrint("Found device: $name (${r.device.remoteId})"); // DEBUG

          bool match = BleConstants.targetDeviceNames.any(
            (target) => name.toLowerCase().contains(target.toLowerCase()),
          );
          if (!match && name.isNotEmpty) {
            // Uncomment to debug hidden devices
            debugPrint("Filtered out: $name (${r.device.remoteId})");
          }
          return match;
        }).toList();
        notifyListeners();
      });

      FlutterBluePlus.isScanning.listen((scanning) {
        _isScanning = scanning;
        notifyListeners();
      });
    } catch (e) {
      debugPrint("Scan Error: $e");
    }
  }

  Future<void> stopScan() async {
    debugPrint("BleScanner: Stopping scan...");
    try {
      // debugPrint(StackTrace.current.toString());
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      notifyListeners();
      debugPrint("BleScanner: Scan stopped");
    } catch (e) {
      debugPrint("BleScanner: Stop Scan Error: $e");
    }
  }
}
