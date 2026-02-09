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
  void onSleepHistoryPoint(DateTime timestamp, int sleepStage,
      {int durationMinutes = 0});
  void onStepsHistoryPoint(DateTime timestamp, int steps, int quarterIndex);

  void onRawAccel(List<int> data);
  void onRawPPG(List<int> data);

  void onAutoConfigRead(String type, bool enabled); // Type: HR, SpO2, etc.

  void onNotification(int type);

  void onGoalsRead(int steps, int calories, int distance, int sport, int sleep);
  void onFindDevice();
  void onMeasurementError(int type, int errorCode);
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

  int _spo2LogInterval = 5;
  int _spo2LogBaseTime = 0;
  int _spo2LogCount = 0;

  bool spo2DataReceived = false; // Track if we got any 0xBC data

  Future<void> processData(List<int> data) async {
    if (data.isEmpty) return;

    // --- BIG DATA REASSEMBLY ---
    // If we are in the middle of receiving a large packet, append data to buffer.
    if (_isReceivingBigData) {
      _bigDataBuffer.addAll(data);
      callbacks.onProtocolLog(
          "Buffering Big Data... ${_bigDataBuffer.length}/$_bigDataExpectedLen");

      // Check if we have received the full payload
      if (_bigDataBuffer.length >= _bigDataExpectedLen) {
        List<int> fullPacket = List.from(_bigDataBuffer);
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
      int lenL = data[2];
      int lenH = data[3];
      int payloadLen = lenL | (lenH << 8);
      int totalExpected = payloadLen + 6; // Header overhead

      if (data.length < totalExpected) {
        // Start buffering if current data is partial
        callbacks.onProtocolLog(
            "Start Buffering Big Data (0xBC): Need $totalExpected bytes");
        _isReceivingBigData = true;
        _bigDataExpectedLen = totalExpected;
        _bigDataBuffer = List.from(data);
        return;
      }
      // Else we have full packet immediately, continue processing below
    }

    // --- PARSING ---
    String hexData =
        data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    callbacks.onRawLog("RX: $hexData");

    int cmd = data[0];
    // int dataOffset = 1; // Unused

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
        _handleNotification(data);
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
        // Battery level is usually the second byte
        if (data.length > 1) callbacks.onBattery(data[1]);
        break;

      case BleConstants.cmdSpo2AutoConfig: // 0x2C
        if (data.length > 2 && data[1] == 0x01) {
          callbacks.onAutoConfigRead("SpO2", data[2] != 0);
        }
        break;

      case BleConstants.cmdHrvConfig: // 0x38
        if (data.length > 2 && data[1] == 0x01) {
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

      // ... Add others as needed
    }
  }

  void _handleRawData(List<int> data) {
    // 0xA1 <Type> ...
    // Raw sensor streams (PPG, Accel) often come with 0xA1 header.
    int subType = data[1];
    if (subType == 0x03) {
      callbacks.onRawAccel(data);
    } else if (subType == 0x01 || subType == 0x02) {
      callbacks.onRawPPG(data);
    }
  }

  void _handleRealTimeMeasure(List<int> data) {
    // 69 <Type> <Status> <Val>
    if (data.length < 3) return;
    int type = data[1];

    // Status is at index 2
    int status = data[2];

    if (status != 0) {
      callbacks
          .onProtocolLog("Realtime Measure Error: Type=$type Status=$status");
      callbacks.onMeasurementError(type, status);
      return;
    }

    // Value is at index 3
    if (data.length > 3) {
      int val = data[3];
      if (val > 0) {
        if (type == BleConstants.typeHeartRate)
          callbacks.onHeartRate(val);
        else if (type == BleConstants.typeSpo2)
          callbacks.onSpo2(val);
        else if (type == BleConstants.typeStress)
          callbacks.onStress(val);
        else if (type == BleConstants.typeHrv) callbacks.onHrv(val);
      }
    }
  }

  void _handleNotification(List<int> data) {
    // 73 <Type>
    if (data.length < 2) return;
    int type = data[1];

    callbacks.onNotification(type);

    // Legacy support for Stress values in notification?
    // 73 00 [Stress?]
    if (type == 0 && data.length > 2) {
      int val = data[2];
      if (val > 0) callbacks.onStress(val);
    }
  }

  void _handleHeartRateLog(List<int> data) {
    // 0x15 ...
    if (data.length < 2) return;
    int subType = data[1];
    if (subType == 0xFF) return; // End

    if (subType == 0) {
      // Start: [15, 00, 18?, 05(Interval), ...]
      if (data.length > 3) _hrLogInterval = data[3];
      if (_hrLogInterval <= 0) _hrLogInterval = 5;
    } else if (subType == 1) {
      // Timestamp
      if (data.length >= 6) {
        int t0 = data[2];
        int t1 = data[3];
        int t2 = data[4];
        int t3 = data[5];
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
    for (int i = startIndex;
        i < data.length - 1 && i < startIndex + limit;
        i++) {
      int val = data[i];
      if (val != 0 && val != 255) {
        _emitHrPoint(val);
      }
      _hrLogCount++;
    }
  }

  void _emitHrPoint(int val) {
    if (_hrLogBaseTime == 0) return;
    int sec = _hrLogBaseTime + (_hrLogCount * _hrLogInterval * 60);
    // The device sends the timestamp as if it were UTC, but it actually represents Local Time components.
    // Example: 00:00 Device Time -> Sent as 00:00 UTC Timestamp.
    // If we just use fromMillisecondsSinceEpoch, it converts 00:00 UTC -> 01:00 Local (if +1).
    // So we first parse as UTC to get the "face value" components, then create a Local DateTime from them.
    DateTime utcDt =
        DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
    DateTime dt = DateTime(utcDt.year, utcDt.month, utcDt.day, utcDt.hour,
        utcDt.minute, utcDt.second);
    callbacks.onHeartRateHistoryPoint(dt, val);
  }

  void _handleSpo2OrConfig(List<int> data) {
    // 0x16 ...
    if (data.length < 3) return;
    int b1 = data[1];
    int b2 = data[2];

    // SpO2 Log: Key 0x03
    if (b2 == 0x03) {
      // Header: [16, Offset, 03, Start, Count?]
      // Just reset state
      // _spo2LogInterval = 5;
      return;
    }

    // Config Read: 16 01 [Times...] (Year 2000 catch)
    if (b1 == 0x01) {
      // Check timestamp to differentiate from Data
      if (data.length > 5) {
        int t0 = data[2];
        // ...
        int timestamp = t0 | (data[3] << 8) | (data[4] << 16) | (data[5] << 24);
        if (timestamp < 1000000000) {
          // Config Read (Timestamp small)
          bool enabled = (data[2] != 0);
          callbacks.onAutoConfigRead("HR", enabled);
          return;
        } else {
          // SpO2 Data Timestamp
          _spo2LogBaseTime = timestamp;
          _spo2LogCount = 0;
          // Parse immediate ?
          _parseSpo2Params(data, 6, 9);
          return;
        }
      }
    }

    // Legacy/Data stream?
    // If we assume it falls through... logic in original was fuzzy.
  }

  void _parseSpo2Params(List<int> data, int startIndex, int limit) {
    for (int i = startIndex;
        i < data.length - 1 && i < startIndex + limit;
        i++) {
      int val = data[i];
      if (val > 0 && val != 255) {
        _emitSpo2Point(val);
      }
      _spo2LogCount++;
    }
  }

  void _emitSpo2Point(int val) {
    if (_spo2LogBaseTime == 0) return;
    int sec = _spo2LogBaseTime + (_spo2LogCount * _spo2LogInterval * 60);
    // Same fix for SpO2
    DateTime utcDt =
        DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
    DateTime dt = DateTime(utcDt.year, utcDt.month, utcDt.day, utcDt.hour,
        utcDt.minute, utcDt.second);
    callbacks.onSpo2HistoryPoint(dt, val);
  }

  void _handleBigData(List<int> data) {
    // BC <Type> ...
    if (data.length < 2) return;
    int sub = data[1];

    if (sub == BleConstants.subSpo2BigData) {
      // 0x2A - SpO2 History BigData
      // Structure: BC 2A ... [Header?] ... [DaysAgo] [Data...]
      _lastBigDataType = sub;
      spo2DataReceived = true;
      // Index 6 start is an assumption based on header size
      int index = 6;
      while (index < data.length) {
        if (index >= data.length) break;
        int daysAgo = data[index];
        callbacks.onProtocolLog(
            "Parsing SpO2 Chunk: DaysAgo=$daysAgo (Index=$index)");

        if (daysAgo == 0xFF) break;
        index++;

        DateTime syncingDay = DateTime.now().subtract(Duration(days: daysAgo));
        // Iterate 24h (48 bytes) -> 2 bytes per hour? Or per reading?
        // Actually typical format is Min byte, Max byte per hour.
        for (int h = 0; h < 24; h++) {
          if (index + 1 >= data.length) break;
          int minV = data[index++];
          int maxV = data[index++];
          if (minV > 0 && maxV > 0) {
            int avg = (minV + maxV) ~/ 2;
            DateTime dt = DateTime(
                syncingDay.year, syncingDay.month, syncingDay.day, h, 0);
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
      int daysInPacket = data[6];
      int index = 7;
      callbacks
          .onProtocolLog("Parsing Sleep BigData (0xBC): Days=$daysInPacket");

      for (int i = 0; i < daysInPacket; i++) {
        if (index >= data.length) break;

        // Structure per day:
        // [DaysAgo] [DayBytes] [StartMins L] [StartMins H] [EndMins L] [EndMins H] [Stages...]
        if (index + 6 > data.length) break;

        final int startOfChunk = index;
        int daysAgo = data[index];
        int dayBytes = data[index + 1];

        // Python: sleepStart = int.from_bytes(..., signed=True)
        int sleepStartMins =
            (data[index + 2] | (data[index + 3] << 8)).toSigned(16);
        int sleepEndMins =
            (data[index + 4] | (data[index + 5] << 8)).toSigned(16);

        DateTime now = DateTime.now();
        // Calculate session start date
        // Note: daysAgo=0 is "Today", 1="Yesterday"
        DateTime baseDate = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysAgo));

        // Refine Start Time: usually previous day evening
        DateTime sessionStart = baseDate.add(Duration(minutes: sleepStartMins));

        if (sleepStartMins > sleepEndMins) {
          // Wrapped around midnight (Start 23:00, End 07:00)
          sessionStart = sessionStart.subtract(const Duration(days: 1));
        }

        callbacks.onProtocolLog(
            "Sleep Session: Start=${sessionStart.toString()} Mins=$sleepStartMins->$sleepEndMins");

        // Parse Stages
        int stageDataStart = index + 6;
        int stagesLength = dayBytes - 4; // Headers (Start/End) are 4 bytes

        DateTime stageTime = sessionStart;

        // Safety check boundaries
        if (stageDataStart + stagesLength > data.length) {
          stagesLength = data.length - stageDataStart;
        }

        for (int k = 0; k < stagesLength; k += 2) {
          if (stageDataStart + k + 1 >= data.length) break;

          int type = data[stageDataStart + k];
          int duration = data[stageDataStart + k + 1];

          // Type mapping: 0x02=Light, 0x03=Deep, 0x05=Awake
          callbacks.onSleepHistoryPoint(stageTime, type,
              durationMinutes: duration);

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
    }
  }

  void _handleGoals(List<int> data) {
    // 21 ...
    // Layout from GB: 21 00 Steps(4) Cals(4) Dist(4) Sport(2) Sleep(2)
    if (data.length < 15) return;

    int steps = data[2] | (data[3] << 8) | (data[4] << 16) | (data[5] << 24);
    int calories = data[6] | (data[7] << 8) | (data[8] << 16) | (data[9] << 24);
    int distance =
        data[10] | (data[11] << 8) | (data[12] << 16) | (data[13] << 24);
    int sport = data[14] | (data[15] << 8); // 2 bytes

    // Wait, GB: sport(2), sleep(2). Total 4+4+4+2+2 = 16 bytes payload?
    // Indices:
    // Steps: 2,3,4,5
    // Cals: 6,7,8,9
    // Dist: 10,11,12,13
    // Sport: 14,15 (2 bytes)
    // Sleep: 16,17 (2 bytes)
    // Packet MUST be at least 18 bytes.
    if (data.length < 18) return;

    int sleep = data[16] | (data[17] << 8);

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
    int y = int.tryParse(data[1].toRadixString(16)) ??
        0; // Use BCD logic if hex? Original used toRadixString(16) which implies BCD-ish?
    // Original: int.tryParse(data[offset].toRadixString(16))
    // If data is 0x25, string is "25", int is 25. Correct for BCD.
    int year = 2000 + y;
    int month = int.tryParse(data[2].toRadixString(16)) ?? 1;
    int day = int.tryParse(data[3].toRadixString(16)) ?? 1;
    int qIdx = data[4];

    // Steps at index 9 (Offset+8) => data[9], data[10]
    if (data.length > 10) {
      int steps = data[9] | (data[10] << 8);
      if (steps > 0) {
        // Calculate time
        int mins = qIdx * 15;
        DateTime dt = DateTime(year, month, day).add(Duration(minutes: mins));
        callbacks.onStepsHistoryPoint(dt, steps, qIdx);
      }
    }
  }

  void _handleStressHistory(List<int> data) {
    // 0x37 [PacketIdx] ...
    if (data.length < 2) return;
    int pIdx = data[1];
    if (pIdx == 0xFF) return; // End
    if (pIdx == 0) return; // Header

    int startIdx = (pIdx == 1) ? 3 : 2;
    // Reconstruct simplified time
    // Since stress packet doesn't have timestamp, we assume "Today"?
    // Or based on request?
    // Original code just logged it.
    // We will calculate generic "MinuteOfDay" and let Service attach Date.
    // But wait, callbacks takes DateTime.
    // We'll use a dummy date or "Today".
    DateTime today = DateTime.now();
    // We'll use start of today, Service can re-map if needed?
    // Actually, Stress History logic in original was very barebones.

    int minsOffset = 0;
    if (pIdx > 1) {
      minsOffset = 12 * 30 + (pIdx - 2) * 13 * 30;
    }

    for (int i = startIdx; i < data.length - 1; i++) {
      int val = data[i];
      if (val > 0) {
        int minOfDay = minsOffset + (i - startIdx) * 30;
        int h = minOfDay ~/ 60;
        int m = minOfDay % 60;
        DateTime dt = DateTime(today.year, today.month, today.day, h, m);
        callbacks.onStressHistoryPoint(dt, val);
      }
    }
  }

  void _handleHrvHistory(List<int> data) {
    // 0x39 [PacketIdx] ...
    // Modeled after Stress (0x37)
    if (data.length < 2) return;
    int pIdx = data[1];

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

    DateTime today = DateTime.now();

    int minsOffset = 0;
    if (pIdx > 1) {
      minsOffset = 12 * 30 + (pIdx - 2) * 13 * 30;
    }

    for (int i = startIdx; i < data.length - 1; i++) {
      int val = data[i];
      if (val > 0) {
        int minOfDay = minsOffset + (i - startIdx) * 30;
        int h = minOfDay ~/ 60;
        int m = minOfDay % 60;
        DateTime dt = DateTime(today.year, today.month, today.day, h, m);
        callbacks.onHrvHistoryPoint(dt, val);
      }
    }
  }

  void _handleStressConfigOrData(List<int> data) {
    // 36 01 [Enabled]
    if (data.length > 2 && data[1] == 0x01) {
      bool enabled = (data[2] != 0);
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

    String hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
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
          "Sleep Packet (0x7A): Detected Short Header. Days=$daysInPacket");
    }

    for (int i = 0; i < daysInPacket; i++) {
      if (index + 6 >= data.length) break;

      // int daysAgo = data[index]; // ignored for now, assume chronological or mapped
      int dayBytes = data[index + 1];

      // Time
      int sleepStartMins = data[index + 2] | (data[index + 3] << 8);
      int sleepEndMins = data[index + 4] | (data[index + 5] << 8);

      DateTime now = DateTime.now();
      // Construct approximate start time (Logic from GB: if start > end, it crossed midnight)
      // Since we don't have exact 'daysAgo' reliable context without a full history sync,
      // let's try to map it to 'request date' or just use the time for the graph relative to 24h.

      // For simplicity, let's assume the data is for "last night" if it crosses midnight, or "today" if not.
      DateTime sessionStart = DateTime(now.year, now.month, now.day, 0, 0)
          .add(Duration(minutes: sleepStartMins));

      if (sleepStartMins > sleepEndMins) {
        // Started yesterday
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

        int type = data[index];
        int duration = data[index + 1];

        // 0x02=Light, 0x03=Deep, 0x05=Awake
        callbacks.onSleepHistoryPoint(sessionStart, type,
            durationMinutes: duration);

        sessionStart = sessionStart.add(Duration(minutes: duration));

        index += 2;
        bytesRead += 2;
      }
    }
  }
}
