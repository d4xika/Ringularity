import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ringularity/services/secure_storage_service.dart';

import '../../models/activity_model.dart';

class ApiService extends ChangeNotifier {
  static const String _baseUrl = 'http://10.25.6.11:3000/api';

  //TODO: add button to sync data to the backend
  //and back to phone

  // Logger
  // Keeps an in-memory log of API requests involved for debugging purposes.
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void _log(String message) {
    final String timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final String entry = "[$timestamp] $message";
    _logs.insert(0, entry);
    if (_logs.length > 500) _logs.removeLast();
    debugPrint(entry);
    notifyListeners();
  }

  // --- Data Upload ---
  // Methods to post local sensor data to the backend API.
  // We use the 'Ignore Duplicates' preference to handle re-uploads gracefully.

  Future<void> saveHeartRate(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/heart_rate_logs',
      data,
      conflictKeys: 'device_id,recorded_at',
    );
  }

  Future<void> saveSleep(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/sleep_logs',
      data,
      conflictKeys: 'device_id,recorded_at',
    );
  }

  Future<void> saveSteps(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/steps_logs',
      data,
      conflictKeys: 'device_id,recorded_at',
    );
  }

  Future<void> saveHrv(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/hrv_logs',
      data,
      conflictKeys: 'device_id,recorded_at',
    );
  }

  Future<void> saveStress(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/stress_logs',
      data,
      conflictKeys: 'device_id,recorded_at',
    );
  }

  Future<dynamic> registerUser(Map<String, dynamic> data) async {
    _log("[REGISTER_USER] Send to backend...");

    final response = await http.post(
      Uri.parse('$_baseUrl/users/register'),
      headers: {
        'Content-Type': 'application/json',
        'Prefer': 'resolution=ignore-duplicates',
      },
      body: jsonEncode(data),
    );

    return response;
  }

  Future<dynamic> loginUser(Map<String, dynamic> data) async {
    _log("[LOGIN_USER] Send to backend...");

    final response = await http.post(
      Uri.parse('$_baseUrl/users/login'),
      headers: {
        'Content-Type': 'application/json',
        'Prefer': 'resolution=ignore-duplicates',
      },
      body: jsonEncode(data),
    );

    return response;
  }

  Future<dynamic> authorizeUser(Map<String?, String?> data) async {
    _log("[AUTHORIZE_USER] Send to backend...");

    final response = await http.post(
      Uri.parse('$_baseUrl/users/authorize'),
      headers: {
        'Content-Type': 'application/json',
        'Prefer': 'resolution=ignore-duplicates',
      },
      body: jsonEncode(data),
    );

    return response;
  }

  // --- Retrieval Methods ---
  // Fetch historical data from the API for a specific device and date.

  Future<List<dynamic>> getHeartRate(String deviceId, DateTime date) async {
    return _getData('/vitals/get_heart_rate_logs', deviceId, date);
  }

  Future<List<dynamic>> getSleep(String deviceId, DateTime date) async {
    return _getData('/vitals/get_sleep_logs', deviceId, date);
  }

  Future<List<dynamic>> getSteps(String deviceId, DateTime date) async {
    return _getData('/vitals/get_steps_logs', deviceId, date);
  }

  Future<List<dynamic>> getHrv(String deviceId, DateTime date) async {
    return _getData('/vitals/get_hrv_logs', deviceId, date);
  }

  Future<List<dynamic>> getStress(String deviceId, DateTime date) async {
    return _getData('/vitals/get_stress_logs', deviceId, date);
  }

  // Generic helper to GET data ranges filtering by device_id and date.
  Future<List<dynamic>> _getData(
    String endpoint,
    String deviceId,
    DateTime date,
  ) async {
    // Determine the 24-hour window for the request
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final startStr = startOfDay.toIso8601String();
    final endStr = endOfDay.toIso8601String();

    final queryString = "recorded_at_start=$startStr&recorded_at_end=$endStr";
    final uri = Uri.parse('$_baseUrl$endpoint?$queryString');

    _log("SYNC: GET $uri");

    final user = await StorageService.getUserSession();

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': user['user_id'].toString(),
          'X-Auth-Key': user['auth_key'].toString(),
        },
      );
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

  Future<void> _sendData(
    String endpoint,
    List<Map<String, dynamic>> data, {
    String? conflictKeys,
  }) async {
    if (data.isEmpty) return;
    _log("SYNC: Sending ${data.length} items to $endpoint...");

    try {
      String url = '$_baseUrl$endpoint';
      if (conflictKeys != null) {
        url += '?on_conflict=$conflictKeys';
      }
      final user = await StorageService.getUserSession();

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Prefer': 'resolution=ignore-duplicates',
          'X-User-Id': user['user_id'].toString(),
          'X-Auth-Key': user['auth_key'].toString(),
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

  Future<void> saveActivity(ActivityModel activity) async {
    final List<Map<String, dynamic>> data = [activity.toJson()];

    await _sendData(
      '/vitals/activity_logs',
      data,
      conflictKeys: 'device_id,recorded_at',
    );
  }

  // Pfad passt noch nicht
  Future<List<dynamic>> getActivities(DateTime date) async {
    return _getData('/vitals/get_activity_logs', "device_placeholder", date);
  }
}
