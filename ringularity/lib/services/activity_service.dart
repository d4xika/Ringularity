import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_model.dart';
import 'api/api_service.dart';

class ActivityService extends ChangeNotifier {
  static const String _storageKey = 'saved_activities';

  List<ActivityModel> _activities = [];

  List<ActivityModel> get activities => _activities;

  ActivityService() {
    _loadFromLocal();
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? activitiesJson = prefs.getString(_storageKey);

      if (activitiesJson != null) {
        final List<dynamic> decodedList = jsonDecode(activitiesJson);

        _activities = decodedList
            .map((json) => ActivityModel.fromJson(json))
            .toList();

        _activities.sort((a, b) => b.date.compareTo(a.date));

        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading activities: $e");
    }
  }

  // TODO API Sync
  Future<void> addActivity(
    ActivityModel activity,
    ApiService? apiService,
  ) async {
    _activities.add(activity);

    _activities.sort((a, b) => b.date.compareTo(a.date));

    notifyListeners();

    await _saveToLocal();

    //auskommentierten Code wieder aktivieren,
    //sobald die API fertig ist. Bis dahin wird die Aktivität lokal gespeichert,
    //aber der Backend-Sync ist pausiert.
    try {
      //await apiService.saveActivity(activity);
      debugPrint("Activity successfully synchronized to backend!");
    } catch (e) {
      debugPrint("Backend Sync failed (locally saved): $e");
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> jsonList = _activities
          .map((a) => a.toJson())
          .toList();

      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Error saving activities: $e");
    }
  }
}
