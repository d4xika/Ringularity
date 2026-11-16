import 'package:flutter/foundation.dart';
import '../user/storage_service.dart';

import 'ble_constants.dart';

/// An interface mapping parsed BLE data to concrete application events.
abstract class BleDataCallbacks {
  void onProtocolLog(String message);
  void onRawLog(String message);

  void onHeartRate(int bpm);
  void onStress(int level);
  void onHrv(int hrv);
  void onBattery(int level);

  void onHeartRateHistoryPoint(DateTime timestamp, int bpm);
  void onStressHistoryPoint(DateTime timestamp, int level);
  void onHrvHistoryPoint(DateTime timestamp, int val);
  void onSleepHistoryPoint(
    DateTime timestamp,
    int sleepStage, {
    int durationMinutes = 0,
  });
  void onSleepSyncComplete();
  void onStepsHistoryPoint(DateTime timestamp, int steps, int quarterIndex);

  void onRawAccel(List<int> data);
  void onRawPPG(List<int> data);

  void onAutoConfigRead(String type, bool enabled, {int interval = 0});

  void onNotification(int type);

  void onGoalsRead(int steps, int distance, int sport, int sleep);
  void onFindDevice();
  void onMeasurementError(int type, int errorCode);

  void onActivityUpdate({
    required int steps,
    required int bpm,
    required int distance,
    required int duration,
  });

  void onActivityPacketReceived();
}

/// A stateful parser that decodes raw byte streams from the smart ring into typed data structures.
///
/// Handles packet reassembly for segmented "Big Data" transfers (like multi-day sleep records)
/// and extracts binary-coded values based on the proprietary Colmi/Nordic hex protocol.
class BleDataProcessor {
  final BleDataCallbacks callbacks;

  /// Creates a new [BleDataProcessor] attached to a specific [callbacks] delegate.
  BleDataProcessor(this.callbacks);

  final List<int> _bigDataBuffer = [];
  int _bigDataExpectedLen = 0;
  bool _isReceivingBigData = false;

  final Map<int, _HistoryPackets> _history = {};
  final Map<int, List<int>> _stepRows = {};
  DateTime? _requestDate;
  DateTime _referenceDate = DateTime.now();
  int? _activeCommand;

  /// Called only after every indexed packet of the requested transfer was decoded.
  void Function(int command)? onHistoryComplete;

  /// Reports malformed or rejected transfers to the request coordinator.
  void Function(Object error)? onHistoryError;

  /// Starts a dated request with fresh buffers, independent of the displayed day.
  void beginHistoryRequest(int command, DateTime date, DateTime referenceDate) {
    _activeCommand = command;
    _requestDate = DateTime(date.year, date.month, date.day);
    _referenceDate = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    _history.clear();
    _stepRows.clear();
    _bigDataBuffer.clear();
    _isReceivingBigData = false;
  }

  /// Discards unfinished packet buffers after a timeout or disconnect.
  void cancelHistoryRequest() {
    _activeCommand = null;
    _requestDate = null;
    _history.clear();
    _stepRows.clear();
    _bigDataBuffer.clear();
    _isReceivingBigData = false;
  }

  /// Delivers a completion event only for the command currently being awaited.
  void _completeHistory(int command) {
    if (_activeCommand == command) {
      onHistoryComplete?.call(command);
    }
  }

  /// Processes only the indexed history frames whose checksum is intact.
  bool _validHistoryPacket(List<int> data) {
    if (data.length != 16 ||
        (data.take(15).fold<int>(0, (sum, byte) => sum + byte) & 0xff) !=
            data[15]) {
      onHistoryError?.call(const FormatException('Invalid BLE history frame'));
      return false;
    }
    return true;
  }

