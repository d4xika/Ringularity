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

  List<BluetoothDevice> get availableDevices => {
    for (final device in _bondedDevices) device.remoteId: device,
    for (final result in _scanResults) result.device.remoteId: result.device,
  }.values.toList();

  Future<void> _operations = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.catchError((Object _) {});
    return result;
  }

  bool _matchesName(BluetoothDevice device) {
    final name = device.platformName.isNotEmpty
        ? device.platformName
        : device.advName;
    return BleConstants.targetDeviceNames.any(
      (target) => name.toLowerCase().contains(target.toLowerCase()),
    );
  }

  bool _isScanning = false;

  /// Indicates whether the radio is currently actively listening for advertisements.
  bool get isScanning => _isScanning;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  /// Queries the host OS (iOS/Android) for devices that have already formed a secure bond
  /// or are persistently connected at the system level.
  Future<void> loadBondedDevices({bool notify = true}) async {
    final devices = <DeviceIdentifier, BluetoothDevice>{};
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        for (final device in await FlutterBluePlus.bondedDevices) {
          if (_matchesName(device)) {
            devices[device.remoteId] = device;
          }
        }
      } catch (error) {
        debugPrint('Error loading bonded devices: $error');
      }
    }
    try {
      final system = await FlutterBluePlus.systemDevices([
        Guid(BleConstants.serviceUuid),
        Guid(BleConstants.serviceUuidV2),
      ]);
      for (final device in system) {
        if (defaultTargetPlatform != TargetPlatform.android ||
            _matchesName(device)) {
          devices[device.remoteId] = device;
        }
      }
    } catch (error) {
      debugPrint('Error loading system devices: $error');
    }
    _bondedDevices = devices.values.toList();
    if (notify) {
      notifyListeners();
    }
  }

  /// Instructs the Bluetooth radio to begin discovering nearby devices without a timeout.
  Future<void> startScan() => _enqueue(_startScan);

  Future<void> _startScan() async {
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

      await loadBondedDevices(notify: false);
      await FlutterBluePlus.startScan(withServices: []);

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results.where((r) {
          return _matchesName(r.device) ||
              r.advertisementData.serviceUuids.any(
                (uuid) =>
                    uuid == Guid(BleConstants.serviceUuid) ||
                    uuid == Guid(BleConstants.serviceUuidV2),
              );
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
  Future<void> stopScan() => _enqueue(_stopScan);

  Future<void> _stopScan() async {
    debugPrint("BleScanner: Stopping scan...");
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint("BleScanner: Stop Scan Error: $e");
    } finally {
      await _scanSubscription?.cancel();
      await _isScanningSubscription?.cancel();
      _scanSubscription = null;
      _isScanningSubscription = null;
      _isScanning = false;
      notifyListeners();
      debugPrint("BleScanner: Scan stopped");
    }
  }

  Future<void> resetAccount() => _enqueue(() async {
    await _stopScan();
    _scanResults.clear();
    _bondedDevices.clear();
    notifyListeners();
  });

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }
}
