import 'package:flutter/foundation.dart';

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

  List<int> _bigDataBuffer = [];
  int _bigDataExpectedLen = 0;
  bool _isReceivingBigData = false;

  int _hrLogInterval = 5;
  int _hrLogBaseTime = 0;
  int _hrLogCount = 0;

  /// Primary entry point for incoming BLE data streams.
  /// Identifies command headers and routes data to specific packet parsers.
  Future<void> processData(List<int> data) async {
    if (data.isEmpty) return;

    if (_isReceivingBigData) {
      _bigDataBuffer.addAll(data);
      callbacks.onProtocolLog(
        "Buffering Big Data... ${_bigDataBuffer.length}/$_bigDataExpectedLen",
      );

      if (_bigDataBuffer.length >= _bigDataExpectedLen) {
        final List<int> fullPacket = List.from(_bigDataBuffer);
        _isReceivingBigData = false;
        _bigDataBuffer.clear();
        _bigDataExpectedLen = 0;
        await processData(fullPacket);
      }
      return;
    }

    if (data[0] == BleConstants.cmdBigData && data.length >= 4) {
      final int lenL = data[2];
      final int lenH = data[3];
      final int payloadLen = lenL | (lenH << 8);
      final int totalExpected = payloadLen + 6;

      if (data.length < totalExpected) {
        callbacks.onProtocolLog(
          "Start Buffering Big Data (0xBC): Need $totalExpected bytes",
        );
        _isReceivingBigData = true;
        _bigDataExpectedLen = totalExpected;
        _bigDataBuffer = List.from(data);
        return;
      }
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

  void _handleHeartRateLog(List<int> data) {
    if (data.length < 2) return;
    final int subType = data[1];
    if (subType == 0xFF) return;

    if (subType == 0) {
      if (data.length > 3) _hrLogInterval = data[3];
      if (_hrLogInterval <= 0) _hrLogInterval = 5;
    } else if (subType == 1) {
      if (data.length >= 6) {
        final int t0 = data[2];
        final int t1 = data[3];
        final int t2 = data[4];
        final int t3 = data[5];
        _hrLogBaseTime = t0 | (t1 << 8) | (t2 << 16) | (t3 << 24);
        _hrLogCount = 0;

        _parseHrParams(data, 6, 9);
      }
    } else {
      _parseHrParams(data, 2, 13);
    }
  }

  /// Extracts sequential 16-bit little-endian heart rate readings from a payload chunk.
  void _parseHrParams(List<int> data, int startIndex, int limit) {
    final int end = startIndex + limit;
    int i = startIndex;
    while (i < data.length - 1 && i < end) {
      final int low = data[i];
      final int high = (i + 1 < data.length) ? data[i + 1] : 0;
      final int val = low | (high << 8);

      if (val > 0 && val != 0xFFFF && val >= 30 && val <= 220) {
        _emitHrPoint(val);
      }

      _hrLogCount++;
      i += 2;
    }
  }

  void _emitHrPoint(int val) {
    if (_hrLogBaseTime == 0) return;
    final int sec = _hrLogBaseTime + (_hrLogCount * _hrLogInterval * 60);
    final DateTime utcDt = DateTime.fromMillisecondsSinceEpoch(
      sec * 1000,
      isUtc: true,
    );
    final DateTime dt = DateTime(
      utcDt.year,
      utcDt.month,
      utcDt.day,
      utcDt.hour,
      utcDt.minute,
      utcDt.second,
    );
    callbacks.onHeartRateHistoryPoint(dt, val);
  }

  /// Unpacks a buffered 0xBC payload containing complex, multi-day structural data (e.g., Sleep block history).
  void _handleBigData(List<int> data) {
    if (data.length < 2) return;
    final int sub = data[1];

    if (sub == BleConstants.subSleepBigData) {
      if (data.length < 7) return;
      final int daysInPacket = data[6];
      int index = 7;
      callbacks.onProtocolLog(
        "Parsing Sleep BigData (0xBC): Days=$daysInPacket",
      );

      for (int i = 0; i < daysInPacket; i++) {
        if (index >= data.length) break;

        if (index + 6 > data.length) break;

        final int startOfChunk = index;
        final int daysAgo = data[index];
        final int dayBytes = data[index + 1];

        final int sleepStartMins = (data[index + 2] | (data[index + 3] << 8))
            .toSigned(16);
        final int sleepEndMins = (data[index + 4] | (data[index + 5] << 8))
            .toSigned(16);

        final DateTime now = DateTime.now();
        final DateTime baseDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysAgo));

        DateTime sessionStart = baseDate.add(Duration(minutes: sleepStartMins));

        if (sleepStartMins > sleepEndMins) {
          sessionStart = sessionStart.subtract(const Duration(days: 1));
        }

        callbacks.onProtocolLog(
          "Sleep Session: Start=${sessionStart.toString()} Mins=$sleepStartMins->$sleepEndMins",
        );

        final int stageDataStart = index + 6;
        int stagesLength = dayBytes - 4;

        DateTime stageTime = sessionStart;

        if (stageDataStart + stagesLength > data.length) {
          stagesLength = data.length - stageDataStart;
        }

        for (int k = 0; k < stagesLength; k += 2) {
          if (stageDataStart + k + 1 >= data.length) break;

          final int type = data[stageDataStart + k];
          final int duration = data[stageDataStart + k + 1];

          callbacks.onSleepHistoryPoint(
            stageTime,
            type,
            durationMinutes: duration,
          );

          stageTime = stageTime.add(Duration(minutes: duration));
        }
        callbacks.onSleepSyncComplete();

        index = startOfChunk + 2 + dayBytes;
      }
    } else {
      callbacks.onProtocolLog(
        "Unknown Big Data Subtype: ${sub.toRadixString(16)}",
      );
    }
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

  void _handleStepsLog(List<int> data) {
    if (data.length < 13) return;
    if (data[1] == 0xF0) {
      return;
    }

    final int y = int.tryParse(data[1].toRadixString(16)) ?? 0;
    final int year = 2000 + y;
    final int month = int.tryParse(data[2].toRadixString(16)) ?? 1;
    final int day = int.tryParse(data[3].toRadixString(16)) ?? 1;
    final int qIdx = data[4];

    if (data.length > 10) {
      final int steps = data[9] | (data[10] << 8);
      if (steps > 0) {
        final int mins = qIdx * 15;
        final DateTime dt = DateTime(
          year,
          month,
          day,
        ).add(Duration(minutes: mins));
        callbacks.onStepsHistoryPoint(dt, steps, qIdx);
      }
    }
  }

  void _handleStressHistory(List<int> data) {
    callbacks.onProtocolLog(
      "Handling Stress History (0x37): ${data.length} bytes",
    );
    if (data.length < 2) return;
    final int pIdx = data[1];
    if (pIdx == 0xFF) return;
    if (pIdx == 0) return;

    final int startIdx = (pIdx == 1) ? 3 : 2;
    final DateTime today = DateTime.now();

    int minsOffset = 0;
    if (pIdx > 1) {
      minsOffset = 12 * 30 + (pIdx - 2) * 13 * 30;
    }

    for (int i = startIdx; i < data.length - 1; i++) {
      final int val = data[i];
      if (val > 0) {
        final int minOfDay = minsOffset + (i - startIdx) * 30;
        int h = minOfDay ~/ 60;
        int m = minOfDay % 60;
        if (h >= 24) {
          h = 23;
          m = 59;
        }
        final DateTime dt = DateTime(today.year, today.month, today.day, h, m);
        callbacks.onStressHistoryPoint(dt, val);
      }
    }
  }

  void _handleHrvHistory(List<int> data) {
    if (data.length < 2) return;
    final int pIdx = data[1];

    if (pIdx == 0xFF) return;
    if (pIdx == 0) return;

    int startIdx = (pIdx == 0) ? 2 : (pIdx == 1 ? 3 : 2);

    if (pIdx == 1) {
      startIdx = 3;
    } else {
      startIdx = 2;
    }

    final DateTime today = DateTime.now();

    int minsOffset = 0;
    if (pIdx > 1) {
      minsOffset = 12 * 30 + (pIdx - 2) * 13 * 30;
    }

    for (int i = startIdx; i < data.length - 1; i++) {
      final int val = data[i];
      if (val > 0) {
        final int minOfDay = minsOffset + (i - startIdx) * 30;
        final int h = minOfDay ~/ 60;
        final int m = minOfDay % 60;
        final DateTime dt = DateTime(today.year, today.month, today.day, h, m);
        callbacks.onHrvHistoryPoint(dt, val);
      }
    }
  }

  void _handleStressConfigOrData(List<int> data) {
    if (data.length > 2 && data[1] == 0x01) {
      final bool enabled = (data[2] != 0);
      callbacks.onAutoConfigRead("Stress", enabled);
    }
  }

  void _handleSleepLog(List<int> data) {
    final String hex = data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    callbacks.onProtocolLog("Sleep Packet (0x7A): $hex");

    if (data.length < 7) return;

    int daysInPacket = data[6];
    int index = 7;

    if (daysInPacket == 0 && data.length > 4 && data[2] > 0 && data[2] < 10) {
      daysInPacket = data[2];
      index = 4;
      callbacks.onProtocolLog(
        "Sleep Packet (0x7A): Detected Short Header. Days=$daysInPacket",
      );
    }

    for (int i = 0; i < daysInPacket; i++) {
      if (index + 6 >= data.length) break;

      final int daysAgo = data[index];
      final int dayBytes = data[index + 1];

      final int sleepStartMins = data[index + 2] | (data[index + 3] << 8);
      final int sleepEndMins = data[index + 4] | (data[index + 5] << 8);

      final DateTime now = DateTime.now();
      final DateTime targetDate = now.subtract(Duration(days: daysAgo));

      DateTime sessionStart = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        0,
        0,
      ).add(Duration(minutes: sleepStartMins));

      if (sleepStartMins > sleepEndMins) {
        sessionStart = sessionStart.subtract(const Duration(days: 1));
      }

      index += 6;

      int bytesRead = 4;
      while (bytesRead < dayBytes) {
        if (index + 1 >= data.length) break;

        final int type = data[index];
        final int duration = data[index + 1];

        callbacks.onSleepHistoryPoint(
          sessionStart,
          type,
          durationMinutes: duration,
        );

        sessionStart = sessionStart.add(Duration(minutes: duration));

        index += 2;
        bytesRead += 2;
      }
    }
    callbacks.onSleepSyncComplete();
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
