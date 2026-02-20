import 'package:flutter/foundation.dart';

import 'ble_constants.dart';

/// Callback interface for parsed data events
abstract class BleDataCallbacks {
  void onProtocolLog(String message);
  void onRawLog(String message);

  void onHeartRate(int bpm);
  void onSpo2(int percent);
  void onStress(int level);
  void onHrv(int hrv);
  void onBattery(int level);

  void onHeartRateHistoryPoint(DateTime timestamp, int bpm);
  void onSpo2HistoryPoint(DateTime timestamp, int percent);
  void onStressHistoryPoint(DateTime timestamp, int level);
  void onHrvHistoryPoint(DateTime timestamp, int val);
  void onSleepHistoryPoint(
    DateTime timestamp,
    int sleepStage, {
    int durationMinutes = 0,
  });
  void onStepsHistoryPoint(DateTime timestamp, int steps, int quarterIndex);

  void onRawAccel(List<int> data);
  void onRawPPG(List<int> data);

  void onAutoConfigRead(
    String type,
    bool enabled, {
    int interval = 0,
  }); // Type: HR, SpO2, etc.

  void onNotification(int type);

  void onGoalsRead(int steps, int calories, int distance, int sport, int sleep);
  void onFindDevice();
  void onMeasurementError(int type, int errorCode);

  void onActivityUpdate({
    required int steps,
    required int bpm,
    required int calories,
    required int distance,
    required int duration,
  });

  void onActivityPacketReceived(); // New callback for raw packet detection
}

class BleDataProcessor {
  final BleDataCallbacks callbacks;

  BleDataProcessor(this.callbacks);

  // Big Data State (Received in chunks, needs reassembly)
  // 0xBC (Big Data) packets are often split into multiple BLE notifications.
  List<int> _bigDataBuffer = [];
  int _bigDataExpectedLen = 0;
  bool _isReceivingBigData = false;
  int _lastBigDataType = 0;

  // History Parsing State
  int _hrLogInterval = 5;
  int _hrLogBaseTime = 0;
  int _hrLogCount = 0;

  final int _spo2LogInterval = 5;
  int _spo2LogBaseTime = 0;
  int _spo2LogCount = 0;

  bool spo2DataReceived = false; // Track if we got any 0xBC data

