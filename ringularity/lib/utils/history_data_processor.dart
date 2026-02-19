import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ringularity/models/chart_view_model.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/services/vitals_storage_service.dart';

class HistoryDataProcessor {
  final BleService service;
  final VitalsStorageService storage;

  HistoryDataProcessor({required this.service, required this.storage});

  ChartViewModel prepareChartData({
    required String title,
    required String selectedPeriod,
    required DateTime selectedDate,
  }) {
    bool isTrend = false;
    List<Point> points = [];
    DateTime startTime = selectedDate;
    int durationMinutes = 1440;
    int labelInterval = 360;
    double? averageY;

    if (title == "Sleep") {
      return _prepareSleepChartData(selectedDate);
    }

    if (selectedPeriod == "D") {
      startTime = DateUtils.dateOnly(selectedDate);

      if (_isToday(selectedDate)) {
        points = _getLiveDailyPoints(title);
      } else {
        final dayData = storage.getVitalsForDate(startTime);
        if (dayData != null) {
          points = _extractTrace(dayData, title);
        }
      }

      // Convert to Cumulative for Steps and Distance in Daily View
      // User requested "aggregated values" (line chart rising) instead of bars (deltas)
      if (title == "Steps" || title == "Distance") {
        double runningTotal = 0;
        final List<Point> cumulativePoints = [];
        for (final p in points) {
          runningTotal += p.y;
          cumulativePoints.add(Point(p.x, runningTotal));
        }
        points = cumulativePoints;
      }
    } else if (selectedPeriod == "W") {
      isTrend = true;
      startTime = DateUtils.dateOnly(
        selectedDate,
      ).subtract(Duration(days: selectedDate.weekday - 1));
      durationMinutes = 7; // days
      final List<double> weekly = _prepareWeeklyData(title, startTime);
      for (int i = 0; i < weekly.length; i++) {
        if (weekly[i] > 0) points.add(Point(i, weekly[i]));
      }
    } else if (selectedPeriod == "M") {
      isTrend = true;
      startTime = DateTime(selectedDate.year, selectedDate.month, 1);
      durationMinutes = DateTime(
        selectedDate.year,
        selectedDate.month + 1,
        0,
      ).day;
      final List<double> monthly = _prepareMonthlyData(
        title,
        startTime,
        durationMinutes,
      );
      for (int i = 0; i < monthly.length; i++) {
        if (monthly[i] > 0) points.add(Point(i, monthly[i]));
      }
    } else if (selectedPeriod == "Y") {
      isTrend = true;
      startTime = DateTime(selectedDate.year, 1, 1);
      durationMinutes = 12;
      final List<double> yearly = _prepareYearlyData(title, startTime.year);
      for (int i = 0; i < yearly.length; i++) {
        if (yearly[i] > 0) points.add(Point(i, yearly[i]));
      }
    }

    if (isTrend && points.isNotEmpty) {
      final validData = points.map((p) => p.y.toDouble()).toList();
      if (validData.isNotEmpty) {
        averageY = validData.reduce((a, b) => a + b) / validData.length;
      }
    }

    if (selectedPeriod == "D") {
      labelInterval = 360;
    } else {
      labelInterval = 1;
    }

    double? minX;
    double? maxX;
    if (points.isNotEmpty) {
      minX = points.map((p) => p.x.toDouble()).reduce(min);
      maxX = points.map((p) => p.x.toDouble()).reduce(max);
      if (minX == maxX) maxX += 0.001; // Avoid division by zero range
    }

    return ChartViewModel(
      points,
      _buildLabels(
        startTime,
        durationMinutes,
        labelInterval, // Not strictly used by some views
        selectedPeriod,
        minX: minX,
        maxX: maxX,
      ),
      0, // min/max handled by caller if needed, or by chart
      0,
      startTime,
      durationMinutes,
      labelInterval,
      isTrend: isTrend,
      averageY: averageY,
    );
  }

