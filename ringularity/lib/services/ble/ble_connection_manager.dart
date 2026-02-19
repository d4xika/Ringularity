import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_constants.dart';
import 'ble_logger.dart';

/// Manages the raw Bluetooth connection, service discovery, and characteristic subscription.
/// Decouples the low-level BLE logic from the high-level application service.
class BleConnectionManager extends ChangeNotifier {
  final BleLogger logger;
  final Function(List<int>) onDataReceived;

  BleConnectionManager({required this.logger, required this.onDataReceived});

  // --- Connection State ---
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _writeCharV2;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _notifyCharV2;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  String? get currentDeviceId => _connectedDevice?.remoteId.toString();
  String? get currentDeviceName => _connectedDevice?.platformName;

  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<List<int>>? _notifySubscriptionV2;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  String _status = "Disconnected";
  String get status => _status;

  bool get isConnected => _connectedDevice != null && _writeChar != null;
  bool get isConnecting => _status.startsWith("Connecting");

  // --- Auto-Reconnect Helpers ---
  // Store the last connected device ID to local storage to enable auto-reconnection on next app launch.
  String? _lastDeviceId;
  String? get lastDeviceId => _lastDeviceId;

  Future<void> loadLastDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _lastDeviceId = prefs.getString('last_device_id');
    if (_lastDeviceId != null) {
      debugPrint("Loaded Last Device ID: $_lastDeviceId");
    }
  }

  Future<void> saveLastDeviceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_device_id', id);
    _lastDeviceId = id;
    debugPrint("Saved Last Device ID: $id");
  }

  Future<void> clearLastDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_device_id');
    _lastDeviceId = null;
    debugPrint("Cleared Last Device ID");
  }

  // --- Connection Logic ---
  // Handles the sequence of connecting, bonding (Android), and service discovery.

  Future<void> connectToDevice(BluetoothDevice device) async {
    _status = "Connecting to ${device.platformName}...";
    notifyListeners();

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint("Device Disconnected: ${device.remoteId}");
          _cleanup();
          _status = "Disconnected";
          notifyListeners();
        }
      });

      if (Platform.isAndroid) {
        try {
          await device.requestMtu(512);
        } catch (e) {
          debugPrint("MTU Request Failed: $e");
        }
        try {
          await device.createBond();
        } catch (e) {
          debugPrint("Bonding failed/skipped: $e");
        }
      }

      await _discoverServices(device);

      debugPrint("Waiting 2s for ring to settle...");
      await Future.delayed(const Duration(seconds: 2));

      _status = "Connected to ${device.platformName}";

      // Save as last device for auto-reconnect
      await saveLastDeviceId(device.remoteId.toString());

      notifyListeners();
    } catch (e) {
      _status = "Connection Failed: $e";
      _cleanup();
      notifyListeners();
      rethrow; // Re-throw so the UI or Service can handle the specific error if needed
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
    _cleanup();
  }

  // --- Service Discovery ---
  // Iterates through discovered services to find the specific Nordic UART or Colmi V2 service uuids.
  // This is critical to identify which characteristics to write commands to.

  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    _writeChar = null;
    _writeCharV2 = null;
    _notifyChar = null;
    _notifyCharV2 = null;

    // Standard Nordic UART Service (V1)
    try {
      var service = services.firstWhere(
        (s) => s.uuid.toString().toUpperCase() == BleConstants.serviceUuid,
      );
      for (var c in service.characteristics) {
        if (c.uuid.toString().toUpperCase() == BleConstants.writeCharUuid) {
          _writeChar = c; // Primary write channel
        }
        if (c.uuid.toString().toUpperCase() == BleConstants.notifyCharUuid) {
          _notifyChar = c;
        }
      }
    } catch (e) {
      debugPrint("Nordic UART service not found: $e");
    }

    // V2 Service (Newer Colmi rings)
    // Some rings use a secondary service for specific data (like sleep or big data sync).
    try {
      var serviceV2 = services.firstWhere(
        (s) =>
            s.uuid.toString().toLowerCase() ==
            BleConstants.serviceUuidV2.toLowerCase(),
      );
      for (var c in serviceV2.characteristics) {
        String uuid = c.uuid.toString().toLowerCase();
        if (uuid == BleConstants.notifyCharUuidV2.toLowerCase()) {
          _notifyCharV2 = c;
        }
        if (uuid == BleConstants.writeCharUuidV2.toLowerCase()) {
          _writeCharV2 = c;
        }
      }
    } catch (e) {
      debugPrint("Colmi V2 Service not found (V1-only?)");
    }

    // Fallback
    if (_writeChar == null) {
      for (var s in services) {
        if (s.uuid.toString().startsWith("000018")) continue;
        for (var c in s.characteristics) {
          if (_writeChar == null &&
              (c.properties.write || c.properties.writeWithoutResponse)) {
            _writeChar = c;
          }
          if (_notifyChar == null && c.properties.notify) {
            _notifyChar = c;
          }
        }
      }
    }

    // Subscribe V1
    if (_notifyChar != null) {
      await _notifySubscription?.cancel();
      await _notifyChar!.setNotifyValue(true);
      _notifySubscription = _notifyChar!.lastValueStream.listen(
        _onInternalDataReceived,
      );
    }

    // Subscribe V2
    if (_notifyCharV2 != null) {
      await _notifySubscriptionV2?.cancel();
      await _notifyCharV2!.setNotifyValue(true);
      _notifySubscriptionV2 = _notifyCharV2!.lastValueStream.listen(
        _onInternalDataReceived,
      );
    }
  }

  void _onInternalDataReceived(List<int> data) {
    onDataReceived(data);
  }

  void _cleanup() {
    _connectedDevice = null;
    _writeChar = null;
    _notifyChar = null;
    _notifyCharV2 = null;
    _notifySubscription?.cancel();
    _notifySubscriptionV2?.cancel();
    _connectionStateSubscription?.cancel();
    // Do NOT clear logger here, keep logs
  }

  // --- Output ---

  Future<void> sendData(List<int> data) async {
    if (_writeChar != null) {
      final c = _writeChar!;
      final props = c.properties;
      // If characteristic only supports withoutResponse, use it. Otherwise prefer write with response.
      final bool useWithoutFirst = props.writeWithoutResponse && !props.write;
      try {
        await c.write(data, withoutResponse: useWithoutFirst);
      } catch (e) {
        debugPrint("sendData write failed (withoutResponse=$useWithoutFirst): $e");
        // Retry with the alternate mode if supported
        if (!useWithoutFirst && props.writeWithoutResponse) {
          try {
            await c.write(data, withoutResponse: true);
          } catch (e2) {
            debugPrint("sendData retry (withoutResponse=true) failed: $e2");
          }
        }
      }
    } else {
      debugPrint("Attempted to send data but _writeChar is null");
    }
  }

  Future<void> sendDataV2(List<int> data) async {
    if (_writeCharV2 != null) {
      final c = _writeCharV2!;
      final props = c.properties;
      final bool useWithoutFirst = props.writeWithoutResponse && !props.write;
      try {
        await c.write(data, withoutResponse: useWithoutFirst);
      } catch (e) {
        debugPrint("sendDataV2 write failed (withoutResponse=$useWithoutFirst): $e");
        if (!useWithoutFirst && props.writeWithoutResponse) {
          try {
            await c.write(data, withoutResponse: true);
          } catch (e2) {
            debugPrint("sendDataV2 retry (withoutResponse=true) failed: $e2");
          }
        }
      }
    } else {
      // Fallback or error? For now assume V1 fallback handled by caller or just warn
      debugPrint("Attempted to send V2 data but _writeCharV2 is null");
    }
  }

  // Expose check if V2 is available
  bool get hasV2Service => _writeCharV2 != null;
}
