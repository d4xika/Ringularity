import 'dart:typed_data';
import 'ble_constants.dart';

class PacketFactory {
  // Command Constants
  static const int cmdHeartRateMeasurement = 0x69; // 105 - Manual Start

  static const int cmdStopRealTime = 0x6A; // 106 - Manual Stop
  static const int cmdRealTimeData = 0x43; // 67 - Realtime Data Config

  // Headers
  // Protocol: Command + Data (14 bytes) + Checksum
  // ... (unchanged)

  // ...

  static Uint8List stopHeartRate() {
    // 0x6A 0x01 0x00 - Stop Real-time Measurement
    return createPacket(
      command: cmdStopRealTime,
      data: [0x01, 0x00],
    );
  }

  // ...

  static Uint8List stopRealTimeSpo2() {
    // 0x6A 0x03 0x00 - Stop Real-time SpO2 Logic
    return createPacket(
      command: cmdStopRealTime,
      data: [0x03, 0x00],
    );
  }

  // Helper for HRV Stop
  static Uint8List stopRealTimeHrv() {
    // 0x6A = Stop Command
    // 0x0A = HRV Data Type (Type 10)
    // 0x00 = Parameter
    return createPacket(
      command: cmdStopRealTime,
      data: [0x0A, 0x00],
    );
  }

  /// Constructs a 16-byte packet adhering to the Colmi Ring protocol.
  /// Structure: [Command Byte] [Data Bytes...] [Checksum]
  /// The packet is always padded to 16 bytes.
  /// [command] - The command ID (e.g., 0x69 for Heart Rate).
  /// [data] - A list of data bytes (will be padded with zeros to fit payload area).
  static Uint8List createPacket({required int command, List<int>? data}) {
    final List<int> packet = List.filled(16, 0);

    packet[0] = command;

    if (data != null) {
      for (int i = 0; i < data.length && i < 14; i++) {
        packet[1 + i] = data[i];
      }
    }

    // Checksum: (Sum of bytes 0-14) & 0xFF
    // This is a simple additive checksum used by the ring to verify integrity.
    int sum = 0;
    for (int i = 0; i < 15; i++) {
      sum += packet[i];
    }
    packet[15] = sum & 0xFF;

    return Uint8List.fromList(packet);
  }

  /// Creates a raw packet from the exact bytes provided.
  static Uint8List createRawPacket(List<int> bytes) {
    return Uint8List.fromList(bytes);
  }

  /// Creates sample commands based on user request
  static Uint8List startHeartRate() {
    // 0x6901 - Request Heart Rate (Real-time)
    // Payload: [0x01] tells the ring to start streaming HR data.
    return createPacket(
      command: cmdHeartRateMeasurement,
      data: [0x01],
    );
  }

  /// 0xBC 27 Big Data Request (Sleep)
  /// Standard format: 16 bytes padded. Key 0x01.
  static Uint8List createSleepRequestPacket() {
    // 0xBC 27 00 00 FF FF (BigData Sleep Request)
    // Python: [39, 0, 0, 255, 255] -> cmd 188 (0xBC)
    return createPacket(
        command: BleConstants.cmdBigData, data: [0x27, 0x00, 0x00, 0xFF, 0xFF]);
  }

  /// 0x43 Realtime Data Config Packet
  /// From log: 43 00 0f 00 5f 01 00...
  static Uint8List getRealtimeDataPacket() {
    return createPacket(
      command: cmdRealTimeData,
      data: [0x00, 0x0F, 0x00, 0x5F, 0x01, 0x00], // Added trailing 0x00
    );
  }

  static Uint8List enableHeartRate({int interval = 5}) {
    // 0x16 0x02 0x01 <Interval> - Enable Periodic Monitoring
    // Gadgetbridge sends interval as byte 3.
    // Interval 5 mins = 0x05.
    return createPacket(
      command: 0x16,
      data: [0x02, 0x01, interval],
    );
  }

  static Uint8List disableHeartRate() {
    // 0x16 0x02 0x00 - Disable Periodic Monitoring
    return createPacket(
      command: 0x16,
      data: [0x02, 0x00],
    );
  }

  static Uint8List enableSpo2() {
    // 0x2C 0x02 0x01 - Enable Periodic Monitoring
    return createPacket(
      command: 0x2C,
      data: [0x02, 0x01],
    );
  }