  // Helper for Sleep Chart Data (keeps simplified logic for now)
  ChartViewModel _prepareSleepChartData(DateTime selectedDate) {
    return ChartViewModel(
      [],
      Container(), // labels
      0,
      100, // min/max
      selectedDate,
      1440,
      360,
    );
  }

  List<Point> _getLiveDailyPoints(String title) {
    final manager = service.dataManager;
    List<Point> raw = [];
    switch (title) {
      case "HR":
        raw = List.from(manager.hrHistory);
        break;
      case "Steps":
        raw = manager.stepsHistory.map((p) => Point(p.x * 15, p.y)).toList();
        break;
      case "Distance":
        raw = manager.stepsHistory
            .map((p) => Point(p.x * 15, (p.y * 0.762).round()))
            .toList();
        break;
      case "SpO2":
        raw = List.from(manager.spo2History);
        break;
      case "Stress":
        raw = List.from(manager.stressHistory);
        break;
      case "HRV":
        raw = List.from(manager.hrvHistory);
        break;
    }
    raw.sort((a, b) => a.x.compareTo(b.x));
    return raw;
  }

  List<Point> _extractTrace(DailyVitals data, String title) {
    switch (title) {
      case "HR":
        final hr = List<Point>.from(data.hrTrace);
        hr.sort((a, b) => a.x.compareTo(b.x));
        return hr;
      case "Steps":
        final steps = data.stepsTrace.map((p) => Point(p.x * 15, p.y)).toList();
        steps.sort((a, b) => a.x.compareTo(b.x));
        return steps;
      case "Distance":
        final dist = data.stepsTrace
            .map((p) => Point(p.x * 15, (p.y * 0.762).round()))
            .toList();
        dist.sort((a, b) => a.x.compareTo(b.x));
        return dist;
      case "SpO2":
        final spo2 = List<Point>.from(data.spo2Trace);
        spo2.sort((a, b) => a.x.compareTo(b.x));
        return spo2;
      case "Stress":
        final stress = List<Point>.from(data.stressTrace);
        stress.sort((a, b) => a.x.compareTo(b.x));
        return stress;
      case "HRV":
        final hrv = List<Point>.from(data.hrvTrace);
        hrv.sort((a, b) => a.x.compareTo(b.x));
        return hrv;
      default:
        return [];
    }
  }

  double _getDailyValue(String title, DailyVitals? data, DateTime date) {
    if (_isToday(date)) {
      switch (title) {
        case "Steps":
          return service.steps.toDouble();
        case "Distance":
          return service.distance / 1000.0; // km
        case "HR":
          return service.heartRate.toDouble();
        case "Stress":
          return service.stress.toDouble();
        case "SpO2":
          return service.spo2.toDouble();
        case "HRV":
          // Check if hrv exists on service, if not use 0 or manager
          return service.hrv.toDouble();
        default:
          return 0.0;
      }
    }

    if (data == null) return 0.0;

    switch (title) {
      case "Steps":
        return data.steps.toDouble();
      case "Distance":
        return data.distance / 1000.0;
      case "HR":
        return data.avgHr.toDouble();
      case "Stress":
        return data.avgStress.toDouble();
      case "SpO2":
        return data.avgSpo2.toDouble();
      case "HRV":
        return data.avgHrv.toDouble();
      default:
        return 0.0;
    }
  }