  /// Assembles indexed packets, rejecting gaps rather than silently shortening a day.
  List<List<int>>? _assembleHistory(List<int> data) {
    if (!_validHistoryPacket(data)) {
      return null;
    }
    final command = data[0];
    if (data[1] == 0xff) {
      _history.remove(command);
      _completeHistory(command);
      return null;
    }
    if (data[1] == 0) {
      if (data[2] > 1 && data[3] == 0) {
        onHistoryError?.call(
          const FormatException('Invalid history sampling interval'),
        );
        return null;
      }
      final transfer = _HistoryPackets(data[2], data[3]);
      _history[command] = transfer;
      if (transfer.count <= 1) {
        _completeHistory(command);
      }
      return null;
    }
    final transfer = _history[command];
    if (transfer == null || data[1] >= transfer.count) {
      return null;
    }
    final existing = transfer.packets[data[1]];
    if (existing != null && !listEquals(existing, data)) {
      onHistoryError?.call(
        const FormatException('Conflicting BLE history packet'),
      );
      return null;
    }
    transfer.packets[data[1]] = List.from(data);
    if (transfer.packets.length != transfer.count - 1) {
      return null;
    }
    return [for (var i = 1; i < transfer.count; i++) transfer.packets[i]!];
  }

  /// Primary entry point for incoming BLE data streams.
  /// Identifies command headers and routes data to specific packet parsers.
  Future<void> processData(List<int> data) async {
    final revision = StorageService.revision;
    if (data.isEmpty) {
      return;
    }
    if (!_isReceivingBigData &&
        data.length > 16 &&
        data.length % 16 == 0 &&
        {0x15, 0x37, 0x39, 0x43}.contains(data[0])) {
      for (var start = 0; start < data.length; start += 16) {
        if (revision != StorageService.revision) {
          return;
        }
        await _processCommand(data.sublist(start, start + 16));
      }
      return;
    }

    if (data[0] == BleConstants.cmdBigData || _isReceivingBigData) {
      if (_isReceivingBigData &&
          data.length == 16 &&
          data[0] != BleConstants.cmdBigData &&
          (data.take(15).fold<int>(0, (sum, byte) => sum + byte) & 0xff) ==
              data[15]) {
        await _processCommand(data);
        return;
      }
      processBigData(data, uart: true);
      return;
    }
    await _processCommand(data);
  }

  /// Reassembles the dedicated big-data channel without consuming UART notifications.
  void processBigData(List<int> data, {bool uart = false}) {
    _bigDataBuffer.addAll(data);
    _isReceivingBigData = uart;
    while (_bigDataBuffer.length >= 6) {
      if (_bigDataBuffer.first != BleConstants.cmdBigData) {
        _bigDataBuffer.clear();
        _isReceivingBigData = false;
        onHistoryError?.call(const FormatException('Invalid big-data header'));
        return;
      }
      _bigDataExpectedLen = 6 + _bigDataBuffer[2] + (_bigDataBuffer[3] << 8);
      if (_bigDataBuffer.length < _bigDataExpectedLen) {
        return;
      }
      final frame = _bigDataBuffer.sublist(0, _bigDataExpectedLen);
      _bigDataBuffer.removeRange(0, _bigDataExpectedLen);
      _handleBigData(frame);
    }
    _isReceivingBigData = uart && _bigDataBuffer.isNotEmpty;
  }

  /// Dispatches a complete UART frame while other channels may be receiving data.
  Future<void> _processCommand(List<int> data) async {
    if (_activeCommand != null &&
        data[0] == (_activeCommand! | 0x80) &&
        _activeCommand != BleConstants.cmdBigData) {
      onHistoryError?.call(
        StateError(
          'Ring rejected history command ${_activeCommand!.toRadixString(16)}',
        ),
      );
      return;
    }
    if (_activeCommand != null &&
        data[0] != _activeCommand &&
        {
          BleConstants.cmdGetHeartRateLog,
          BleConstants.cmdStressSync,
          BleConstants.cmdHrvSync,
          BleConstants.cmdGetStepsLog,
        }.contains(data[0])) {
      return;
    }
    final String hexData = data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    callbacks.onRawLog("RX: $hexData");

    final int cmd = data[0];

    if (cmd == BleConstants.cmdRawData && data.length > 2) {
      _handleRawData(data);
      return;
    }

    switch (cmd) {
      case BleConstants.cmdRealTimeMeasure:
        _handleRealTimeMeasure(data);
        break;

      case BleConstants.cmdNotify:
        if (data.length > 1) {
          _handleNotification(data[1], data);
        }
        break;

      case BleConstants.cmdGetHeartRateLog:
        _handleHeartRateLog(data);
        break;

      case BleConstants.cmdGetStepsLog:
        _handleStepsLog(data);
        break;

      case BleConstants.cmdBigData:
        _handleBigData(data);
        break;

      case BleConstants.cmdStressSync:
        _handleStressHistory(data);
        break;

      case BleConstants.cmdStressConfig:
        _handleStressConfigOrData(data);
        break;

      case BleConstants.cmdGetBattery:
        if (data.length > 1) callbacks.onBattery(data[1]);
        break;

      case BleConstants.cmdHrvConfig:
        if (data.length > 2 && (data[1] == 0x01 || data[1] == 0x02)) {
          callbacks.onAutoConfigRead("HRV", data[2] != 0);
        }
        break;

      case BleConstants.cmdHrvSync:
        _handleHrvHistory(data);
        break;

      case BleConstants.cmdGetSleepLog:
        _handleSleepLog(data);
        break;

      case BleConstants.cmdSetGoals:
        _handleGoals(data);
        break;

      case BleConstants.cmdFindDevice:
        _handleFindDevice(data);
        break;

      case BleConstants.cmdActivityData:
        _handleActivityData(data);
        break;

      case 0x77:
        final String hex = data
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        callbacks.onProtocolLog("Activity Data (0x77): $hex");
        _handleActivityData(data);
        break;

      case 0x48:
        _handleRealTimeHealthData(data);
        break;

      default:
        final String hex = data
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        callbacks.onProtocolLog(
          "Unknown Command (${cmd.toRadixString(16)}): $hex",
        );
        break;
    }
  }

