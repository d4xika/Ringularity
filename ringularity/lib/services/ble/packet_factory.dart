import 'dart:typed_data';

import 'ble_constants.dart';

/// A static utility builder that constructs properly padded and checksum-validated
/// 16-byte arrays (Uint8List) required by the ring's binary communication protocol.
class PacketFactory {
  static const int cmdHeartRateMeasurement = 0x69;
  static const int cmdStopRealTime = 0x6A;
  static const int cmdRealTimeData = 0x43;

  static Uint8List stopHeartRate() {
    return createPacket(command: cmdStopRealTime, data: [0x01, 0x00]);
  }

  static Uint8List stopRealTimeSpo2() {
    return createPacket(command: cmdStopRealTime, data: [0x03, 0x00]);
  }

  static Uint8List stopRealTimeHrv() {
    return createPacket(command: cmdStopRealTime, data: [0x0A, 0x00]);
  }

  /// Constructs a 16-byte packet adhering strictly to the Colmi Ring protocol rules.
  ///
  /// Structure: [Command Byte] [Data Bytes...] [Checksum]
  /// The packet is always padded with trailing zeros to reach 16 bytes.
  /// [command] - The primary instructional header ID (e.g., 0x69 for Heart Rate).
  /// [data] - Optional supplementary payload arguments.
  static Uint8List createPacket({required int command, List<int>? data}) {
    final List<int> packet = List.filled(16, 0);

    packet[0] = command;

    if (data != null) {
      for (int i = 0; i < data.length && i < 14; i++) {
        packet[1 + i] = data[i];
      }
    }

    // This is a simple additive checksum used by the ring to verify data integrity over the air.
    int sum = 0;
    for (int i = 0; i < 15; i++) {
      sum += packet[i];
    }
    packet[15] = sum & 0xFF;

    return Uint8List.fromList(packet);
  }

  /// Wraps a raw array of integers into a structured byte buffer without altering it.
  static Uint8List createRawPacket(List<int> bytes) {
    return Uint8List.fromList(bytes);
  }

  static Uint8List startHeartRate() {
    return createPacket(command: cmdHeartRateMeasurement, data: [0x01]);
  }

  /// Requests the 0xBC 27 Big Data pipeline for sleep structure logs.
  static Uint8List createSleepRequestPacket() {
    return createPacket(
      command: BleConstants.cmdBigData,
      data: [0x27, 0x00, 0x00, 0xFF, 0xFF],
    );
  }

  static Uint8List getRealtimeDataPacket() {
    return createPacket(
      command: cmdRealTimeData,
      data: [0x00, 0x0F, 0x00, 0x5F, 0x01, 0x00],
    );
  }

  static Uint8List enableHeartRate({int interval = 5}) {
    return createPacket(command: 0x16, data: [0x02, 0x01, interval]);
  }

  static Uint8List disableHeartRate() {
    return createPacket(command: 0x16, data: [0x02, 0x00]);
  }

  static Uint8List enableSpo2() {
    return createPacket(command: 0x2C, data: [0x02, 0x01]);
  }

  static Uint8List disableSpo2() {
    return createPacket(command: 0x2C, data: [0x02, 0x00]);
  }

  static Uint8List startSpo2() {
    return createPacket(command: cmdHeartRateMeasurement, data: [0x03, 0x01]);
  }

  static List<Uint8List> stopSpo2() {
    return [
      createPacket(command: 0x2C, data: [0x02, 0x00]),
    ];
  }

  static Uint8List stopStress() {
    return createPacket(
      command: cmdStopRealTime,
      data: [BleConstants.typeStress, 0x00],
    );
  }

  static Uint8List startStress() {
    return createPacket(
      command: cmdHeartRateMeasurement,
      data: [BleConstants.typeStress, 0x01],
    );
  }

  static Uint8List reboot() {
    return createPacket(command: 0x08);
  }

  static const int cmdGetSteps = 0x43;

  static Uint8List getStepsPacket({int dayOffset = 0}) {
    final List<int> data = [dayOffset, 0x0f, 0x00, 0x60, 0x00];
    return createPacket(command: cmdGetSteps, data: data);
  }

  static const int cmdGetBattery = 0x03;
  static const int cmdGetHeartRateLog = 0x15;
  static const int cmdGetSpo2Log = 0x16;
  static const int cmdGetSleepLog = 0x7A;

  static Uint8List getBatteryPacket() {
    return createPacket(command: cmdGetBattery);
  }

  /// Builds the request payload for daily heart rate history.
  /// Utilizes UTC DateTime bounds to prevent timezone offsets from corrupting the ring's internal fetch logic.
  static Uint8List getHeartRateLogPacket(DateTime date) {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    final int timestamp = utcDate.millisecondsSinceEpoch ~/ 1000;

    final ByteData byteData = ByteData(4);
    byteData.setUint32(0, timestamp, Endian.little);

    final List<int> data = List.filled(4, 0);
    for (int i = 0; i < 4; i++) {
      data[i] = byteData.getUint8(i);
    }

    return createPacket(command: cmdGetHeartRateLog, data: data);
  }

