import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ringularity/services/user/storage_service.dart';
import '../../models/app_user.dart';

import '../../models/activity_model.dart';

class ApiService extends ChangeNotifier {
  static const String _baseUrl = 'http://10.25.6.11:3000/api';

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
      conflictKeys: 'user_id,recorded_at',
    );
  }

  Future<void> saveSleep(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/sleep_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  Future<void> saveSteps(List<Map<String, dynamic>> data) async {
    debugPrint("Steps Data: $data");
    await _sendData(
      '/vitals/steps_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  Future<void> saveHrv(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/hrv_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  Future<void> saveStress(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/stress_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  Future<void> _handleAuthResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);

      await StorageService.saveUserSession(
        body['auth_key'],
        body['user_id'].toString(),
      );

      final user = AppUser.fromJson(body);
      await StorageService.saveUserProfile(user);
    }
  }

  Future<dynamic> registerUser(Map<String, dynamic> data) async {
    _log("[REGISTER_USER] Send to backend...");

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/users/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 5));

      await _handleAuthResponse(response);
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> loginUser(Map<String, dynamic> data) async {
    _log("[LOGIN_USER] Send to backend...");

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/users/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 5));

      await _handleAuthResponse(response);
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateUser(String name, String birthdate) async {
    try {
      final session = await StorageService.getUserSession();

      final response = await http
          .patch(
            Uri.parse('$_baseUrl/users/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "user_id": session['user_id'],
              "auth_key": session['auth_key'],
              "name": name,
              "birthday": birthdate,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await _handleAuthResponse(response);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> updateSecurity({
    required String currentPassword,
    String? newEmail,
    String? newPassword,
  }) async {
    try {
      final session = await StorageService.getUserSession();

      final response = await http
          .post(
            Uri.parse('$_baseUrl/users/security_update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "user_id": session['user_id'],
              "auth_key": session['auth_key'],
              "current_password": currentPassword,
              if (newEmail != null) "new_email": newEmail,
              if (newPassword != null) "new_password": newPassword,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await StorageService.saveUserSession(
          responseData['auth_key'],
          session['user_id']!,
        );

        final user = AppUser.fromJson(responseData);
        await StorageService.saveUserProfile(user);

        return {"success": true};
      } else {
        return {
          "success": false,
          "error": responseData['error'] ?? "Update failed",
        };
      }
    } catch (e) {
      return {"success": false, "error": "Connection error: $e"};
    }
  }

  Future<dynamic> authorizeUser(Map<String?, String?> data) async {
    _log("[AUTHORIZE_USER] Send to backend...");

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/users/authorize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 5));

      await _handleAuthResponse(response);
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<bool> checkIfAlive() async {
    _log("[CHECK_IF_ALIVE] Send to backend...");

    try {
      await http
          .get(
            Uri.parse('$_baseUrl/alive'),
            headers: {
              'Content-Type': 'application/json',
              'Prefer': 'resolution=ignore-duplicates',
            },
          )
          .timeout(const Duration(seconds: 5));

      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Retrieval Methods ---
  // Fetch historical data from the API for a specific date.

  Future<List<dynamic>> getHeartRate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _getData('/vitals/get_heart_rate_logs', normalized);
  }

  Future<List<dynamic>> getSleep(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day - 1, 18);
    final end = DateTime(date.year, date.month, date.day, 18);
    return _getData('/vitals/get_sleep_logs', start, end);
  }

  Future<List<dynamic>> getSteps(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _getData('/vitals/get_steps_logs', normalized);
  }

  Future<List<dynamic>> getHrv(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _getData('/vitals/get_hrv_logs', normalized);
  }

  Future<List<dynamic>> getStress(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _getData('/vitals/get_stress_logs', normalized);
  }

  // Generic helper to GET data ranges filtering by user_id and date.
  Future<List<dynamic>> _getData(
    String endpoint,
    DateTime start, [
    DateTime? end,
  ]) async {
    final startStr = start.toIso8601String();
    final endStr =
        (end ??
                DateTime(
                  start.year,
                  start.month,
                  start.day,
                ).add(const Duration(days: 1)))
            .toIso8601String();

    final queryString = "recorded_at_start=$startStr&recorded_at_end=$endStr";
    final uri = Uri.parse('$_baseUrl$endpoint?$queryString');

    _log("SYNC: GET $uri");

    final user = await StorageService.getUserSession();

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-User-Id': user['user_id'].toString(),
              'X-Auth-Key': user['auth_key'].toString(),
            },
          )
          .timeout(const Duration(seconds: 5));
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

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Prefer': 'resolution=ignore-duplicates',
              'X-User-Id': user['user_id'].toString(),
              'X-Auth-Key': user['auth_key'].toString(),
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 5));

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
      '/activities/activity_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  Future<List<dynamic>> getActivities(DateTime start, DateTime end) async {
    return _getData('/activities/get_activity_logs', start, end);
  }
}
