import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoalService extends ChangeNotifier {
  // Default values
  int _goalSteps = 10000;
  double _goalSleep = 8.0;
  int _goalActivity = 30;

  // Getters
  int get goalSteps => _goalSteps;
  double get goalSleep => _goalSleep;
  int get goalActivity => _goalActivity;

  static const String _keySteps = 'goal_steps';
  static const String _keySleep = 'goal_sleep';
  static const String _keyActivity = 'goal_activity';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _goalSteps = prefs.getInt(_keySteps) ?? 10000;
    _goalSleep = prefs.getDouble(_keySleep) ?? 8.0;
    _goalActivity = prefs.getInt(_keyActivity) ?? 30;
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
}
