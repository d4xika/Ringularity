import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/sleep_data_model.dart';

class DailyVitals {
  final DateTime date;

  final int steps;
  final int distance;
  final int avgHr;
  final int avgStress;
  final int avgSpo2;
  final int avgHrv;
  final int totalSleepMinutes;

  final List<Point> hrTrace;
  final List<Point> stepsTrace;
  final List<Point> spo2Trace;
  final List<Point> stressTrace;
  final List<Point> hrvTrace;
  final List<SleepData> sleepTrace;

  DailyVitals({
    required this.date,
    required this.steps,
    required this.distance,
    required this.avgHr,
    required this.avgStress,
    required this.avgSpo2,
    required this.avgHrv,
    required this.totalSleepMinutes,
    required this.hrTrace,
    required this.stepsTrace,
    required this.spo2Trace,
    required this.stressTrace,
    required this.hrvTrace,
    required this.sleepTrace,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'steps': steps,
    'distance': distance,
    'avgHr': avgHr,
    'avgStress': avgStress,
    'avgSpo2': avgSpo2,
    'avgHrv': avgHrv,
    'totalSleepMinutes': totalSleepMinutes,

    'hrTrace': hrTrace.map((p) => {'x': p.x, 'y': p.y}).toList(),
    'stepsTrace': stepsTrace.map((p) => {'x': p.x, 'y': p.y}).toList(),
    'spo2Trace': spo2Trace.map((p) => {'x': p.x, 'y': p.y}).toList(),
    'stressTrace': stressTrace.map((p) => {'x': p.x, 'y': p.y}).toList(),
    'hrvTrace': hrvTrace.map((p) => {'x': p.x, 'y': p.y}).toList(),
    'sleepTrace': sleepTrace.map((s) => s.toJson()).toList(),
  };

  factory DailyVitals.fromJson(Map<String, dynamic> json) {
    List<Point> parsePoints(String key) {
      if (json[key] == null) return [];
      return (json[key] as List).map((e) => Point(e['x'], e['y'])).toList();
    }

    return DailyVitals(
      date: DateTime.parse(json['date']),
      steps: json['steps'] ?? 0,
      distance: json['distance'] ?? 0,
      avgHr: json['avgHr'] ?? 0,
      avgStress: json['avgStress'] ?? 0,
      avgSpo2: json['avgSpo2'] ?? 0,
      avgHrv: json['avgHrv'] ?? 0,
      totalSleepMinutes: json['totalSleepMinutes'] ?? 0,

      hrTrace: parsePoints('hrTrace'),
      stepsTrace: parsePoints('stepsTrace'),
      spo2Trace: parsePoints('spo2Trace'),
      stressTrace: parsePoints('stressTrace'),
      hrvTrace: parsePoints('hrvTrace'),
      sleepTrace:
          (json['sleepTrace'] as List?)
              ?.map((e) => SleepData.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class VitalsStorageService extends ChangeNotifier {
  static const String _storageKey = 'vitals_7day_cache';
  List<DailyVitals> _weeklyData = [];

  List<DailyVitals> get weeklyData => _weeklyData;

  VitalsStorageService() {
    _loadFromLocal();
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null) {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      _weeklyData = decoded.map((e) => DailyVitals.fromJson(e)).toList();

      _pruneOldData();
      notifyListeners();
    }
  }

  Future<void> saveToday(DailyVitals todayData) async {
    final int index = _weeklyData.indexWhere(
      (d) => _isSameDay(d.date, todayData.date),
    );

    if (index >= 0) {
      _weeklyData[index] = todayData;
    } else {
      _weeklyData.add(todayData);
    }

    _pruneOldData();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _weeklyData.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
  }

  void _pruneOldData() {
    final now = DateTime.now();
    final limit = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 7));

    _weeklyData.removeWhere((d) => d.date.isBefore(limit));
    _weeklyData.sort((a, b) => a.date.compareTo(b.date));
  }

  DailyVitals? getVitalsForDate(DateTime targetDate) {
    try {
      return _weeklyData.firstWhere((d) => _isSameDay(d.date, targetDate));
    } catch (e) {
      return null;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
