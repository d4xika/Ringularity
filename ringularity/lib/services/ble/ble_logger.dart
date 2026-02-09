import 'package:flutter/foundation.dart';

class BleLogger extends ChangeNotifier {
  String _lastLog = "No data received";
  String get lastLog => _lastLog;

  final List<String> _protocolLog = [];
  List<String> get protocolLog => List.unmodifiable(_protocolLog);

  void log(String message) {
    debugPrint("[${DateTime.now().toString().substring(11, 19)}] $message");
  }

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

  void setLastLog(String message) {
    _lastLog = message;
    // notifyListeners(); // Optional in original code, but we might want it if UI binds to it
  }

  void clearLogs() {
    _protocolLog.clear();
    notifyListeners();
  }
}