  Future<void> processData(List<int> data) async {
    if (data.isEmpty) return;

    // If we are in the middle of receiving a large packet, append data to buffer.
    if (_isReceivingBigData) {
      _bigDataBuffer.addAll(data);
      callbacks.onProtocolLog(
        "Buffering Big Data... ${_bigDataBuffer.length}/$_bigDataExpectedLen",
      );

      // Check if we have received the full payload
      if (_bigDataBuffer.length >= _bigDataExpectedLen) {
        final List<int> fullPacket = List.from(_bigDataBuffer);
        _isReceivingBigData = false;
        _bigDataBuffer.clear();
        _bigDataExpectedLen = 0;
        await processData(fullPacket); // Recursive process on the full packet
      }
      return;
    }

    // Start of Big Data Packet (0xBC)
    // Check if the packet length indicator implies more data is coming than what's in this current BLE frame.
    if (data[0] == BleConstants.cmdBigData && data.length >= 4) {
      final int lenL = data[2];
      final int lenH = data[3];
      final int payloadLen = lenL | (lenH << 8);
      final int totalExpected = payloadLen + 6;

      if (data.length < totalExpected) {
        // Start buffering if current data is partial
        callbacks.onProtocolLog(
          "Start Buffering Big Data (0xBC): Need $totalExpected bytes",
        );
        _isReceivingBigData = true;
        _bigDataExpectedLen = totalExpected;
        _bigDataBuffer = List.from(data);
        return;
      }
      // Else we have full packet immediately, continue processing below
    }

    final String hexData = data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    callbacks.onRawLog("RX: $hexData");

    final int cmd = data[0];

    if (data.length >= 6 && cmd != 0x77 && cmd != BleConstants.cmdNotify) {
      int possibleHr = 0;

      if (data.length >= 13 &&
          data[12] > 30 &&
          data[12] < 220 &&
          data[12] != 105) {
        possibleHr = data[12];
      } else if (data.length >= 7 &&
          data[6] > 30 &&
          data[6] < 220 &&
          data[6] != 105) {
        possibleHr = data[6];
      } else if (data.length >= 4 &&
          data[3] > 30 &&
          data[3] < 220 &&
          data[3] != 105) {
        possibleHr = data[3];
      }

      if (possibleHr > 0) {
        debugPrint(
          "Found Heart Rate in cmd 0x${cmd.toRadixString(16)}: $possibleHr bpm",
        );
        callbacks.onHeartRate(possibleHr);
      }
    }
    // ----------------------------------------------------

    // Handling 0xA1 specially (sometimes 3 byte header?)
    if (cmd == BleConstants.cmdRawData && data.length > 2) {
      // Logically handled same as others but payload structure differs
      _handleRawData(data);
      return;
    }

    switch (cmd) {
      case BleConstants.cmdRealTimeMeasure: // 0x69
        _handleRealTimeMeasure(data);
        break;

      case BleConstants.cmdNotify: // 0x73
        if (data.length > 1) {
          _handleNotification(data[1], data);
        }
        break;

      case BleConstants.cmdGetHeartRateLog: // 0x15
        _handleHeartRateLog(data);
        break;

      case BleConstants.cmdGetSpo2Log: // 0x16 - OR HR Auto Config
        _handleSpo2OrConfig(data);
        break;

      case BleConstants.cmdGetStepsLog: // 0x43
        _handleStepsLog(data);
        break;

      case BleConstants.cmdBigData: // 0xBC
        _handleBigData(data);
        break;

      case BleConstants.cmdStressSync: // 0x37
        _handleStressHistory(data);
        break;

      case BleConstants.cmdStressConfig: // 0x36
        _handleStressConfigOrData(data);
        break;

      case BleConstants.cmdGetBattery: // 0x03
        if (data.length > 1) callbacks.onBattery(data[1]);
        break;

      case BleConstants.cmdSpo2AutoConfig: // 0x2C
        if (data.length > 2 && (data[1] == 0x01 || data[1] == 0x02)) {
          callbacks.onAutoConfigRead("SpO2", data[2] != 0);
        }
        break;

      case BleConstants.cmdHrvConfig: // 0x38
        if (data.length > 2 && (data[1] == 0x01 || data[1] == 0x02)) {
          callbacks.onAutoConfigRead("HRV", data[2] != 0);
        }
        break;

      case BleConstants.cmdHrvSync: // 0x39
        _handleHrvHistory(data);
        break;

      case BleConstants.cmdGetSleepLog: // 0x7A
        _handleSleepLog(data);
        break;

      case BleConstants.cmdSetGoals: // 0x21
        _handleGoals(data);
        break;

      case BleConstants.cmdFindDevice: // 0x50
        _handleFindDevice(data);
        break;

      case BleConstants.cmdActivityData: // 0x78
        _handleActivityData(data);
        break;

      case 0x77: // Activity Control / Data
        // Log raw data for analysis
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
        // Log unknown commands
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
    // 0xA1 <Type> ...
    // Raw sensor streams (PPG, Accel) often come with 0xA1 header.
    final int subType = data[1];
    if (subType == 0x03) {
      callbacks.onRawAccel(data);
    } else if (subType == 0x01 || subType == 0x02) {
      callbacks.onRawPPG(data);
    }
  }

  void _handleRealTimeMeasure(List<int> data) {
    // 69 <Type> <Status> <Val>
    if (data.length < 3) return;
    final int type = data[1];

    // Status is at index 2
    final int status = data[2];

    if (status != 0) {
      callbacks.onProtocolLog(
        "Realtime Measure Error: Type=$type Status=$status",
      );
      callbacks.onMeasurementError(type, status);
      return;
    }

    // Value is at index 3
    if (data.length > 3) {
      final int val = data[3];
      if (val > 0) {
        if (type == BleConstants.typeHeartRate)
          callbacks.onHeartRate(val);
        else if (type == BleConstants.typeSpo2)
          callbacks.onSpo2(val);
        else if (type == BleConstants.typeStress)
          callbacks.onStress(val);
        else if (type == BleConstants.typeHrv)
          callbacks.onHrv(val);
      }
    }
  }

  void _handleHeartRateLog(List<int> data) {
    // 0x15 ...
    if (data.length < 2) return;
    final int subType = data[1];
    if (subType == 0xFF) return; // End

    if (subType == 0) {
      // Start: [15, 00, 18?, 05(Interval), ...]
      if (data.length > 3) _hrLogInterval = data[3];
      if (_hrLogInterval <= 0) _hrLogInterval = 5;
    } else if (subType == 1) {
      // Timestamp
      if (data.length >= 6) {
        final int t0 = data[2];
        final int t1 = data[3];
        final int t2 = data[4];
        final int t3 = data[5];
        _hrLogBaseTime = t0 | (t1 << 8) | (t2 << 16) | (t3 << 24);
        _hrLogCount = 0;

        // Parse first batch in this packet
        _parseHrParams(data, 6, 9);
      }
    } else {
      // Data
      // Starts at index 2
      _parseHrParams(data, 2, 13);
    }
  }

  void _parseHrParams(List<int> data, int startIndex, int limit) {
    for (
      int i = startIndex;
      i < data.length - 1 && i < startIndex + limit;
      i++
    ) {
      final int val = data[i];
      if (val != 0 && val != 255) {
        _emitHrPoint(val);
      }
      _hrLogCount++;
    }
  }

  void _emitHrPoint(int val) {
    if (_hrLogBaseTime == 0) return;
    final int sec = _hrLogBaseTime + (_hrLogCount * _hrLogInterval * 60);
    // The device sends the timestamp as if it were UTC, but it actually represents Local Time components.
    // Example: 00:00 Device Time -> Sent as 00:00 UTC Timestamp.
    // If we just use fromMillisecondsSinceEpoch, it converts 00:00 UTC -> 01:00 Local (if +1).
    // So we first parse as UTC to get the "face value" components, then create a Local DateTime from them.
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

  void _handleSpo2OrConfig(List<int> data) {
    // 0x16 ...
    if (data.length < 3) return;
    final int b1 = data[1];
    final int b2 = data[2];

    // SpO2 Log: Key 0x03
    if (b2 == 0x03) {
      // Header: [16, Offset, 03, Start, Count?]
      // Just reset state
      // _spo2LogInterval = 5;
      return;
    }

    // Config Read: 16 01 [Times...] OR 16 02 [Status]
    // b1 can be 0x01 (Read/Set?) or 0x02 (Status Report).
    if (b1 == 0x01 || b1 == 0x02) {
      if (b2 != 0x03) {
        // Disambiguate from Data using Timestamp check (legacy logic)
        // If it's a short packet (<=5), it CANNOT be Data (needs 6 bytes to form timestamp).
        // If it's long (>5), check timestamp.

        bool isConfig = false;
        if (data.length <= 5) {
          isConfig = true;
        } else {
          final int t0 = data[2];
          final int timestamp =
              t0 | (data[3] << 8) | (data[4] << 16) | (data[5] << 24);
          if (timestamp < 1000000000) {
            isConfig = true;
          } else {
            // SpO2 Data Timestamp (Large)
            _spo2LogBaseTime = timestamp;
            _spo2LogCount = 0;
            _parseSpo2Params(data, 6, 9);
            return;
          }
        }

        if (isConfig) {
          final bool enabled = (data[2] != 0);
          int interval = 0;
          if (data.length > 3) {
            interval = data[3];
          }
          debugPrint(
            "Parsing HR Config (0x16): Sub=$b1 Enabled=$enabled Interval=$interval Packet=${data.length}",
          );
          callbacks.onAutoConfigRead("HR", enabled, interval: interval);
          return;
        }
      }
    }

    // Legacy/Data stream?
    // If we assume it falls through... logic in original was fuzzy.
  }

  void _parseSpo2Params(List<int> data, int startIndex, int limit) {
    for (
      int i = startIndex;
      i < data.length - 1 && i < startIndex + limit;
      i++
    ) {
      final int val = data[i];
      if (val > 0 && val != 255) {
        _emitSpo2Point(val);
      }
      _spo2LogCount++;
    }
  }

  void _emitSpo2Point(int val) {
    if (_spo2LogBaseTime == 0) return;
    final int sec = _spo2LogBaseTime + (_spo2LogCount * _spo2LogInterval * 60);
    // Same fix for SpO2
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
    callbacks.onSpo2HistoryPoint(dt, val);
  }

  void _handleBigData(List<int> data) {
    // BC <Type> ...
    if (data.length < 2) return;
    final int sub = data[1];

    if (sub == BleConstants.subSpo2BigData) {
      // 0x2A - SpO2 History BigData
      // Structure: BC 2A ... [Header?] ... [DaysAgo] [Data...]
      _lastBigDataType = sub;
      spo2DataReceived = true;
      // Index 6 start is an assumption based on header size
      int index = 6;
      while (index < data.length) {
        if (index >= data.length) break;
        final int daysAgo = data[index];
        callbacks.onProtocolLog(
          "Parsing SpO2 Chunk: DaysAgo=$daysAgo (Index=$index)",
        );

        if (daysAgo == 0xFF) break;
        index++;

        final DateTime syncingDay = DateTime.now().subtract(
          Duration(days: daysAgo),
        );
        // Iterate 24h (48 bytes) -> 2 bytes per hour? Or per reading?
        // Actually typical format is Min byte, Max byte per hour.
        for (int h = 0; h < 24; h++) {
          if (index + 1 >= data.length) break;
          final int minV = data[index++];
          final int maxV = data[index++];
          if (minV > 0 && maxV > 0) {
            final int avg = (minV + maxV) ~/ 2;
            final DateTime dt = DateTime(
              syncingDay.year,
              syncingDay.month,
              syncingDay.day,
              h,
              0,
            );
            callbacks.onSpo2HistoryPoint(dt, avg);
          }
        }
      }
    } else if (sub == BleConstants.subSleepBigData) {
      // 0x27 - Sleep History
      _lastBigDataType = sub;
      // Gadgetbridge says structure is similar: [DaysAgo] [DayBytes] [Start] [End] etc...
      // Or simply: DayIndex, Length ...
      // Let's implement based on ColmiR0xPacketHandler.java historicalSleep logic.
      // Offset 6 = Days In Packet?
      // Check full packet structure: BC 27 Length_L Length_H 00 00 Days [DayData...]

      // Note: _bigDataBuffer logic should have reassembled the full packet if needed,
      // but if the packet is self-contained or part of a stream, we check headers.
      // But _handleBigData assumes reassembly logic is done if using recursion, OR
      // it handles the "final" payload.
      // Since `data` passed here is the full buffer from `processData` recursion:

      if (data.length < 7) return;
      final int daysInPacket = data[6];
      int index = 7;
      callbacks.onProtocolLog(
        "Parsing Sleep BigData (0xBC): Days=$daysInPacket",
      );

      for (int i = 0; i < daysInPacket; i++) {
        if (index >= data.length) break;

        // Structure per day:
        // [DaysAgo] [DayBytes] [StartMins L] [StartMins H] [EndMins L] [EndMins H] [Stages...]
        if (index + 6 > data.length) break;

        final int startOfChunk = index;
        final int daysAgo = data[index];
        final int dayBytes = data[index + 1];

        // Python: sleepStart = int.from_bytes(..., signed=True)
        final int sleepStartMins = (data[index + 2] | (data[index + 3] << 8))
            .toSigned(16);
        final int sleepEndMins = (data[index + 4] | (data[index + 5] << 8))
            .toSigned(16);

        final DateTime now = DateTime.now();
        // Calculate session start date
        // Note: daysAgo=0 is "Today", 1="Yesterday"
        final DateTime baseDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysAgo));

        // Refine Start Time: usually previous day evening
        DateTime sessionStart = baseDate.add(Duration(minutes: sleepStartMins));

        if (sleepStartMins > sleepEndMins) {
          // Wrapped around midnight (Start 23:00, End 07:00)
          sessionStart = sessionStart.subtract(const Duration(days: 1));
        }

        callbacks.onProtocolLog(
          "Sleep Session: Start=${sessionStart.toString()} Mins=$sleepStartMins->$sleepEndMins",
        );

        // Parse Stages
        final int stageDataStart = index + 6;
        int stagesLength = dayBytes - 4; // Headers (Start/End) are 4 bytes

        DateTime stageTime = sessionStart;

        // Safety check boundaries
        if (stageDataStart + stagesLength > data.length) {
          stagesLength = data.length - stageDataStart;
        }

        for (int k = 0; k < stagesLength; k += 2) {
          if (stageDataStart + k + 1 >= data.length) break;

          final int type = data[stageDataStart + k];
          final int duration = data[stageDataStart + k + 1];

          // Type mapping: 0x02=Light, 0x03=Deep, 0x05=Awake
          callbacks.onSleepHistoryPoint(
            stageTime,
            type,
            durationMinutes: duration,
          );

          stageTime = stageTime.add(Duration(minutes: duration));
        }

        // Advance main index
        // Structure: [DaysAgo:1][DayBytes:1][Start:2][End:2][Data: dayBytes-4]
        // data[index+1] is dayBytes.
        // Total chunk size = 1 (DaysAgo) + 1 (DayBytes) + dayBytes.
        index = startOfChunk + 2 + dayBytes;
      }
    } else if (sub == BleConstants.subBigDataEnd) {
      // End
      String typeStr = "Unknown";
      if (_lastBigDataType == BleConstants.subSpo2BigData) {
        typeStr = "SpO2";
      } else if (_lastBigDataType == BleConstants.subSleepBigData) {
        typeStr = "Sleep";
      }

      String extra = "";
      if (_lastBigDataType == BleConstants.subSpo2BigData) {
        extra = " Spo2Received: $spo2DataReceived";
      }

      callbacks.onProtocolLog("Big Data 0xBC Complete ($typeStr).$extra");
    } else {
      callbacks.onProtocolLog(
        "Unknown Big Data Subtype: ${sub.toRadixString(16)}",
      );
    }
  }