  static const int cmdBind = 0x48;
  static const int cmdConfig = 0x39;

  static Uint8List createBindRequest() {
    return createPacket(command: cmdBind, data: [0x00]);
  }

  /// A specific raw hex string observed in official client apps, likely serving as an auth or master-bind token.
  static Uint8List createBindActionPacket() {
    return Uint8List.fromList([
      0x48,
      0x00,
      0x01,
      0xC8,
      0x00,
      0x00,
      0x00,
      0x00,
      0x32,
      0xF6,
      0x00,
      0x01,
      0x2D,
      0x00,
      0x19,
      0x80,
    ]);
  }

  static Uint8List createConfigInit() {
    return createPacket(command: BleConstants.cmdLegacyConfig, data: [0x05]);
  }

  static const int cmdSetTime = 0x01;
  static const int cmdBattery = 0x03;
  static const int cmdPhoneName = 0x04;
  static const int cmdPreferences = 0x0A;

  /// Injects the host smartphone's local time into the ring.
  ///
  /// The ring firmware expects this time explicitly encoded in Binary Coded Decimal (BCD) format.
  static Uint8List createSetTimePacket() {
    final now = DateTime.now();
    int toBcd(int val) => ((val ~/ 10) << 4) | (val % 10);

    final int y = toBcd(now.year % 100);
    final int m = toBcd(now.month);
    final int d = toBcd(now.day);
    final int h = toBcd(now.hour);
    final int min = toBcd(now.minute);
    final int s = toBcd(now.second);
    return createPacket(command: cmdSetTime, data: [y, m, d, h, min, s]);
  }

  static Uint8List createSetPhoneNamePacket() {
    return createPacket(command: cmdPhoneName, data: [0x02, 0x0A, 0x47, 0x42]);
  }

  static Uint8List createUserProfilePacket() {
    return createPacket(
      command: cmdPreferences,
      data: [0x02, 0x00, 0x00, 0x00, 30, 175, 70, 0x00, 0x00, 0x00],
    );
  }

  static Uint8List createLegacyUserProfilePacket() {
    return createPacket(
      command: BleConstants.cmdLegacyConfig,
      data: [0x04, 0x00, 0x00, 0x00, 30, 175, 70, 0x00, 0x00, 0x00],
    );
  }

  static Uint8List createLegacyUserProfilePacketEmpty() {
    return createPacket(
      command: cmdConfig,
      data: [0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    );
  }

  static Uint8List getSpo2LogPacket({int dayOffset = 0}) {
    final List<int> data = [dayOffset, 0x03, 0x00, 0x60, 0x00];
    return createPacket(command: cmdGetSpo2Log, data: data);
  }

  static const int cmdRawData = 0xA1;
  static const int subCmdEnableRaw = 0x04;
  static const int subCmdDisableRaw = 0x02;

  static Uint8List enableRawDataPacket() {
    return createPacket(command: cmdRawData, data: [subCmdEnableRaw]);
  }

  static Uint8List disableRawDataPacket() {
    return createPacket(command: cmdRawData, data: [subCmdDisableRaw]);
  }

  static const int cmdSyncSpo2HistoryNew = 0xBC;
  static const int subCmdSyncSpo2 = 0x2A;

  static Uint8List getSpo2LogPacketNew() {
    return createPacket(
      command: cmdSyncSpo2HistoryNew,
      data: [subCmdSyncSpo2, 0x01, 0x00, 0xFF, 0x00, 0xFF],
    );
  }

  static const int cmdSyncHrv = 0x39;

  static Uint8List getHrvLogPacket({int packetIndex = 0}) {
    return createPacket(command: cmdSyncHrv, data: [packetIndex]);
  }

  static const int cmdSyncStress = 0x37;

  static Uint8List getStressHistoryPacket({int packetIndex = 0}) {
    return createPacket(command: cmdSyncStress, data: [packetIndex]);
  }

  static Uint8List getSleepLogPacket({int packetIndex = 0}) {
    return createPacket(command: cmdGetSleepLog, data: [packetIndex]);
  }

  static Uint8List startRawPPG() {
    return createPacket(command: cmdHeartRateMeasurement, data: [0x08, 0x25]);
  }

  static Uint8List stopRawPPG() {
    return disableHeartRate();
  }

  static Uint8List createFindDevicePacket() {
    return createPacket(command: 0x50, data: [0x55, 0xAA]);
  }

  static Uint8List requestGoals() {
    return createPacket(command: 0x21, data: [0x01]);
  }

  static Uint8List createFactoryResetPacket() {
    return createPacket(command: 0xFF, data: [0x66, 0x66]);
  }

  static Uint8List startActivity(int type) {
    return createPacket(command: 0x77, data: [0x01, type]);
  }

  static Uint8List stopActivity() {
    return createPacket(command: 0x77, data: [0x00]);
  }

  static Uint8List endActivity() {
    return createPacket(command: 0x77, data: [0x04]);
  }
}
