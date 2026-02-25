import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/activity_model.dart';
import '../api/api_service.dart';

/// Manages the state and persistence of the user's recorded workout activities.
///
/// Acts as the single source of truth for the Activity UI. It handles fetching
/// data from the local SharedPreferences cache for immediate display, and
/// bidirectional synchronization with the backend [ApiService].
class ActivityService extends ChangeNotifier {
  static const String _storageKey = 'saved_activities';

  final ApiService _apiService = ApiService();

  List<ActivityModel> _activities = [];

  /// A chronologically sorted list (newest first) of all loaded activities.
  List<ActivityModel> get activities => _activities;

  /// Creates a new [ActivityService] and automatically triggers initialization.
  ActivityService() {
    _init();
  }

  /// Bootstraps the service by loading local cache, then fetching the last 30 days from the cloud.
  Future<void> _init() async {
    await _loadFromLocal();
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    await syncFromBackend(thirtyDaysAgo, now);
  }

  /// Parses the stored JSON string from SharedPreferences into Dart objects.
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

  /// Commits a newly recorded workout to local storage, UI state, and the backend.
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

  /// Serializes the current memory state into a JSON string and writes it to disk.
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

  /// Downloads activities from the backend within the given timeframe and merges them with local data.
  /// Returns the number of newly discovered items.
  Future<int> syncFromBackend(DateTime start, DateTime end) async {
    try {
      final List<dynamic> remoteData = await _apiService.getActivities(
        start,
        end,
      );
      int newItemsCount = 0;

      if (remoteData.isNotEmpty) {
        // Use a Map keyed by timestamp to automatically dedup remote vs local items
        final Map<int, ActivityModel> activityMap = {
          for (var a in _activities) a.date.millisecondsSinceEpoch: a,
        };

        final int countBefore = activityMap.length;

        for (var json in remoteData) {
          final remote = ActivityModel.fromJson(json);
          activityMap[remote.date.millisecondsSinceEpoch] = remote;
        }

        newItemsCount = activityMap.length - countBefore;

        _activities = activityMap.values.toList();
        _activities.sort((a, b) => b.date.compareTo(a.date));

        await _saveToLocal();
        notifyListeners();
      }

      return newItemsCount;
    } catch (e) {
      debugPrint("Error syncing from backend: $e");
      return 0;
    }
  }

  /// Optimistically deletes an activity from local state, then requests backend deletion.
  /// If the backend fails, the activity is restored to the local state.
  Future<void> deleteActivity(ActivityModel activity) async {
    final int originalIndex = _activities.indexOf(activity);
    final ActivityModel deletedActivity = activity;

    _activities.removeAt(originalIndex);
    notifyListeners();
    await _saveToLocal();

    try {
      await _apiService.deleteActivity(activity.date);
      debugPrint("Activity deleted successfully from backend");
    } catch (e) {
      debugPrint("API error with deleting: $e");

      // Rollback on failure
      _activities.insert(originalIndex, deletedActivity);
      notifyListeners();
      await _saveToLocal();

      rethrow;
    }
  }
}