  void _handleNotification(int type, List<int> data) {
    // This is the main entry point for notifications from the device.
    // The 'type' byte is the first byte of the payload (after the 0x73 header).
    // The 'data' list is the full payload, including the 'type' byte.
    // So data[0] == type.

    // Some notifications are handled by _handleBigData if type == 0xBC
    // Other notifications are handled directly here or by specific handlers.

    // debugPrint("DEBUG: _handleNotification: Type=0x${type.toRadixString(16)} Data=${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");

    if (type == 0xBC) {
      // Big Data
      _handleBigData(data);
    } else if (type == 0x77) {
      // Activity Data
      _handleActivityData(data);
    } else if (type == 0x21) {
      // Goals
      _handleGoals(data);
    } else if (type == 0x43) {
      // Steps Log
      _handleStepsLog(data);
    } else if (type == 0x37) {
      // Stress History
      _handleStressHistory(data);
    } else if (type == 0x39) {
      // HRV History
      _handleHrvHistory(data);
    } else if (type == 0x36) {
      // Stress Config
      _handleStressConfigOrData(data);
    } else if (type == 0x22) {
      // Find Device
      _handleFindDevice(data);
    } else if (type == 0x11) {
      // Battery
      if (data.length > 2) {
        // callbacks.onBatteryRead(data[2]); // Undefined
      }
    } else if (type == 0x10) {
      // Firmware Version
      if (data.length > 2) {
        // callbacks.onFirmwareVersionRead(data[2]); // Undefined
      }
    } else if (type == 0x01) {
      // Time Sync Response
      // callbacks.onTimeSyncResponse(); // Undefined
    } else if (type == 0x02) {
      // User Info Response
      // callbacks.onUserInfoResponse(); // Undefined
    } else if (type == 0x03) {
      // Alarm Response
      // callbacks.onAlarmResponse(); // Undefined
    } else if (type == 0x04) {
      // Sedentary Reminder Response
      // callbacks.onSedentaryReminderResponse(); // Undefined
    } else if (type == 0x05) {
      // Heart Rate Interval Response
      // callbacks.onHeartRateIntervalResponse(); // Undefined
    } else if (type == 0x06) {
      // Language Response
      // callbacks.onLanguageResponse(); // Undefined
    } else if (type == 0x07) {
      // Unit Response
      // callbacks.onUnitResponse(); // Undefined
    } else if (type == 0x08) {
      // Find Phone Response
      // callbacks.onFindPhoneResponse(); // Undefined
    } else if (type == 0x09) {
      // Weather Response
      // callbacks.onWeatherResponse(); // Undefined
    } else if (type == 0x0A) {
      // Camera Control Response
      // callbacks.onCameraControlResponse(); // Undefined
    } else if (type == 0x0B) {
      // Music Control Response
      // callbacks.onMusicControlResponse(); // Undefined
    } else if (type == 0x0C) {
      // Call Control Response
      // callbacks.onCallControlResponse(); // Undefined
    } else if (type == 0x0D) {
      // Message Control Response
      // callbacks.onMessageControlResponse(); // Undefined
    } else if (type == 0x0E) {
      // App Control Response
      // callbacks.onAppControlResponse(); // Undefined
    } else if (type == 0x0F) {
      // Device Info Response
      // callbacks.onDeviceInfoResponse(); // Undefined
    } else if (type == 0x12) {
      // Log payloads for analysis
      // String hex = data.skip(2).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      // debugPrint("DEBUG Notification 12 (0x12) Payload: $hex");

      // Parse Steps from Notification 12
      // Format seems to be: 73 12 [00] [High] [Low] [00] ...
      // Index 2: 00
      // Index 3: High
      // Index 4: Low
      if (data.length > 5) {
        final int totalSteps = (data[3] << 8) | data[4];
        debugPrint("DEBUG: Parsed Steps from Notif 12: $totalSteps");

        // Send to DataManager
        // Note: This is Total Steps. DataManager will store it as 'activitySteps'.
        // ActiveSessionScreen subtracts startSteps to get session steps.
        callbacks.onActivityUpdate(
          steps: totalSteps,
          bpm:
              0, // Don't overwrite BPM if we don't have it (DataManager handles 0)
          calories: 0,
          distance: 0,
          duration: 0,
        );
      }
    }

    callbacks.onNotification(type);

    // Legacy support for Stress values in notification?
    // ...
  }

