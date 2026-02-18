import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weekly_goal_model.dart';

class GoalService extends ChangeNotifier {
  // Default values
  int _goalSteps = 10000;
  double _goalSleep = 8.0;
  int _goalActivity = 30;

  List<WeeklyGoal> _weeklyGoals = [];

  // Getters
  int get goalSteps => _goalSteps;
  double get goalSleep => _goalSleep;
  int get goalActivity => _goalActivity;
  List<WeeklyGoal> get weeklyGoals => _weeklyGoals;

  static const String _keySteps = 'goal_steps';
  static const String _keySleep = 'goal_sleep';
  static const String _keyActivity = 'goal_activity';
  static const String _keyWeeklyGoals = 'weekly_goals';

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
    } else {
      // Default goal if none exist
      _weeklyGoals = [
        WeeklyGoal(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          activityType: 'Running',
          targetValue: 3,
          unit: 'hours',
        ),
      ];
    }
    notifyListeners();
  }

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

  Future<void> addWeeklyGoal(WeeklyGoal goal) async {
    _weeklyGoals.add(goal);
    notifyListeners();
    await _saveWeeklyGoals();
  }

  Future<void> updateWeeklyGoal(WeeklyGoal updatedGoal) async {
    final index = _weeklyGoals.indexWhere((g) => g.id == updatedGoal.id);
    if (index != -1) {
      _weeklyGoals[index] = updatedGoal;
      notifyListeners();
      await _saveWeeklyGoals();
    }
  }

  Future<void> removeWeeklyGoal(String id) async {
    _weeklyGoals.removeWhere((g) => g.id == id);
    notifyListeners();
    await _saveWeeklyGoals();
  }

  Future<void> _saveWeeklyGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _weeklyGoals.map((g) => g.toJson()).toList(),
    );
    await prefs.setString(_keyWeeklyGoals, encoded);
  }
}
