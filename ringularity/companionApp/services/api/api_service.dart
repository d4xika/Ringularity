import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService extends ChangeNotifier {
  static const String _baseUrl = 'http://10.25.6.11:3000';

  // Logger
  // Keeps an in-memory log of API requests involved for debugging purposes.
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void _log(String message) {
    String timestamp = DateTime.now().toIso8601String().substring(11, 19);
    String entry = "[$timestamp] $message";
    _logs.insert(0, entry);
    if (_logs.length > 500) _logs.removeLast();
    debugPrint(entry);
    notifyListeners();
  }

  // --- Data Upload ---
  // Methods to post local sensor data to the backend API.
  // We use the 'Ignore Duplicates' preference to handle re-uploads gracefully.

  Future<void> saveHeartRate(List<Map<String, dynamic>> data) async {
    await _sendData('/heart_rate_logs', data,
        conflictKeys: 'device_id,recorded_at');
  }

  Future<void> saveSpo2(List<Map<String, dynamic>> data) async {
    await _sendData('/spo2_logs', data, conflictKeys: 'device_id,recorded_at');
  }

  Future<void> saveSleep(List<Map<String, dynamic>> data) async {
    await _sendData('/sleep_logs', data, conflictKeys: 'device_id,recorded_at');
  }

  Future<void> saveSteps(List<Map<String, dynamic>> data) async {
    await _sendData('/steps_logs', data, conflictKeys: 'device_id,recorded_at');
  }

  Future<void> saveHrv(List<Map<String, dynamic>> data) async {
    await _sendData('/hrv_logs', data, conflictKeys: 'device_id,recorded_at');
  }

  Future<void> saveStress(List<Map<String, dynamic>> data) async {
    await _sendData('/stress_logs', data,
        conflictKeys: 'device_id,recorded_at');
  }

  // --- Retrieval Methods ---
  // Fetch historical data from the API for a specific device and date.

  Future<List<dynamic>> getHeartRate(String deviceId, DateTime date) async {
    return _getData('/heart_rate_logs', deviceId, date);
  }

  Future<List<dynamic>> getSpo2(String deviceId, DateTime date) async {
    return _getData('/spo2_logs', deviceId, date);
  }

  Future<List<dynamic>> getSleep(String deviceId, DateTime date) async {
    return _getData('/sleep_logs', deviceId, date);
  }

  Future<List<dynamic>> getSteps(String deviceId, DateTime date) async {
    return _getData('/steps_logs', deviceId, date);
  }

  Future<List<dynamic>> getHrv(String deviceId, DateTime date) async {
    return _getData('/hrv_logs', deviceId, date);
  }

  Future<List<dynamic>> getStress(String deviceId, DateTime date) async {
    return _getData('/stress_logs', deviceId, date);
  }

  // Generic helper to GET data ranges filtering by device_id and date.
  Future<List<dynamic>> _getData(
      String endpoint, String deviceId, DateTime date) async {
    // Determine the 24-hour window for the request
    final startOfDay = DateTime(date.year, date.month, date.day);
    // ...
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final startStr = startOfDay.toIso8601String();
    final endStr = endOfDay.toIso8601String();

    final queryString =
        "device_id=eq.$deviceId&recorded_at=gte.$startStr&recorded_at=lt.$endStr";
    final uri = Uri.parse('$_baseUrl$endpoint?$queryString');

    _log("SYNC: GET $uri");

    try {
      final response = await http.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body);
        _log("SUCCESS: GET $endpoint (${data.length} items)");
        return data;
      } else {
        _log("FAIL: GET $endpoint (${response.statusCode}) - ${response.body}");
        return [];
      }
    } catch (e) {
      _log("ERROR: GET $endpoint - $e");
      return [];
    }
  }

  Future<void> _sendData(String endpoint, List<Map<String, dynamic>> data,
      {String? conflictKeys}) async {
    if (data.isEmpty) return;
    _log("SYNC: Sending ${data.length} items to $endpoint...");

    try {
      String url = '$_baseUrl$endpoint';
      if (conflictKeys != null) {
        url += '?on_conflict=$conflictKeys';
      }
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Prefer': 'resolution=ignore-duplicates',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode >= 200 && response.statusCode <= 300) {
        _log("SUCCESS: $endpoint (${response.statusCode})");
      } else {
        _log("FAIL: $endpoint (${response.statusCode}) - ${response.body}");
        throw Exception('Failed to sync data: ${response.statusCode}');
      }
    } catch (e) {
      _log("ERROR: $endpoint - $e");
      rethrow;
    }
  }
}