  static Uint8List disableSpo2() {
    // 0x2C 0x02 0x00 - Disable Periodic Monitoring
    return createPacket(
      command: 0x2C,
      data: [0x02, 0x00],
    );
  }

  // Reference: requestSpO2 (hex: '6903') - This is the Real-Time measurement
  static Uint8List startSpo2() {
    return createPacket(
      command: cmdHeartRateMeasurement,
      data: [0x03, 0x01],
    );
  }

  // Reference: disableSpO2Monitoring (hex: '2c0200')
  static List<Uint8List> stopSpo2() {
    return [
      createPacket(command: 0x2C, data: [0x02, 0x00]),
    ];
  }

  // Reference: disableStressMonitoring (hex: '360200')
  static Uint8List stopStress() {
    // 0x6A 0x08 0x00 - Stop Real-Time Stress (Type 0x08)
    return createPacket(
      command: cmdStopRealTime,
      data: [BleConstants.typeStress, 0x00],
    );
  }

  static Uint8List startStress() {
    // 0x69 0x08 0x01 - Start Real-Time Stress
    return createPacket(
      command: cmdHeartRateMeasurement,
      data: [BleConstants.typeStress, 0x01],
    );
  }

  static Uint8List reboot() {
    return createPacket(command: 0x08);
  }

  static const int cmdGetSteps = 0x43; // 67 decimal

  /// Creates packet to request steps for a specific day offset
  static Uint8List getStepsPacket({int dayOffset = 0}) {
    // 0x01 = Key, 0x00 = Start Index, 0x60 = Count (96 blocks of 15 min = 24h), 0x00
    // If 0x0F was used before, it might have been an offset or specific key?
    // Trying 0x01 based on common protocols, or sticking to 0x0F if it's the key.
    // Let's assume 0x0F is key, 0x00 is start, 0x60 (96) is length.
    List<int> data = [dayOffset, 0x0f, 0x00, 0x60, 0x00];
    return createPacket(command: cmdGetSteps, data: data);
  }

  // New Commands
  static const int cmdGetBattery = 0x03;
  static const int cmdGetHeartRateLog = 0x15; // 21 decimal
  static const int cmdGetSpo2Log = 0x16; // 22 decimal
  static const int cmdGetSleepLog = 0x7A; // 122 decimal (Experimental)

  /// Creates packet to request battery level
  static Uint8List getBatteryPacket() {
    return createPacket(command: cmdGetBattery);
  }

  /// Creates packet to request Heart Rate Log for a specific date
  /// [date] - usually midnight of the requested day
  static Uint8List getHeartRateLogPacket(DateTime date) {
    // Structure based on colmi_r02_client:
    // Packet[0] = 0x15 (Command for HR Log)
    // Packet[1-4] = Timestamp (Little Endian)
    // Packet[5-15] = 0 (Padding)

    // Fix: Use UTC components to ignore local timezone offset.
    // The ring likely treats 'Set Time' (Local) as its internal reference.
    // If we request 'Local Midnight' converted to 'True UTC Timestamp', it shifts by TZ offset.
    // We want the timestamp of 'Midnight 13th' to be the same raw number as if it were UTC.
    // Example: Dec 14 00:00 Local (UTC+1) -> Dec 13 23:00 UTC. Timestamp is for Dec 13.
    // By using DateTime.utc(2025, 12, 14), we get Dec 14 00:00 UTC. Timestamp is for Dec 14.
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    int timestamp = utcDate.millisecondsSinceEpoch ~/ 1000;

    // Fix 2: Packet Length.
    // Gadgetbridge sends exactly 5 bytes (Cmd 0x15 + 4 bytes Timestamp).
    // Previous code sent 14 bytes of payload (Cmd + 4 bytes TS + 10 bytes Zeros).
    // The ring might reject the extra length or interpret zeros as data.
    // We send only the 4 bytes of timestamp data (createPacket handles framing).

    ByteData byteData = ByteData(4);
    byteData.setUint32(0, timestamp, Endian.little);

    List<int> data = List.filled(4, 0);
    for (int i = 0; i < 4; i++) {
      data[i] = byteData.getUint8(i);
    }

    return createPacket(command: cmdGetHeartRateLog, data: data);
  }

  // Binding / Pairing Commands
  static const int cmdBind = 0x48;
  static const int cmdConfig = 0x39; // or UserInfo/Settings

