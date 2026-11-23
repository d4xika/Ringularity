import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ringularity/services/user/storage_service.dart';

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

  /// Separates V2 fragments from simultaneous UART sensor notifications.
  final void Function(List<int>)? onBigDataReceived;

  /// Creates a new [BleConnectionManager] instance.
  BleConnectionManager({
    required this.logger,
    required this.onDataReceived,
    this.onBigDataReceived,
  });

  int _generation = 0;
  AccountSession? _owner;
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? _connectingDevice;
  Future<void>? _connecting;
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
    final prefs = await AccountPreferences.getInstance();
    _lastDeviceId = prefs.getString('last_device_id');
    if (_lastDeviceId != null) {
      debugPrint("Loaded Last Device ID: $_lastDeviceId");
    }
  }

  /// Caches a successful connection ID into local storage.
  Future<void> saveLastDeviceId(String id) async {
    final owner = StorageService.requireSession();
    final prefs = await AccountPreferences.getInstance();
    await prefs.setString('last_device_id', id);
    owner.check();
    _lastDeviceId = id;
    debugPrint("Saved Last Device ID: $id");
  }

  /// Wipes the cached connection ID (used during unpairing).
  Future<void> clearLastDeviceId() async {
    final owner = StorageService.requireSession();
    final prefs = await AccountPreferences.getInstance();
    await prefs.remove('last_device_id');
    owner.check();
    _lastDeviceId = null;
    debugPrint("Cleared Last Device ID");
  }

  /// Initiates the connection sequence for a target [device], handling OS-specific quirks.
  Future<void> connectToDevice(BluetoothDevice device) {
    final result = _connectToDevice(device);
    _connecting = result;
    return result.whenComplete(() {
      if (identical(_connecting, result)) {
        _connecting = null;
      }
    });
  }

  /// Connects and discovers channels for one account and connection generation.
  /// A superseded attempt disconnects instead of publishing a stale connection.
  Future<void> _connectToDevice(BluetoothDevice device) async {
    final owner = StorageService.requireSession();
    final generation = ++_generation;
    _owner = owner;
    _connectingDevice = device;
    _status = "Connecting to ${device.platformName}...";
    notifyListeners();

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      if (!owner.isCurrent || generation != _generation) {
        await device.disconnect();
        throw SessionExpired();
      }
      _connectedDevice = device;

      _connectionStateSubscription = device.connectionState.listen((state) {
        if (generation != _generation || !owner.isCurrent) {
          return;
        }
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

      owner.check();
      if (generation != _generation) {
        throw SessionExpired();
      }
      await _discoverServices(device, generation, owner);

      debugPrint("Waiting 2s for ring to settle...");
      await Future.delayed(const Duration(seconds: 2));

      owner.check();
      if (generation != _generation) {
        throw SessionExpired();
      }
      _status = "Connected to ${device.platformName}";

      await saveLastDeviceId(device.remoteId.toString());

      notifyListeners();
    } catch (e) {
      if (!owner.isCurrent || generation != _generation) {
        rethrow;
      }
      _status = "Connection Failed: $e";
      _cleanup();
      notifyListeners();
      rethrow;
    }
  }

  /// Forgets the previous account’s remembered ring and waits for its connection to end.
  Future<void> resetAccount() {
    _lastDeviceId = null;
    return disconnect();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  /// Severs the active Bluetooth connection and clears all streams.
  Future<void> disconnect() async {
    final device = _connectedDevice ?? _connectingDevice;
    final connecting = _connecting;
    _cleanup();
    _status = 'Disconnected';
    notifyListeners();
    try {
      await device?.disconnect();
    } finally {
      await connecting?.catchError((Object _) {});
    }
  }

  /// Scans the connected peripheral for specific Service UUIDs to map the read/write channels.
  /// Falls back to generic channels if standard UART or Colmi endpoints are not found.
  Future<void> _discoverServices(
    BluetoothDevice device,
    int generation,
    AccountSession owner,
  ) async {
    final List<BluetoothService> services = await device.discoverServices();
    if (generation != _generation || !owner.isCurrent) {
      throw SessionExpired();
    }
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
      final characteristic = _notifyChar!;
      await _notifySubscription?.cancel();
      owner.check();
      if (generation != _generation) {
        throw SessionExpired();
      }
      await characteristic.setNotifyValue(true);
      owner.check();
      if (generation != _generation) {
        throw SessionExpired();
      }
      _notifySubscription = characteristic.onValueReceived.listen((data) {
        if (generation == _generation && owner.isCurrent) {
          _onInternalDataReceived(data);
        }
      });
    }

    if (_notifyCharV2 != null) {
      final characteristic = _notifyCharV2!;
      await _notifySubscriptionV2?.cancel();
      owner.check();
      if (generation != _generation) {
        throw SessionExpired();
      }
      await characteristic.setNotifyValue(true);
      owner.check();
      if (generation != _generation) {
        throw SessionExpired();
      }
      _notifySubscriptionV2 = characteristic.onValueReceived.listen((data) {
        if (generation == _generation && owner.isCurrent) {
          (onBigDataReceived ?? _onInternalDataReceived)(data);
        }
      });
    }
  }

  /// Bridges the incoming byte array from the BLE stream to the parent service.
  void _onInternalDataReceived(List<int> data) {
    onDataReceived(data);
  }

  /// Nullifies active connections and cancels subscriptions. Does not erase the logger.
  void _cleanup() {
    _generation++;
    _owner = null;
    _connectedDevice = null;
    _connectingDevice = null;
    _writeChar = null;
    _writeCharV2 = null;
    _notifyChar = null;
    _notifyCharV2 = null;
    _notifySubscription?.cancel();
    _notifySubscriptionV2?.cancel();
    _connectionStateSubscription?.cancel();
  }

  /// Dispatches a byte payload to the primary (V1) write characteristic of the ring.
  Future<void> sendData(List<int> data) async {
    await _write(_writeChar, data);
  }

  /// Dispatches a byte payload to the secondary channel and reports write failures.
  Future<void> sendDataV2(List<int> data) async {
    await _write(_writeCharV2, data);
  }

  /// Retries the supported write mode once and preserves the final transport error.
  Future<void> _write(
    BluetoothCharacteristic? characteristic,
    List<int> data,
  ) async {
    StorageService.requireSession();
    final owner = _owner;
    if (owner == null) {
      throw SessionExpired();
    }
    owner.check();
    if (characteristic == null) {
      throw StateError('Ring write characteristic is unavailable');
    }
    final withoutResponse =
        characteristic.properties.writeWithoutResponse &&
        !characteristic.properties.write;
    try {
      await characteristic.write(data, withoutResponse: withoutResponse);
    } catch (_) {
      owner.check();
      if (!withoutResponse && characteristic.properties.writeWithoutResponse) {
        await characteristic.write(data, withoutResponse: true);
      } else {
        rethrow;
      }
    }
  }

  /// Indicates whether the currently connected hardware supports the advanced V2 communication pipeline.
  bool get hasV2Service => _writeCharV2 != null;
}