  void _handleActivityData(List<int> data) {
    debugPrint("DEBUG: _handleActivityData called with ${data.length} bytes");
    callbacks.onActivityPacketReceived(); // Notify detection logic immediately

    // 0x77 seems to have unreliable Step data (0 or values like 103).
    // notification 0x12 has the real counter.
    // So we will IGNORE Steps from 0x77 now.
    final int steps = 0;

    // Duration: Unknown position.
    final int duration = 0;

    // Heart Rate
    int bpm = 0;
    if (data.length > 6) {
      if (data[6] > 30 && data[6] < 220) bpm = data[6];
    }
    debugPrint("DEBUG: Parsed BPM from 0x77: $bpm");

    // Only update BPM from 0x77
    if (bpm > 0) {
      // 0 will be ignored by DataManager logic if we changed it,
      // BUT currently DataManager DOES overwrite if we pass 0?
      // Wait, DataManager codes: `_activitySteps = steps;`
      // If we pass 0 here, it will overwrite the Notif 12 steps with 0!
      // This is bad.
      // We need to NOT call onActivityUpdate if steps is 0.
      // But we need to update BPM.

      // We already call callbacks.onHeartRate(bpm) below.
      // And BleDataManager.onHeartRate updates `_heartRate`.
      // Does UI use `_heartRate`?
      // ActiveSessionScreen uses `service.heartRate` (from `_heartRate`).
      // So we do NOT need to call onActivityUpdate for BPM alone.
      // onActivityUpdate is primarily for Steps/Duration/Distance.

      // So: We simply DO NOT call onActivityUpdate from 0x77 anymore,
      // unless we find reliable non-step data we need (like Duration?).
      // For now, let's just update Live HR.
    }

    // Also update 'Live' HR if valid (Crucial for Display)
    if (bpm > 0) callbacks.onHeartRate(bpm);
  }