  static Uint8List createBindRequest() {
    // 0x48 00 ...
    return createPacket(command: cmdBind, data: [0x00]);
  }

  /// Creates the "Bind Action" packet found in official app logs.
  /// HEX: 48 00 01 C8 00 00 00 00 32 F6 00 01 2D 00 19 80
  /// This likely sets the User ID or Authorization Token.
  static Uint8List createBindActionPacket() {
    return Uint8List.fromList([
      0x48, // Command: Bind
      0x00, // Sub-command?
      0x01, // Key?
      0xC8, // 200?
      0x00, 0x00, 0x00, 0x00, // Empty/ID?
      0x32, // 50
      0xF6, // 246
      0x00,
      0x01,
      0x2D, // 45
      0x00,
      0x19, // 25
      0x80 // Magic / Checksum?
    ]);
    // Note: We bypass createPacket here to ensure EXACT byte matching including checksum/tail if the ring expects this specific blob.
    // However, if checksum is needed, createPacket does it.
    // Let's verify if the last byte 0x80 is a checksum.
    // Sum(0..14) = 48+0+1+C8+0+0+0+0+32+F6+0+1+2D+0+19 = 265 (0x109) -> 0x09?
    // 0x80 is definitely not 0x09.
    // This implies the packet is RAW and follows a different structure or the log `80` is correct.
    // I will send it exactly as observed.
  }

  static Uint8List createConfigInit() {
    // 0x39 05 ...
    return createPacket(command: BleConstants.cmdLegacyConfig, data: [0x05]);
  }

  // Gadgetbridge Commands
  static const int cmdSetTime = 0x01;
  static const int cmdBattery = 0x03;
  static const int cmdPhoneName = 0x04;
  static const int cmdPreferences = 0x0A;

  /// Creates packet to set time (0x01 YY MM DD HH MM SS) - BCD Encoded!
  /// The ring requires Binary Coded Decimal format for time components.
  static Uint8List createSetTimePacket() {
    final now = DateTime.now();
    int toBcd(int val) => ((val ~/ 10) << 4) | (val % 10);

    int y = toBcd(now.year % 100);
    int m = toBcd(now.month);
    int d = toBcd(now.day);
    int h = toBcd(now.hour);
    int min = toBcd(now.minute);
    int s = toBcd(now.second);
    return createPacket(command: cmdSetTime, data: [y, m, d, h, min, s]);
  }

  /// Creates packet to set Phone Name (0x04 02 0A ...)
  static Uint8List createSetPhoneNamePacket() {
    // 0x04 + 0x02(Major) + 0x0A(Minor) + 'G' 'B' (Gadgetbridge)
    // We'll use 'F' 'L' for Flutter just to be cool, or stick to 'G' 'B' if it matters.
    // Let's use 'G' 'B' first to match Gadgetbridge exactly.
    return createPacket(command: cmdPhoneName, data: [0x02, 0x0A, 0x47, 0x42]);
  }

  /// Creates packet to set User Preferences (0x0A 02 ...)
  /// Replaces the old 0x39 sequence.
  static Uint8List createUserProfilePacket() {
    // 0x0A + 0x02 (Write) + 0x00(24h) + 0x00(Metric) + 0x00(Male) + Age(30) + H(175) + W(70) + 00 00 00
    // Using default dummy values for now: Male, 30yo, 175cm, 70kg.
    return createPacket(command: cmdPreferences, data: [
      0x02, // Write
      0x00, // 24h
      0x00, // Metric
      0x00, // Gender: Male
      30, // Age
      175, // Height (cm)
      70, // Weight (kg)
      0x00, // Sys BP
      0x00, // Dia BP
      0x00 // HR Alarm
    ]);
  }

  // Legacy User Profile (0x39)
  // Found in logs: 39 04 ...
  static Uint8List createLegacyUserProfilePacket() {
    return createPacket(command: BleConstants.cmdLegacyConfig, data: [
      0x04, // Write? (Log showed 39 04)
      0x00, // 24h
      0x00, // Metric
      0x00, // Gender: Male
      30, // Age
      175, // Height (cm)
      70, // Weight (kg)
      0x00, // Sys BP
      0x00, // Dia BP
      0x00 // HR Alarm
    ]);
  }

