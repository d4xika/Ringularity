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

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  Future<void> loadBondedDevices({bool notify = true}) async {
    try {
      // 1. Get bonded devices (primarily for Android)
      final bonded = await FlutterBluePlus.bondedDevices;

      // 2. Get system-connected devices (crucial for iOS)
      // On iOS, devices already connected to the phone (but maybe not this app)
      // won't show up in scan results. systemDevices lets us find them.
      final system = await FlutterBluePlus.systemDevices([
        Guid(BleConstants.serviceUuid),
        Guid(BleConstants.serviceUuidV2),
      ]);

      // Combine both lists and remove duplicates
      final Set<BluetoothDevice> allDevices = {...bonded, ...system};

      // Filter bonded devices to only those matching our target names (Colmi, R02, etc.)
      _bondedDevices = allDevices.where((d) {
        final String name = d.platformName;
        // Check platform name against our whitelist in BleConstants
        return BleConstants.targetDeviceNames.any(
          (target) => name.toLowerCase().contains(target.toLowerCase()),
        );
      }).toList();
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint("Error loading bonded/system devices: $e");
    }
  }

  Future<void> startScan() async {
    if (_isScanning) {
      debugPrint("BleScanner: Already scanning");
      return;
    }

    _isScanning = true;
    notifyListeners();

    debugPrint("BleScanner: Starting scan...");
    // No longer awaiting loadBondedDevices here to prevent lag on scan start.
    // Bonded devices should be refreshed by the caller if needed.

    _scanResults.clear();

    try {
      // Cancel previous subscriptions if they exist
      await _scanSubscription?.cancel();
      await _isScanningSubscription?.cancel();

      await FlutterBluePlus.startScan(
        withServices: [], // Scan all
        // timeout: const Duration(seconds: 10), // DEBUG: Removed timeout
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results.where((r) {
          String name = r.device.platformName;
          if (name.isEmpty) name = r.advertisementData.advName;

          final bool match = BleConstants.targetDeviceNames.any(
            (target) => name.toLowerCase().contains(target.toLowerCase()),
          );
          if (!match && name.isNotEmpty) {
            // debugPrint("Filtered out: $name (${r.device.remoteId})");
          }
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