  void _handleGoals(List<int> data) {
    // 21 ...
    // Log Analysis: 21 01 [88 13 00] [e0 93 04] [b8 0b 00] ...
    // Steps (3 bytes): 88 13 00 -> 0x001388 = 5000
    // Cals (3 bytes): e0 93 04 -> 0x0493e0 = 300000 (Small Cal? -> 300 kcal)
    // Dist (3 bytes): b8 0b 00 -> 0x000bb8 = 3000 (Meters)

    final String hex = data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    callbacks.onProtocolLog("Goals Packet (0x21): $hex");

    // We need at least 11 bytes for Steps, Calories, Distance
    if (data.length < 11) return;

    final int steps = data[2] | (data[3] << 8) | (data[4] << 16);
    final int rawCals = data[5] | (data[6] << 8) | (data[7] << 16);
    final int distance = data[8] | (data[9] << 8) | (data[10] << 16);

    // Normalize Calories (assuming small calories from ring, converting to kcal)
    // If rawCals is clearly too large for kcal (e.g. > 10000 for a day), divide.
    // 300000 is definitely small calories.
    int calories = rawCals;
    if (rawCals > 10000) {
      calories = rawCals ~/ 1000;
    }

    // Sport/Sleep parsing remains ambiguous, leaving as 0 or trying best guess if consistent
    final int sport = 0;
    final int sleep = 0;

    callbacks.onGoalsRead(steps, calories, distance, sport, sleep);
  }

