import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ringularity/models/chart_view_model.dart';
import 'package:ringularity/models/sleep_data_model.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/services/health/vitals_storage_service.dart';

import '../../theme/text_styles.dart';

/// A computational utility class responsible for transforming raw metric data into renderable chart models.
///
/// It pulls raw points from either the live `BleService` or the historical `VitalsStorageService`,
/// applies necessary math (like calculating cumulative totals or daily averages), and structures
/// them into a `ChartViewModel` tailored for specific time periods (Day, Week, Month, Year).
class HistoryDataProcessor {
  final BleService service;
  final VitalsStorageService storage;

  /// Creates a new [HistoryDataProcessor] linked to the active data providers.
  HistoryDataProcessor({required this.service, required this.storage});

  /// The main entry point to construct a `ChartViewModel` for the UI.
  ///
  /// [title] dictates the metric being processed (e.g., "HR", "Steps").
  /// [selectedPeriod] dictates the aggregation window ("D", "W", "M", "Y").
  /// [selectedDate] provides the chronological anchor point.
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
    } else if (selectedPeriod == "W") {
      isTrend = true;
      startTime = DateUtils.dateOnly(
        selectedDate,
      ).subtract(Duration(days: selectedDate.weekday - 1));
      durationMinutes = 7;
      final List<double> weekly = _prepareWeeklyData(title, startTime);
      for (int i = 0; i < weekly.length; i++) {
        points.add(Point(i, weekly[i]));
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
        points.add(Point(i, monthly[i]));
      }
    } else if (selectedPeriod == "Y") {
      isTrend = true;
      startTime = DateTime(selectedDate.year, 1, 1);
      durationMinutes = 12;
      final List<double> yearly = _prepareYearlyData(title, startTime.year);
      for (int i = 0; i < yearly.length; i++) {
        points.add(Point(i, yearly[i]));
      }
    }

    final bool skipDailyCumulativeAvg =
        selectedPeriod == "D" && (title == "Steps" || title == "Distance");

    if (!skipDailyCumulativeAvg && points.isNotEmpty) {
      final validData = points
          .where((p) => p.y > 0 && !p.y.isNaN)
          .map((p) => p.y.toDouble())
          .toList();

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
      if (minX == maxX) maxX += 0.001;
    }

    return ChartViewModel(
      points,
      _buildLabels(
        startTime,
        durationMinutes,
        labelInterval,
        selectedPeriod,
        minX: minX,
        maxX: maxX,
      ),
      0,
      0,
      startTime,
      durationMinutes,
      labelInterval,
      isTrend: isTrend,
      averageY: averageY,
      minX: minX,
      maxX: maxX,
    );
  }

  /// Specialized parser for sleep data.
  /// Translates sleep phases (Awake, REM, Light, Deep) into discrete Y-axis heights for the step-graph.
  ChartViewModel _prepareSleepChartData(DateTime selectedDate) {
    // Sleep "Day" starts at 18:00 the previous calendar day.
    final DateTime startTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day - 1,
      18,
    );
    final int durationMinutes = 1440;

    final sleepData = service.getSleepDataForDate(selectedDate);
    final List<Point> points = [];

    final sortedData = List<SleepData>.from(sleepData)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (int i = 0; i < sortedData.length; i++) {
      final s = sortedData[i];

      double yValue = 0.0;
      switch (s.stage) {
        case 0x05: // Awake
          yValue = 3.0;
          break;
        case 0x04: // REM
          yValue = 2.5;
          break;
        case 0x02: // Light
          yValue = 2.0;
          break;
        case 0x03: // Deep
          yValue = 1.0;
          break;
        default:
          yValue = 0.0;
      }

      if (yValue > 0) {
        final int startOffset = s.timestamp.difference(startTime).inMinutes;
        for (int m = 0; m < s.durationMinutes; m++) {
          points.add(Point(startOffset + m, yValue));
        }
      }
    }

    double minX = 0.0;
    double maxX = 1440.0;

    if (points.isNotEmpty) {
      final double firstX = points.first.x.toDouble();
      final double lastX = points.last.x.toDouble();
      minX = max(0.0, firstX - 60);
      maxX = min(1440.0, lastX + 60);
    }

    return ChartViewModel(
      points,
      _buildLabels(
        startTime,
        durationMinutes,
        120,
        "D",
        minX: minX,
        maxX: maxX,
      ),
      0.0,
      4.0,
      startTime,
      durationMinutes,
      120,
      minX: minX,
      maxX: maxX,
    );
  }

  /// Extracts the active, volatile trace for the current day directly from the [BleDataManager].
  List<Point> _getLiveDailyPoints(String title) {
    final manager = service.dataManager;
    final now = DateTime.now();
    final int minutesToday = now.hour * 60 + now.minute;
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
            .map((p) => Point(p.x * 15, (p.y * 0.762) / 1000.0))
            .toList();
        break;
      case "Stress":
        raw = List.from(manager.stressHistory);
        break;
      case "HRV":
        raw = List.from(manager.hrvHistory);
        break;
    }
    raw.sort((a, b) => a.x.compareTo(b.x));
    return raw.where((p) => p.x <= minutesToday).toList();
  }

  /// Extracts a specific historical trace from a cached [DailyVitals] block.
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
            .map((p) => Point(p.x * 15, (p.y * 0.762) / 1000.0))
            .toList();
        dist.sort((a, b) => a.x.compareTo(b.x));
        return dist;
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

  /// Resolves the summarized "Total" or "Average" value for an entire day to plot as a single point on a macro-trend chart.
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
        case "HRV":
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
      case "HRV":
        return data.avgHrv.toDouble();
      default:
        return 0.0;
    }
  }

  /// Aggregates 7 sequential daily values into a weekly timeline.
  List<double> _prepareWeeklyData(String title, DateTime startOfWeek) {
    final List<double> weekData = List.generate(7, (index) => 0.0);
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      weekData[i] = _getDailyValue(title, storage.getVitalsForDate(date), date);
    }
    return weekData;
  }

  /// Aggregates daily values to fill an entire month.
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

  /// Calculates the average daily value over each of the 12 months for a yearly trend line.
  List<double> _prepareYearlyData(String title, int year) {
    final List<double> yearlyData = List.generate(12, (index) => 0.0);
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

  /// Determines the optimal dynamic minimum and maximum limits for the Y-axis based on the dataset to provide visually pleasing padding.
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

    // These metrics always start visually from zero for accurate volume representation.
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

  /// Dynamically generates properly aligned visual Text labels (Time, Days, Months) for the X-axis based on the current zoom context.
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

    double step = range / 5;
    if (period == "D") {
      const nice = [15, 30, 60, 120, 180, 240, 300, 360, 480];
      step = nice.firstWhere((n) => n >= step, orElse: () => 480).toDouble();
    } else if (period == "W") {
      step = 1;
    } else if (period == "M") {
      step = 5;
    } else if (period == "Y") {
      step = 1;
    }

    final List<Widget> labelWidgets = [];
    double current = (minX / step).ceil() * step;

    if (current < minX) current += step;

    int safety = 0;
    while (current <= maxX && safety < 100) {
      final double t = (current - minX) / range;

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

      final align = Alignment(t * 2 - 1, 0);

      labelWidgets.add(
        Align(
          alignment: align,
          child: Text(
            text,
            style: AppTextStyles.bodygrey.copyWith(fontSize: 10),
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
