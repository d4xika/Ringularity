import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_model.dart';
import 'api/api_service.dart';

class ActivityService extends ChangeNotifier {
  static const String _storageKey = 'saved_activities';

  final ApiService _apiService = ApiService();

  List<ActivityModel> _activities = [];

  List<ActivityModel> get activities => _activities;

  ActivityService() {
    _init();
  }

  Future<void> _init() async {
    await _loadFromLocal();
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    await syncFromBackend(thirtyDaysAgo, now);
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

  Future<void> addActivity(ActivityModel activity) async {
    _activities.insert(0, activity);
    notifyListeners();
    await _saveToLocal();

    try {
      await _apiService.saveActivity(activity);
    } catch (e) {
      debugPrint("Sync failed, stays local for now: $e");
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

  Future<void> syncFromBackend(DateTime start, DateTime end) async {
    try {
      final List<dynamic> remoteData = await _apiService.getActivities(
        start,
        end,
      );
      if (remoteData.isNotEmpty) {
        final Map<int, ActivityModel> activityMap = {
          for (var a in _activities) a.date.millisecondsSinceEpoch: a,
        };

        for (var json in remoteData) {
          final remote = ActivityModel.fromJson(json);
          activityMap[remote.date.millisecondsSinceEpoch] = remote;
        }

        _activities = activityMap.values.toList();
        _activities.sort((a, b) => b.date.compareTo(a.date));

        await _saveToLocal();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error syncing from backend: $e");
    }
  }
}