  void _handleFindDevice(List<int> data) {
    callbacks.onFindDevice();
  }

  void _handleStepsLog(List<int> data) {
    // 0x43 ...
    if (data.length < 13) return;
    if (data[1] == 0xF0) {
      // Start
      return;
    }

    // Parse Date: [1]=Yr, [2]=Mo, [3]=Day
    final int y =
        int.tryParse(data[1].toRadixString(16)) ??
        0; // Use BCD logic if hex? Original used toRadixString(16) which implies BCD-ish?
    // Original: int.tryParse(data[offset].toRadixString(16))
    // If data is 0x25, string is "25", int is 25. Correct for BCD.
    final int year = 2000 + y;
    final int month = int.tryParse(data[2].toRadixString(16)) ?? 1;
    final int day = int.tryParse(data[3].toRadixString(16)) ?? 1;
    final int qIdx = data[4];

    // Steps at index 9 (Offset+8) => data[9], data[10]
    if (data.length > 10) {
      final int steps = data[9] | (data[10] << 8);
      if (steps > 0) {
        // Calculate time
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
    // 0x37 [PacketIdx] ...
    if (data.length < 2) return;
    final int pIdx = data[1];
    if (pIdx == 0xFF) return; // End
    if (pIdx == 0) return; // Header

    final int startIdx = (pIdx == 1) ? 3 : 2;
    // Reconstruct simplified time
    // Since stress packet doesn't have timestamp, we assume "Today"?
    // Or based on request?
    // Original code just logged it.
    // We will calculate generic "MinuteOfDay" and let Service attach Date.
    // But wait, callbacks takes DateTime.
    // We'll use a dummy date or "Today".
    final DateTime today = DateTime.now();
    // We'll use start of today, Service can re-map if needed?
    // Actually, Stress History logic in original was very barebones.

    int minsOffset = 0;
    if (pIdx > 1) {
      // Fixed logic from original: pIdx starts at 1?
      // If pIdx=1, offset=0.
      // If pIdx=2, offset= ?
      // Original: minsOffset = 12 * 30 + (pIdx - 2) * 13 * 30;
      // If pIdx=2: 360 + 0 = 360 (6 hours)
    }

    // Original formula preservation
    if (pIdx > 1) {
      minsOffset = 12 * 30 + (pIdx - 2) * 13 * 30;
    }

    for (int i = startIdx; i < data.length - 1; i++) {
      final int val = data[i];
      if (val > 0) {
        final int minOfDay = minsOffset + (i - startIdx) * 30;
        int h = minOfDay ~/ 60;
        int m = minOfDay % 60;
        // Safety check for hours
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
    // 0x39 [PacketIdx] ...
    // Modeled after Stress (0x37)
    if (data.length < 2) return;
    final int pIdx = data[1];

    // Check if it's Legacy Config (0x39 04 / 0x39 05)
    // If it's 04 or 05, and length is small?
    // Usually Config command response mirrors request.
    // If we requested Sync (0x39 00 ...), we expect 0x39 00 response.
    // If we requested Config (0x39 04 ...), we expect 0x39 04 response.
    // RISK: Overlap if PacketIndex is 4 or 5.
    // Mitigation: Check length? Or context?
    // For now, assume if it looks like data (length > 2) and we are syncing, it's data.

    if (pIdx == 0xFF) return; // End
    // If pIdx is a valid config opcode? 0x01 (Read), 0x02 (Write), 0x03 (Del)?
    // Command 0x39 legacy opcodes are 0x05 (Init), 0x04 (Profile).
    // Let's assume if we are syncing, we want to parse it.

    int startIdx = (pIdx == 0) ? 2 : (pIdx == 1 ? 3 : 2);
    // Actually Stress logic: 0->Header? No, Stress 0->Header is ignored in my code?
    // "if (pIdx == 0) return;" // Header
    // If HRV follows suit:
    if (pIdx == 0) return;

    // Adjust start index logic if needed
    if (pIdx == 1)
      startIdx = 3;
    else
      startIdx = 2; // Copying stress logic

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
    // 36 01 [Enabled]
    if (data.length > 2 && data[1] == 0x01) {
      final bool enabled = (data[2] != 0);
      callbacks.onAutoConfigRead("Stress", enabled);
    }
  }

  void _handleSleepLog(List<int> data) {
    // Gadgetbridge Protocol (confirmed):
    // Header: 0x7A [PIdx] [LenLow] [LenHigh] ...
    // Payload start at index 7? No, based on PacketHandler.java:
    // int daysInPacket = value[6];
    // int index = 7;
    // ...
    // Loop Days:
    //   daysAgo = value[index];
    //   dayBytes = value[index+1];
    //   start = u16(index+2);
    //   end = u16(index+4);
    //   index += 6;
    //   Loop Stages until dayBytes:
    //     type = value[index];
    //     mins = value[index+1];
    //     index += 2;

    final String hex = data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    callbacks.onProtocolLog("Sleep Packet (0x7A): $hex");

    if (data.length < 7) return;

    // Check header for packet length?
    // int packetLen = (data[2] | (data[3] << 8));
    // if (data.length < packetLen) ... // Packet might be fragmented or full?

    int daysInPacket = data[6];
    int index = 7;

    // Fallback for short header format seen in logs: 7A 00 05 3C ...
    // Indices: 0:7A, 1:00, 2:05, 3:3C.
    // data[6] is 00.
    if (daysInPacket == 0 && data.length > 4 && data[2] > 0 && data[2] < 10) {
      daysInPacket = data[2];
      // Index 3 (3C) might be total bytes or dayBytes?
      // If we assume standard structure but shifted:
      // Index 7 was start of data.
      // Here, start of data might be Index 4?
      index = 4;
      callbacks.onProtocolLog(
        "Sleep Packet (0x7A): Detected Short Header. Days=$daysInPacket",
      );
    }

    for (int i = 0; i < daysInPacket; i++) {
      if (index + 6 >= data.length) break;

      int daysAgo = data[index];
      final int dayBytes = data[index + 1];

      // Time
      final int sleepStartMins = data[index + 2] | (data[index + 3] << 8);
      final int sleepEndMins = data[index + 4] | (data[index + 5] << 8);

      final DateTime now = DateTime.now();
      // 'daysAgo' indicates how many days ago the sleep period ENDED.
      // So daysAgo=0 means the sleep period that ended today (this morning).
      final DateTime targetDate = now.subtract(Duration(days: daysAgo));

      // Construct start time based on the targetDate (the day they woke up)
      DateTime sessionStart = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        0,
        0,
      ).add(Duration(minutes: sleepStartMins));

      // If they went to bed before midnight, the start time is actually the day before the targetDate
      if (sleepStartMins > sleepEndMins) {
        sessionStart = sessionStart.subtract(const Duration(days: 1));
      }

      index += 6;

      // Stages
      // "dayBytes" implies the length of the DATA chunk for this day?
      // GB: "for (int j = 4; j < dayBytes; j += 2)"
      // This implies 'dayBytes' includes the 4 bytes of start/end time?
      // 4 (start/end) + (N * 2 stages).

      int bytesRead = 4;
      while (bytesRead < dayBytes) {
        if (index + 1 >= data.length) break;

        final int type = data[index];
        final int duration = data[index + 1];

        // 0x02=Light, 0x03=Deep, 0x05=Awake
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
  }

  void _handleRealTimeHealthData(List<int> data) {
    if (data.length >= 13) {
      int bpm = data[12];

      if (bpm < 30 || bpm > 220) {
        bpm = data[3];
      }

      if (bpm > 40 && bpm < 220 && bpm != 105) {
        debugPrint("🔥 COLMI R10 PULS GEKNACKT: $bpm bpm");
        callbacks.onHeartRate(bpm);
      }
    }
  }
}