  void _handleRawData(List<int> data) {
    final int subType = data[1];
    if (subType == 0x03) {
      callbacks.onRawAccel(data);
    } else if (subType == 0x01 || subType == 0x02) {
      callbacks.onRawPPG(data);
    }
  }

  void _handleRealTimeMeasure(List<int> data) {
    if (data.length < 3) return;
    final int type = data[1];

    final int status = data[2];

    if (status != 0) {
      callbacks.onProtocolLog(
        "Realtime Measure Error: Type=$type Status=$status",
      );
      callbacks.onMeasurementError(type, status);
      return;
    }

    if (data.length > 3) {
      final int val = data[3];
      if (val > 0) {
        if (type == BleConstants.typeHeartRate) {
          callbacks.onHeartRate(val);
        } else if (type == BleConstants.typeStress) {
          callbacks.onStress(val);
        } else if (type == BleConstants.typeHrv) {
          callbacks.onHrv(val);
        }
      }
    }
  }

  /// Decodes byte-sized heart-rate samples only after all advertised packets arrive.
  void _handleHeartRateLog(List<int> data) {
    final packets = _assembleHistory(data);
    if (packets == null) {
      return;
    }
    final first = packets.first;
    final timestamp =
        first[2] | (first[3] << 8) | (first[4] << 16) | (first[5] << 24);
    final wall = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    );
    final day = DateTime(wall.year, wall.month, wall.day);
    if (_requestDate != null && day != _requestDate) {
      onHistoryError?.call(
        const FormatException('Heart-rate response belongs to a different day'),
      );
      return;
    }
    final samples = [
      ...first.sublist(6, 15),
      for (final packet in packets.skip(1)) ...packet.sublist(2, 15),
    ];
    final interval = _history[data[0]]!.interval;
    final now = DateTime.now();
    for (var i = 0; i < samples.length && i * interval < 1440; i++) {
      final value = samples[i];
      final time = DateTime(day.year, day.month, day.day, 0, i * interval);
      if (value >= 30 && value <= 220 && !time.isAfter(now)) {
        callbacks.onHeartRateHistoryPoint(time, value);
      }
    }
    _history.remove(data[0]);
    _completeHistory(data[0]);
  }

  /// Unpacks a buffered 0xBC payload containing complex, multi-day structural data (e.g., Sleep block history).
  void _handleBigData(List<int> data) {
    if (data.length < 6 || data[1] != BleConstants.subSleepBigData) {
      return;
    }
    if (data.length == 6) {
      callbacks.onSleepSyncComplete();
      _completeHistory(BleConstants.cmdBigData);
      return;
    }
    final records = <(DateTime, int, int)>[];
    final days = data[6];
    var offset = 7;
    for (var i = 0; i < days; i++) {
      if (offset + 6 > data.length) {
        onHistoryError?.call(const FormatException('Incomplete sleep day'));
        return;
      }
      final daysAgo = data[offset];
      final length = data[offset + 1];
      final end = offset + 2 + length;
      if (length < 4 || length.isOdd || end > data.length) {
        onHistoryError?.call(const FormatException('Incomplete sleep stages'));
        return;
      }
      final startMinutes = (data[offset + 2] | (data[offset + 3] << 8))
          .toSigned(16);
      final endMinutes = (data[offset + 4] | (data[offset + 5] << 8)).toSigned(
        16,
      );
      final reference = _activeCommand == null
          ? DateTime.now()
          : _referenceDate;
      var time = DateTime(
        reference.year,
        reference.month,
        reference.day - daysAgo,
        0,
        startMinutes,
      );
      if (startMinutes > endMinutes) {
        time = DateTime(
          time.year,
          time.month,
          time.day - 1,
          time.hour,
          time.minute,
        );
      }
      for (var j = offset + 6; j < end; j += 2) {
        records.add((time, data[j], data[j + 1]));
        time = time.add(Duration(minutes: data[j + 1]));
      }
      offset = end;
    }
    for (final (time, stage, duration) in records) {
      callbacks.onSleepHistoryPoint(time, stage, durationMinutes: duration);
    }
    callbacks.onSleepSyncComplete();
    _completeHistory(BleConstants.cmdBigData);
  }

  void _handleNotification(int type, List<int> data) {
    if (type == 0xBC) {
      _handleBigData(data);
    } else if (type == 0x77) {
      _handleActivityData(data);
    } else if (type == 0x21) {
      _handleGoals(data);
    } else if (type == 0x43) {
      _handleStepsLog(data);
    } else if (type == 0x37) {
      _handleStressHistory(data);
    } else if (type == 0x39) {
      _handleHrvHistory(data);
    } else if (type == 0x36) {
      _handleStressConfigOrData(data);
    } else if (type == 0x22) {
      _handleFindDevice(data);
    } else if (type == 0x11) {
      if (data.length > 2) {}
    } else if (type == 0x10) {
      if (data.length > 2) {}
    } else if (type == 0x12) {
      if (data.length > 5) {
        final int totalSteps = (data[3] << 8) | data[4];
        debugPrint("DEBUG: Parsed Steps from Notif 12: $totalSteps");

        callbacks.onActivityUpdate(
          steps: totalSteps,
          bpm: 0,
          distance: 0,
          duration: 0,
        );
      }
    }

    callbacks.onNotification(type);
  }

  void _handleActivityData(List<int> data) {
    debugPrint("DEBUG: _handleActivityData called with ${data.length} bytes");
    callbacks.onActivityPacketReceived();

    int bpm = 0;
    if (data.length > 6) {
      if (data[6] > 30 && data[6] < 220) bpm = data[6];
    }
    debugPrint("DEBUG: Parsed BPM from 0x77: $bpm");

    if (bpm > 0) callbacks.onHeartRate(bpm);
  }

  void _handleGoals(List<int> data) {
    final String hex = data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    callbacks.onProtocolLog("Goals Packet (0x21): $hex");

    if (data.length < 11) return;

    final int steps = data[2] | (data[3] << 8) | (data[4] << 16);
    final int distance = data[8] | (data[9] << 8) | (data[10] << 16);

    final int sport = 0;
    final int sleep = 0;

    callbacks.onGoalsRead(steps, distance, sport, sleep);
  }

  void _handleFindDevice(List<int> data) {
    callbacks.onFindDevice();
  }

  /// Uses dated step rows and row counts to confirm the complete daily transfer.
  void _handleStepsLog(List<int> data) {
    if (!_validHistoryPacket(data)) {
      return;
    }
    if (data[1] == 0xff) {
      _completeHistory(BleConstants.cmdGetStepsLog);
      return;
    }
    if (data[1] == 0xf0) {
      _stepRows.clear();
      return;
    }
    int bcd(int value) => (value >> 4) * 10 + (value & 15);
    final date = DateTime(2000 + bcd(data[1]), bcd(data[2]), bcd(data[3]));
    if (_requestDate != null && date != _requestDate) {
      return;
    }
    if (data[4] >= 96 || data[6] == 0 || data[5] >= data[6]) {
      onHistoryError?.call(const FormatException('Invalid step history row'));
      return;
    }
    final existing = _stepRows[data[5]];
    if (existing != null && !listEquals(existing, data)) {
      onHistoryError?.call(
        const FormatException('Conflicting step history row'),
      );
      return;
    }
    _stepRows[data[5]] = List.from(data);
    if (_stepRows.length != data[6]) {
      return;
    }
    for (var i = 0; i < data[6]; i++) {
      final row = _stepRows[i];
      if (row == null || row[6] != data[6]) {
        onHistoryError?.call(const FormatException('Missing step history row'));
        return;
      }
    }
    for (final row in _stepRows.values) {
      callbacks.onStepsHistoryPoint(
        DateTime(date.year, date.month, date.day, 0, row[4] * 15),
        row[9] | (row[10] << 8),
        row[4],
      );
    }
    _stepRows.clear();
    _completeHistory(BleConstants.cmdGetStepsLog);
  }

  /// Decodes dated stress slots using the response header's sampling interval.
  void _handleStressHistory(List<int> data) => _handleDatedHistory(data, false);

  /// Decodes little-endian HRV samples, including pairs split across BLE packets.
  void _handleHrvHistory(List<int> data) => _handleDatedHistory(data, true);

  /// Reassembles the echoed day offset and samples before assigning timestamps.
  void _handleDatedHistory(List<int> data, bool hrv) {
    final packets = _assembleHistory(data);
    if (packets == null) {
      return;
    }
    final bytes = [for (final packet in packets) ...packet.sublist(2, 15)];
    final reference = _activeCommand == null ? DateTime.now() : _referenceDate;
    final day = DateTime(
      reference.year,
      reference.month,
      reference.day - bytes.first,
    );
    if (_requestDate != null && day != _requestDate) {
      onHistoryError?.call(
        const FormatException('History response belongs to a different day'),
      );
      return;
    }
    final interval = _history[data[0]]!.interval;
    final width = hrv ? 2 : 1;
    final now = DateTime.now();
    for (var i = 1; i + width <= bytes.length; i += width) {
      final minutes = ((i - 1) ~/ width) * interval;
      if (minutes >= 1440) {
        break;
      }
      final value = hrv ? bytes[i] | (bytes[i + 1] << 8) : bytes[i];
      final time = DateTime(day.year, day.month, day.day, 0, minutes);
      if (value > 0 &&
          (hrv ? value != 0xffff : value <= 100) &&
          !time.isAfter(now)) {
        if (hrv) {
          callbacks.onHrvHistoryPoint(time, value);
        } else {
          callbacks.onStressHistoryPoint(time, value);
        }
      }
    }
    _history.remove(data[0]);
    _completeHistory(data[0]);
  }

  void _handleStressConfigOrData(List<int> data) {
    if (data.length > 2 && data[1] == 0x01) {
      final bool enabled = (data[2] != 0);
      callbacks.onAutoConfigRead("Stress", enabled);
    }
  }

  /// Applies the same complete-day validation to legacy sleep responses.
  void _handleSleepLog(List<int> data) {
    if (data.length < 7) {
      onHistoryError?.call(
        const FormatException('Incomplete legacy sleep header'),
      );
      return;
    }
    var days = data[6];
    var offset = 7;
    if (days == 0 && data[2] > 0 && data[2] < 10) {
      days = data[2];
      offset = 4;
    }
    final payload = [days, ...data.skip(offset)];
    _handleBigData([
      0xbc,
      0x27,
      payload.length & 255,
      payload.length >> 8,
      0,
      0,
      ...payload,
    ]);
  }

  void _handleRealTimeHealthData(List<int> data) {
    if (data.length >= 13) {
      int bpm = data[12];

      if (bpm < 30 || bpm > 220) {
        bpm = data[3];
      }

      if (bpm > 40 && bpm < 220 && bpm != 105) {
        debugPrint("COLMI R10 Heartrate: $bpm bpm");
        callbacks.onHeartRate(bpm);
      }
    }
  }
}

/// Tracks advertised packet counts and deduplicates indexed UART payloads.
class _HistoryPackets {
  final int count;
  final int interval;
  final Map<int, List<int>> packets = {};

  _HistoryPackets(this.count, this.interval);
}