  // Legacy User Profile Empty (0x39 04 00...)
  // Official App sends this (all zeros) and gets 39 ff?
  // Maybe it's a reset.
  static Uint8List createLegacyUserProfilePacketEmpty() {
    return createPacket(
        command: cmdConfig,
        data: [0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
  }

  /// Creates packet to request SpO2 Log
  /// [dayOffset] - 0 for today. Structure same as Steps (0x43).
  static Uint8List getSpo2LogPacket({int dayOffset = 0}) {
    // Structure assumed same as Steps (0x43) since response starts with 0xF0
    // [DayOffset, Key?, Start?, Count?, ?]
    // Steps uses: [Offset, 0x0f, 0x00, 0x60, 0x00]
    // We try the same structure for SpO2. Count 0x60 (96) covers 24h of 15-min blocks.
    // If SpO2 is sparse, this might just request "a day's buffer".
    // Using 0x03 as Key (SpO2 Type) instead of 0x0F
    List<int> data = [dayOffset, 0x03, 0x00, 0x60, 0x00];
    return createPacket(command: cmdGetSpo2Log, data: data);
  }

  // Raw Sensor Data Commands
  static const int cmdRawData = 0xA1;
  static const int subCmdEnableRaw = 0x04;
  static const int subCmdDisableRaw = 0x02;

  static Uint8List enableRawDataPacket() {
    return createPacket(command: cmdRawData, data: [subCmdEnableRaw]);
  }

  static Uint8List disableRawDataPacket() {
    return createPacket(command: cmdRawData, data: [subCmdDisableRaw]);
  }

  // SpO2 History Sync (Alternative 0xBC)
  static const int cmdSyncSpo2HistoryNew = 0xBC;
  // 0x2A matches Gadgetbridge BIG_DATA_TYPE_SPO2
  static const int subCmdSyncSpo2 = 0x2A;

  static Uint8List getSpo2LogPacketNew() {
    // Gadgetbridge: BC <Type> 01 00 FF 00 FF
    // We confirmed 7-byte raw failed (Silence), 16-byte worked (Response).
    // The key 0x01 seems to be "Fetch All", not an offset.
    // 0xBC = Big Data Command
    // subCmdSyncSpo2 = Data Type (SpO2)
    return createPacket(
        command: cmdSyncSpo2HistoryNew,
        data: [subCmdSyncSpo2, 0x01, 0x00, 0xFF, 0x00, 0xFF]);
  }

  // HRV History Sync (0x39) - Experimental
  static const int cmdSyncHrv = 0x39;

  static Uint8List getHrvLogPacket({int packetIndex = 0}) {
    // Assuming structure matches Stress (0x37)
    // 0x39 [PacketIndex]
    return createPacket(command: cmdSyncHrv, data: [packetIndex]);
  }

  // Stress History Sync (0x37)
  static const int cmdSyncStress = 0x37;

  static Uint8List getStressHistoryPacket({int packetIndex = 0}) {
    // Gadgetbridge sends 0x37 [PacketIndex]
    // 0x00 is the first packet.
    return createPacket(command: cmdSyncStress, data: [packetIndex]);
  }

  // Sleep History Sync (0x7A)
  static Uint8List getSleepLogPacket({int packetIndex = 0}) {
    // 0x7A [PacketIndex]
    return createPacket(command: cmdGetSleepLog, data: [packetIndex]);
  }

  // Raw PPG Stream (Green Light High Frequency)
  // Found in Golden Log: 69 08 ...
  static Uint8List startRawPPG() {
    return createPacket(
      command: cmdHeartRateMeasurement, // 0x69
      data: [
        0x08,
        0x25
      ], // 0x25 seen in log #1863, might be specific sensor config
      // Or just 0x08? Log showed: 69 08 25 ...
      // Let's try [0x08, 0x25] first, if fail try [0x08]
    );
  }

  static Uint8List stopRawPPG() {
    // No explicit stop seen in log (it naturally timed out or used the generic disable?)
    // We will try sending the standard HR Disable: 16 02 00
    return disableHeartRate();
  }

  // Find Device (0x50) - 50 55 AA
  static Uint8List createFindDevicePacket() {
    return createPacket(command: 0x50, data: [0x55, 0xAA]);
  }

  // Request Goals (0x21) - Readings
  static Uint8List requestGoals() {
    return createPacket(command: 0x21, data: [0x01]);
  }

  static Uint8List createFactoryResetPacket() {
    // FF 66 66
    return createPacket(command: 0xFF, data: [0x66, 0x66]);
  }
}
