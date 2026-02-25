import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_constants.dart';
import 'ble_logger.dart';

/// Manages the raw Bluetooth connection lifecycle, service discovery, and characteristic subscriptions.
///
/// Decouples the low-level BLE logic from the high-level application services.
/// Handles complexities like Android-specific MTU requests, automatic fallback to
/// alternative characteristic modes (with/without response), and parsing both V1 (Nordic UART)
/// and V2 (Colmi proprietary) BLE service structures.
class BleConnectionManager extends ChangeNotifier {
  final BleLogger logger;
  final Function(List<int>) onDataReceived;

  /// Creates a new [BleConnectionManager] instance.
  BleConnectionManager({required this.logger, required this.onDataReceived});

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _writeCharV2;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _notifyCharV2;

  /// The physical device object currently connected.
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// The UUID/MAC string of the active connection.
  String? get currentDeviceId => _connectedDevice?.remoteId.toString();

  /// The advertised platform name of the active connection.
  String? get currentDeviceName => _connectedDevice?.platformName;

  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<List<int>>? _notifySubscriptionV2;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  String _status = "Disconnected";

  /// A human-readable string indicating the current phase of the connection flow.
  String get status => _status;

  /// True if the hardware is paired and a primary write characteristic is established.
  bool get isConnected => _connectedDevice != null && _writeChar != null;

  /// True if a connection attempt is actively running.
  bool get isConnecting => _status.startsWith("Connecting");

  String? _lastDeviceId;

  /// The UUID/MAC string of the device this app successfully connected to previously.
  String? get lastDeviceId => _lastDeviceId;

  /// Restores the ID of the last known ring to enable automatic background reconnection.
  Future<void> loadLastDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _lastDeviceId = prefs.getString('last_device_id');
    if (_lastDeviceId != null) {
      debugPrint("Loaded Last Device ID: $_lastDeviceId");
    }
  }

  /// Caches a successful connection ID into local storage.
  Future<void> saveLastDeviceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_device_id', id);
    _lastDeviceId = id;
    debugPrint("Saved Last Device ID: $id");
  }

  /// Wipes the cached connection ID (used during unpairing).
  Future<void> clearLastDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_device_id');
    _lastDeviceId = null;
    debugPrint("Cleared Last Device ID");
  }

  /// Initiates the connection sequence for a target [device], handling OS-specific quirks.
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

      // Android requires explicit MTU and Bonding steps to stabilize the connection.
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

      await saveLastDeviceId(device.remoteId.toString());

      notifyListeners();
    } catch (e) {
      _status = "Connection Failed: $e";
      _cleanup();
      notifyListeners();
      rethrow;
    }
  }

  /// Severs the active Bluetooth connection and clears all streams.
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
    _cleanup();
  }

  /// Scans the connected peripheral for specific Service UUIDs to map the read/write channels.
  /// Falls back to generic channels if standard UART or Colmi endpoints are not found.
  Future<void> _discoverServices(BluetoothDevice device) async {
    final List<BluetoothService> services = await device.discoverServices();
    _writeChar = null;
    _writeCharV2 = null;
    _notifyChar = null;
    _notifyCharV2 = null;

    // Phase 1: Search for Standard Nordic UART Service (V1)
    try {
      final service = services.firstWhere(
        (s) => s.uuid.toString().toUpperCase() == BleConstants.serviceUuid,
      );
      for (var c in service.characteristics) {
        if (c.uuid.toString().toUpperCase() == BleConstants.writeCharUuid) {
          _writeChar = c;
        }
        if (c.uuid.toString().toUpperCase() == BleConstants.notifyCharUuid) {
          _notifyChar = c;
        }
      }
    } catch (e) {
      debugPrint("Nordic UART service not found: $e");
    }

    // Phase 2: Search for V2 Service (Newer Colmi rings using secondary pipes for big data)
    try {
      final serviceV2 = services.firstWhere(
        (s) =>
            s.uuid.toString().toLowerCase() ==
            BleConstants.serviceUuidV2.toLowerCase(),
      );
      for (var c in serviceV2.characteristics) {
        final String uuid = c.uuid.toString().toLowerCase();
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

    // Phase 3: Ultimate Fallback (Bind to any available generic TX/RX properties)
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

    // Attach listeners to active read channels
    if (_notifyChar != null) {
      await _notifySubscription?.cancel();
      await _notifyChar!.setNotifyValue(true);
      _notifySubscription = _notifyChar!.lastValueStream.listen(
        _onInternalDataReceived,
      );
    }

    if (_notifyCharV2 != null) {
      await _notifySubscriptionV2?.cancel();
      await _notifyCharV2!.setNotifyValue(true);
      _notifySubscriptionV2 = _notifyCharV2!.lastValueStream.listen(
        _onInternalDataReceived,
      );
    }
  }

  /// Bridges the incoming byte array from the BLE stream to the parent service.
  void _onInternalDataReceived(List<int> data) {
    onDataReceived(data);
  }

  /// Nullifies active connections and cancels subscriptions. Does not erase the logger.
  void _cleanup() {
    _connectedDevice = null;
    _writeChar = null;
    _notifyChar = null;
    _notifyCharV2 = null;
    _notifySubscription?.cancel();
    _notifySubscriptionV2?.cancel();
    _connectionStateSubscription?.cancel();
  }

  /// Dispatches a byte payload to the primary (V1) write characteristic of the ring.
  Future<void> sendData(List<int> data) async {
    if (_writeChar != null) {
      final c = _writeChar!;
      final props = c.properties;
      final bool useWithoutFirst = props.writeWithoutResponse && !props.write;
      try {
        await c.write(data, withoutResponse: useWithoutFirst);
      } catch (e) {
        debugPrint(
          "sendData write failed (withoutResponse=$useWithoutFirst): $e",
        );
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

  /// Dispatches a byte payload to the secondary (V2) write characteristic of the ring, if available.
  Future<void> sendDataV2(List<int> data) async {
    if (_writeCharV2 != null) {
      final c = _writeCharV2!;
      final props = c.properties;
      final bool useWithoutFirst = props.writeWithoutResponse && !props.write;
      try {
        await c.write(data, withoutResponse: useWithoutFirst);
      } catch (e) {
        debugPrint(
          "sendDataV2 write failed (withoutResponse=$useWithoutFirst): $e",
        );
        if (!useWithoutFirst && props.writeWithoutResponse) {
          try {
            await c.write(data, withoutResponse: true);
          } catch (e2) {
            debugPrint("sendDataV2 retry (withoutResponse=true) failed: $e2");
          }
        }
      }
    } else {
      debugPrint("Attempted to send V2 data but _writeCharV2 is null");
    }
  }

  /// Indicates whether the currently connected hardware supports the advanced V2 communication pipeline.
  bool get hasV2Service => _writeCharV2 != null;
}
