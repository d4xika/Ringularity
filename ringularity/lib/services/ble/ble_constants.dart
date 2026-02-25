/// A static library containing all immutable Bluetooth UUIDs, command headers, and target definitions.
///
/// Centralizes the proprietary communication protocol dictionary used by the
/// Colmi/Nordic family of smart rings.
class BleConstants {
  /// The primary Nordic UART Service UUID identifying the core communication pipeline.
  static const String serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";

  /// The characteristic UUID used to transmit (TX) commands to the ring.
  static const String writeCharUuid = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";

  /// The characteristic UUID used to receive (RX) asynchronous data from the ring.
  static const String notifyCharUuid = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

  /// The secondary service UUID used by modern rings for bulk data transfer.
  static const String serviceUuidV2 = "de5bf728-d711-4e47-af26-65e3012a5dc7";
  static const String notifyCharUuidV2 = "de5bf729-d711-4e47-af26-65e3012a5dc7";
  static const String writeCharUuidV2 = "de5bf72a-d711-4e47-af26-65e3012a5dc7";

  /// The list of known BLE advertisement names the scanner should filter for.
  static const List<String> targetDeviceNames = [
    "R12",
    "R10",
    "R06",
    "R02",
    "Ring",
    "Yawell",
    "Colmi",
  ];

  // --- Command Headers (Byte 0) ---

  static const int cmdSetTime = 0x01;
  static const int cmdGetBattery = 0x03;
  static const int cmdSetPhoneName = 0x04;
  static const int cmdReboot = 0x08;
  static const int cmdSetUserProfile = 0x0A;

  static const int cmdGetHeartRateLog = 0x15;
  static const int cmdGetSpo2Log = 0x16;
  static const int cmdSetGoals = 0x21;
  static const int cmdSpo2AutoConfig = 0x2C;
  static const int cmdStressConfig = 0x36;
  static const int cmdStressSync = 0x37;
  static const int cmdHrvConfig = 0x38;
  static const int cmdHrvSync = 0x39;
  static const int cmdLegacyConfig = 0x39;
  static const int cmdGetStepsLog = 0x43;
  static const int cmdBind = 0x48;
  static const int cmdGetSleepLog = 0x7A;

  static const int cmdRealTimeMeasure = 0x69;
  static const int cmdRealTimeStop = 0x6A;

  static const int cmdNotify = 0x73;
  static const int cmdActivityControl = 0x77;
  static const int cmdActivityData = 0x78;

  static const int cmdRawData = 0xA1;
  static const int cmdBigData = 0xBC;

  static const int cmdFactoryReset = 0xFF;

  // --- Subtypes and Identifiers ---

  static const int typeHeartRate = 0x01;
  static const int typeSpo2 = 0x03;
  static const int typeStress = 0x08;
  static const int typeHrv = 0x0A;
  static const int typeRawPPG = 0x08;

  static const int subSpo2BigData = 0x2A;
  static const int subSleepBigData = 0x27;
  static const int subBigDataEnd = 0xEE;

  static const int cmdFindDevice = 0x50;

  // Gadgetbridge verified sleep phase codes
  static const int sleepLight = 0x02;
  static const int sleepDeep = 0x03;
  static const int sleepAwake = 0x05;
}
