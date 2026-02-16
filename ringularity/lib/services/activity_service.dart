import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_model.dart';

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
      debugPrint("Fehler beim Laden der Aktivitäten: $e");
    }
  }

  Future<void> addActivity(ActivityModel activity) async {
    _activities.add(activity);

    _activities.sort((a, b) => b.date.compareTo(a.date));

    notifyListeners();

    await _saveToLocal();

    // TODO API Sync anstoßen
    // _syncToApi(activity);
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> jsonList = _activities
          .map((a) => a.toJson())
          .toList();

      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Fehler beim Speichern der Aktivitäten: $e");
    }
  }
}
