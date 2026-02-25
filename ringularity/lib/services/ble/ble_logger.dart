import 'package:flutter/foundation.dart';

/// A volatile memory buffer managing diagnostic text logs generated during BLE interactions.
///
/// Limits the history to the most recent 1000 protocol events to prevent unbounded RAM usage.
class BleLogger extends ChangeNotifier {
  String _lastLog = "No data received";

  /// The most recent significant protocol event string.
  String get lastLog => _lastLog;

  final List<String> _protocolLog = [];

  /// An unmodifiable, time-ordered list of formatted hex protocol messages.
  List<String> get protocolLog => List.unmodifiable(_protocolLog);

  /// Prints a standard debug message to the console without storing it in the UI buffer.
  void log(String message) {
    debugPrint("[${DateTime.now().toString().substring(11, 19)}] $message");
  }

  /// Appends a new RX/TX hex packet log to the internal buffer and alerts listeners.
  void addToProtocolLog(String message, {bool isTx = false}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final prefix = isTx ? "TX" : "RX";
    final logEntry = "[$timestamp] $prefix: $message";

    _protocolLog.add(logEntry);
    if (_protocolLog.length > 1000) {
      _protocolLog.removeAt(0);
    }
    debugPrint(logEntry);
    notifyListeners();
  }

  /// Updates the single-line summary log string.
  void setLastLog(String message) {
    _lastLog = message;
  }

  /// Erases all existing BLE protocol logs from memory.
  void clearLogs() {
    _protocolLog.clear();
    notifyListeners();
  }
}
