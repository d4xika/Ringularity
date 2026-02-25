import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ringularity/services/user/storage_service.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/activity_model.dart';
import '../../models/app_user.dart';

/// Handles all HTTP communication with the Ruby on Rails backend.
///
/// Responsible for user authentication, pushing recorded vitals, fetching historical
/// data, and generating data exports. Maintains an internal volatile log of all
/// network traffic for debugging purposes.
class ApiService extends ChangeNotifier {
  static const String _baseUrl = 'http://10.25.6.11:3000/api';

  final List<String> _logs = [];

  /// An unmodifiable list of the 500 most recent API request/response logs.
  List<String> get logs => List.unmodifiable(_logs);

  /// Clears the internal API debugging logs.
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// Appends a timestamped string to the internal log, keeping only the latest 500 entries.
  void _log(String message) {
    final String timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final String entry = "[$timestamp] $message";
    _logs.insert(0, entry);
    if (_logs.length > 500) _logs.removeLast();
    debugPrint(entry);
    notifyListeners();
  }

  /// Uploads a batch of heart rate measurements to the backend.
  Future<void> saveHeartRate(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/heart_rate_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  /// Uploads a batch of sleep stage measurements to the backend.
  Future<void> saveSleep(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/sleep_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  /// Uploads a batch of step count measurements to the backend.
  Future<void> saveSteps(List<Map<String, dynamic>> data) async {
    debugPrint("Steps Data: $data");
    await _sendData(
      '/vitals/steps_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  /// Uploads a batch of Heart Rate Variability (HRV) measurements to the backend.
  Future<void> saveHrv(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/hrv_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  /// Uploads a batch of stress level measurements to the backend.
  Future<void> saveStress(List<Map<String, dynamic>> data) async {
    await _sendData(
      '/vitals/stress_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  /// Intercepts successful authentication responses to extract and persist the user session.
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

  /// Sends a registration payload to the backend and logs the user in if successful.
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

  /// Authenticates an existing user and establishes a local session.
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

  /// Patches the current user's profile information on the backend.
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

  /// Securely updates the user's password or email.
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
          "Success": false,
          "Error": responseData['Error'] ?? "Update failed",
        };
      }
    } catch (e) {
      return {"Success": false, "Error": "Connection error: $e"};
    }
  }

  /// Validates an existing auth token against the backend to verify session integrity.
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

  /// Pings the backend to check if it is reachable, determining if the app should enter Offline Mode.
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

  /// Fetches historical heart rate data for a specific calendar date.
  Future<List<dynamic>> getHeartRate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _getData('/vitals/get_heart_rate_logs', normalized);
  }

  /// Fetches historical sleep data, spanning from 18:00 the previous day to 18:00 on the target date.
  Future<List<dynamic>> getSleep(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day - 1, 18);
    final end = DateTime(date.year, date.month, date.day, 18);
    return _getData('/vitals/get_sleep_logs', start, end);
  }

  /// Fetches historical step data for a specific calendar date.
  Future<List<dynamic>> getSteps(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _getData('/vitals/get_steps_logs', normalized);
  }

  /// Fetches historical HRV data for a specific calendar date.
  Future<List<dynamic>> getHrv(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _getData('/vitals/get_hrv_logs', normalized);
  }

  /// Fetches historical stress data for a specific calendar date.
  Future<List<dynamic>> getStress(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _getData('/vitals/get_stress_logs', normalized);
  }

  /// Helper method performing authenticated GET requests with date-range filters.
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

  /// Helper method performing authenticated POST requests with optional conflict resolution logic.
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

  /// Uploads a completed [ActivityModel] (workout session) to the backend.
  Future<void> saveActivity(ActivityModel activity) async {
    final List<Map<String, dynamic>> data = [activity.toJson()];

    await _sendData(
      '/activities/activity_logs',
      data,
      conflictKeys: 'user_id,recorded_at',
    );
  }

  /// Fetches a list of activities within a specified date range.
  Future<List<dynamic>> getActivities(DateTime start, DateTime end) async {
    return _getData('/activities/get_activity_logs', start, end);
  }

  /// Requests the backend to delete a specific activity based on its recording timestamp.
  Future<void> deleteActivity(DateTime recordedAt) async {
    _log("DELETE: Requesting deletion for activity ar $recordedAt...");

    final timestamp = recordedAt
        .toUtc()
        .copyWith(millisecond: 0, microsecond: 0)
        .toIso8601String();

    final url = Uri.parse(
      '$_baseUrl/activities/delete_activity_logs',
    ).replace(queryParameters: {'recorded_at': timestamp});

    final user = await StorageService.getUserSession();

    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': user['user_id'].toString(),
        'X-Auth-Key': user['auth_key'].toString(),
      },
    );

    if (response.statusCode != 200) {
      _log("DELETE FAIL: ${response.statusCode} - ${response.body}");
      throw Exception("Backend error: ${response.statusCode}");
    }

    _log("DELETE SUCCESS: Activity removed from backend");
  }

  /// Requests a full JSON dump of the user's account data and opens the native share sheet to export it.
  Future<void> exportAllUserData() async {
    final user = await StorageService.getUserSession();
    final url = Uri.parse('$_baseUrl/users/export_data');

    final response = await http.get(
      url,
      headers: {
        'X-User-Id': user['user_id'].toString(),
        'X-Auth-Key': user['auth_key'].toString(),
      },
    );

    if (response.statusCode == 200) {
      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/ringularity_export.json';
      final File file = File(filePath);
      await file.writeAsString(response.body);

      final xFile = XFile(filePath);

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Here is my Ringularity export.',
          subject: 'Health Data Export',
        ),
      );

      debugPrint("Exported succesfully");
    } else {
      throw Exception("Export failed (Status: ${response.statusCode})");
    }
  }
}
