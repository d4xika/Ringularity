import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/weekly_goal_model.dart';

/// Tracks the user's overarching daily targets and custom weekly fitness goals.
///
/// This service utilizes SharedPreferences to persist the targets (e.g. 10000 steps)
/// so they survive app restarts and can be used to calculate UI progress rings.
class GoalService extends ChangeNotifier {
  int _goalSteps = 10000;
  double _goalSleep = 8.0;
  int _goalActivity = 30;

  List<WeeklyGoal> _weeklyGoals = [];

  int get goalSteps => _goalSteps;
  double get goalSleep => _goalSleep;
  int get goalActivity => _goalActivity;

  /// A mutable list of specific, user-defined weekly challenges (e.g., "Run 15km this week").
  List<WeeklyGoal> get weeklyGoals => _weeklyGoals;

  static const String _keySteps = 'goal_steps';
  static const String _keySleep = 'goal_sleep';
  static const String _keyActivity = 'goal_activity';
  static const String _keyWeeklyGoals = 'weekly_goals';

  /// Loads all saved goals from local disk into memory.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _goalSteps = prefs.getInt(_keySteps) ?? 10000;
    _goalSleep = prefs.getDouble(_keySleep) ?? 8.0;
    _goalActivity = prefs.getInt(_keyActivity) ?? 30;

    final String? weeklyGoalsJson = prefs.getString(_keyWeeklyGoals);
    if (weeklyGoalsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(weeklyGoalsJson);
        _weeklyGoals = decoded.map((e) => WeeklyGoal.fromJson(e)).toList();
      } catch (e) {
        debugPrint("Error parsing weekly goals: $e");
      }
    }
    notifyListeners();
  }

  /// Updates the primary daily target thresholds and persists them.
  Future<void> updateGoals({int? steps, double? sleep, int? activity}) async {
    final prefs = await SharedPreferences.getInstance();

    if (steps != null) {
      _goalSteps = steps;
      await prefs.setInt(_keySteps, steps);
    }

    if (sleep != null) {
      _goalSleep = sleep;
      await prefs.setDouble(_keySleep, sleep);
    }

    if (activity != null) {
      _goalActivity = activity;
      await prefs.setInt(_keyActivity, activity);
    }

    notifyListeners();
  }

  /// Appends a new custom weekly challenge.
  Future<void> addWeeklyGoal(WeeklyGoal goal) async {
    _weeklyGoals.add(goal);
    notifyListeners();
    await _saveWeeklyGoals();
  }

  /// Modifies an existing custom weekly challenge by its unique ID.
  Future<void> updateWeeklyGoal(WeeklyGoal updatedGoal) async {
    final index = _weeklyGoals.indexWhere((g) => g.id == updatedGoal.id);
    if (index != -1) {
      _weeklyGoals[index] = updatedGoal;
      notifyListeners();
      await _saveWeeklyGoals();
    }
  }

  /// Deletes a specific weekly challenge.
  Future<void> removeWeeklyGoal(String id) async {
    _weeklyGoals.removeWhere((g) => g.id == id);
    notifyListeners();
    await _saveWeeklyGoals();
  }

  /// Serializes the `_weeklyGoals` list and saves it to disk.
  Future<void> _saveWeeklyGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _weeklyGoals.map((g) => g.toJson()).toList(),
    );
    await prefs.setString(_keyWeeklyGoals, encoded);
  }
}
