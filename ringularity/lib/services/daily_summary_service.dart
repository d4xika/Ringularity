import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_summary_model.dart';

/// Manages a lightweight, infinite timeline of the user's daily macro-progress.
///
/// Unlike [VitalsStorageService] which drops data after 7 days, this service permanently
/// stores the top-level aggregates (Total Steps, Total Sleep, Activity Minutes) and the specific
/// *historical goals* the user had configured on that exact day. This powers the infinite scroll
/// on the `CalendarScreen` without requiring network calls.
class DailySummaryService extends ChangeNotifier {
  static const String _storageKey = 'daily_summaries';

  List<DailySummaryModel> _summaries = [];

  List<DailySummaryModel> get summaries => _summaries;

  /// Creates a new [DailySummaryService] and loads the timeline into memory.
  DailySummaryService() {
    _loadFromLocal();
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final List<dynamic> decodedList = jsonDecode(jsonString);

        _summaries = decodedList
            .map((json) => DailySummaryModel.fromJson(json))
            .toList();

        _summaries.sort((a, b) => b.date.compareTo(a.date));

        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading daily summaries: $e");
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> jsonList = _summaries
          .map((s) => s.toJson())
          .toList();

      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Error saving daily summaries: $e");
    }
  }

  /// Retrieves the macro totals and goals for a specific past date.
  DailySummaryModel? getSummaryForDate(DateTime targetDate) {
    try {
      return _summaries.firstWhere(
        (summary) => DateUtils.isSameDay(summary.date, targetDate),
      );
    } catch (e) {
      return null;
    }
  }

  /// Creates or overwrites the snapshot for a given day. Usually called at the end of a sync or workout.
  Future<void> saveOrUpdateDay({
    required DateTime date,
    required int steps,
    required double sleepHours,
    required int activityMinutes,
    required int goalSteps,
    required double goalSleep,
    required int goalActivity,
  }) async {
    final newSummary = DailySummaryModel(
      date: date,
      steps: steps,
      sleepHours: sleepHours,
      activityMinutes: activityMinutes,
      goalSteps: goalSteps,
      goalSleep: goalSleep,
      goalActivity: goalActivity,
    );

    final index = _summaries.indexWhere(
      (s) => DateUtils.isSameDay(s.date, date),
    );

    if (index >= 0) {
      _summaries[index] = newSummary;
    } else {
      _summaries.add(newSummary);
    }

    _summaries.sort((a, b) => b.date.compareTo(a.date));

    notifyListeners();
    await _saveToLocal();
  }
}