  List<double> _prepareWeeklyData(String title, DateTime startOfWeek) {
    final List<double> weekData = List.generate(7, (index) => 0.0);
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      weekData[i] = _getDailyValue(title, storage.getVitalsForDate(date), date);
    }
    return weekData;
  }

  List<double> _prepareMonthlyData(
    String title,
    DateTime startOfMonth,
    int daysInMonth,
  ) {
    final List<double> monthlyData = List.generate(daysInMonth, (index) => 0.0);
    for (int i = 0; i < daysInMonth; i++) {
      final date = DateTime(startOfMonth.year, startOfMonth.month, i + 1);
      monthlyData[i] = _getDailyValue(
        title,
        storage.getVitalsForDate(date),
        date,
      );
    }
    return monthlyData;
  }

  List<double> _prepareYearlyData(String title, int year) {
    final List<double> yearlyData = List.generate(12, (index) => 0.0);
    // Yearly aggregation: avg of month (or total for steps?)
    // For visualization simplicity, accumulating daily vals
    for (int m = 1; m <= 12; m++) {
      double sum = 0;
      int count = 0;
      final daysInMonth = DateTime(year, m + 1, 0).day;
      for (int d = 1; d <= daysInMonth; d++) {
        final date = DateTime(year, m, d);
        final val = _getDailyValue(title, storage.getVitalsForDate(date), date);
        if (val > 0) {
          sum += val;
          count++;
        }
      }
      if (count > 0) {
        yearlyData[m - 1] = sum / count;
      }
    }
    return yearlyData;
  }

  (double minY, double maxY) calculateYRange(List<Point> data, String title) {
    final valid = data.where((p) => !p.y.isNaN && p.y > 0).toList();

    if (valid.isEmpty) return (0.0, 100.0);

    final double minVal = valid.map((p) => p.y.toDouble()).reduce(min);
    final double maxVal = valid.map((p) => p.y.toDouble()).reduce(max);

    if (minVal == maxVal) {
      double min = minVal == 0 ? 0.0 : minVal - 10;
      if (min < 0) min = 0.0;
      return (min, maxVal + 10);
    }

    final double padding = (maxVal - minVal) * 0.1;
    double calculatedMin = minVal - padding;
    final double calculatedMax = maxVal + padding;

    const zeroBottomTypes = [
      "Steps",
      "Sleep",
      "Distance",
      "Oxygen",
      "Stress",
      "HRV",
    ];

    if (zeroBottomTypes.contains(title)) {
      calculatedMin = 0.0;
    }

    if (calculatedMin < 0) {
      calculatedMin = 0.0;
    }

    return (calculatedMin, calculatedMax);
  }

  Widget _buildLabels(
    DateTime start,
    int duration,
    int interval,
    String period, {
    double? minX,
    double? maxX,
  }) {
    if (minX == null || maxX == null) return Container();
    final double range = maxX - minX;
    if (range <= 0) return Container();

    // 1. Determine "Clean" Interval
    double step = range / 5;
    if (period == "D") {
      // Snap to nice minutes
      const nice = [15, 30, 60, 120, 180, 240, 300, 360, 480];
      step = nice.firstWhere((n) => n >= step, orElse: () => 480).toDouble();
    } else if (period == "W") {
      step = 1; // 1 day
    } else if (period == "M") {
      step = 5; // 5 days
    } else if (period == "Y") {
      step = 1; // 1 month
    }

    // 2. Generate Labels
    final List<Widget> labelWidgets = [];

    // Start at the first multiple of step >= minX
    double current = (minX / step).ceil() * step;

    if (current < minX) current += step;

    // Safety limit to prevent infinite loops if step is 0 (shouldn't happen)
    int safety = 0;
    while (current <= maxX && safety < 10) {
      final double t = (current - minX) / range; // 0..1

      // Build Text
      String text = "";
      if (period == "D") {
        final date = start.add(Duration(minutes: current.round()));
        text = DateFormat('HH:mm').format(date);
      } else if (period == "W") {
        final date = start.add(Duration(days: current.round()));
        text = DateFormat('E').format(date);
      } else if (period == "M") {
        text = "${current.round() + 1}";
      } else if (period == "Y") {
        final date = DateTime(start.year, current.round() + 1, 1);
        text = DateFormat('MMM').format(date);
      }

      // Alignment Map 0..1 to -1..1
      final align = Alignment(t * 2 - 1, 0);

      labelWidgets.add(
        Align(
          alignment: align,
          child: Text(
            text,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ),
      );

      current += step;
      safety++;
    }

    return SizedBox(height: 20, child: Stack(children: labelWidgets));
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
