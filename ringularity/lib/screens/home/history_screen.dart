import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/theme/text_styles.dart';
import 'package:ringularity/utils/sleep_score_calculator.dart';

import '../../models/sleep_data.dart';
import '../../services/vitals_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/stat_cards/scrubbable_chart.dart';
import '../../widgets/stat_cards/sleep_stage_summary.dart';
import '../../widgets/stat_cards/stat_summary_header.dart';
import '../../widgets/stat_cards/time_period_selector.dart';

class HistoryScreen extends StatefulWidget {
  final String title;
  final String currentValue;
  final String unit;

  const HistoryScreen({
    super.key,
    required this.title,
    required this.currentValue,
    this.unit = "",
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedPeriod = "D";
  DateTime _selectedDate = DateTime.now();

  String? _scrubbedValue;
  String? _scrubbedTime;

  @override
  void initState() {
    super.initState();
    final service = Provider.of<BleService>(context, listen: false);
    _selectedDate = service.selectedDate;
  }

  @override
  Widget build(BuildContext context) {
    final storageService = Provider.of<VitalsStorageService>(context);

    return Consumer<BleService>(
      builder: (context, service, child) {
        const cumulativeTypes = ["Steps", "Sleep", "Activity", "Distance"];

        bool showTotal = false;
        if (_selectedPeriod == "D" && cumulativeTypes.contains(widget.title)) {
          showTotal = true;
        }

        String baseValue = widget.currentValue;
        if (_selectedPeriod == "D") {
          if (widget.title == "Steps") baseValue = service.steps.toString();
          if (widget.title == "HR") baseValue = service.heartRate.toString();
          if (widget.title == "Stress") baseValue = service.stress.toString();
          if (widget.title == "Oxygen") baseValue = "${service.spo2}";
          if (widget.title == "Distance")
            baseValue = (service.distance / 1000).toStringAsFixed(2);
          if (widget.title == "Sleep")
            baseValue = service.totalSleepTimeFormatted;
        }

        final String displayValue = _scrubbedValue ?? baseValue;

        final chartViewModel = _prepareChartData(service, storageService);
        final List<double> chartData = chartViewModel.dataPoints;
        final (dynamicMinY, dynamicMaxY) = _calculateYRange(chartData);
        final DateTime startTime = chartViewModel.startTime;
        final int dataDurationMinutes = chartViewModel.durationMinutes;

        final double limitX = 1.0;

        // --- FIXED: Korrekter Aufruf der getSleepDataForDate ---
        SleepMetrics? sleepMetrics;
        if (widget.title == "Sleep" && _selectedPeriod == "D") {
          final sleepData = service.getSleepDataForDate(_selectedDate);
          if (sleepData.isNotEmpty) {
            sleepMetrics = SleepScoreCalculator.calculate(sleepData);
          }
        }

        double? averageY;
        if (chartViewModel.isTrend && chartData.isNotEmpty) {
          final validData = chartData.where((d) => !d.isNaN && d > 0);
          if (validData.isNotEmpty) {
            averageY = validData.reduce((a, b) => a + b) / validData.length;
          }
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: ScreenHeader(title: widget.title),
                ),

                TimePeriodSelector(
                  selectedPeriod: _selectedPeriod,
                  onPeriodChanged: (newPeriod) {
                    setState(() {
                      _selectedPeriod = newPeriod;
                      _scrubbedValue = null;
                      _scrubbedTime = null;
                    });
                  },
                ),

                const SizedBox(height: 20),

                StatSummaryHeader(
                  isTotal: showTotal,
                  value: _scrubbedValue ?? displayValue,
                  unit: widget.unit,
                  valueColor: _scrubbedValue != null
                      ? Colors.white
                      : AppColors.mainColor,
                  onCalendarTap: () => _showCalendarPicker(context, service),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (sleepMetrics != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 10,
                            ),
                            child: Column(
                              children: [
                                _buildMetricRow(
                                  "Sleep Score",
                                  "${sleepMetrics.score}",
                                  Icons.speed,
                                ),
                                const SizedBox(height: 12),
                                _buildMetricRow(
                                  "Efficiency",
                                  "${sleepMetrics.efficiency}%",
                                  Icons.rocket_launch,
                                ),
                                const SizedBox(height: 12),
                                _buildMetricRow(
                                  "Quality",
                                  sleepMetrics.rating,
                                  Icons.shield_moon,
                                ),
                                const SizedBox(height: 20),
                                const Divider(color: Colors.white10),
                              ],
                            ),
                          ),

                        SizedBox(
                          height: 350,
                          child: ScrubbableChart(
                            minY: dynamicMinY,
                            maxY: dynamicMaxY,
                            dataPoints: chartData,
                            chartLabels: _buildChartLabels(
                              startTime,
                              dataDurationMinutes,
                              chartViewModel.labelIntervalMinutes,
                            ),
                            limitX: limitX,
                            averageY: averageY,
                            highlightScrubbedBar: true,
                            isCurved: widget.title != "Steps",
                            showDots: false,
                            useBars:
                                widget.title == "Sleep" ||
                                _selectedPeriod == "Y" ||
                                _selectedPeriod == "M",
                            barColorBuilder: (val) {
                              if (widget.title == "Sleep") {
                                if (val >= 2.8)
                                  return const Color(0xFFFF9B9B); // Awake
                                if (val >= 2.4)
                                  return const Color(0xFF9D4BF5); // REM
                                if (val >= 1.8)
                                  return const Color(0xFF4B98F5); // Light
                                return const Color(0xFF1E4578); // Deep
                              }
                              return AppColors.mainColor.withOpacity(0.8);
                            },
                            onValueSelected: (val, progress) {
                              setState(() {
                                if (val == null || progress == null) {
                                  _scrubbedValue = null;
                                  _scrubbedTime = null;
                                } else {
                                  if (widget.title == "Sleep") {
                                    if (chartViewModel.isTrend) {
                                      final int hours = val.floor();
                                      final int minutes = ((val - hours) * 60)
                                          .round();
                                      if (_selectedPeriod == "Y") {
                                        _scrubbedValue =
                                            "Avg ${hours}h ${minutes}m";
                                      } else {
                                        _scrubbedValue =
                                            "${hours}h ${minutes}m";
                                      }
                                    } else {
                                      if (val >= 2.8)
                                        _scrubbedValue = "Awake";
                                      else if (val >= 2.4)
                                        _scrubbedValue = "REM";
                                      else if (val >= 1.8)
                                        _scrubbedValue = "Light";
                                      else if (val >= 0.5)
                                        _scrubbedValue = "Deep";
                                      else
                                        _scrubbedValue = "-";
                                    }
                                  } else {
                                    _scrubbedValue = _formatScrubbedValue(val);
                                  }

                                  if (_selectedPeriod == "D") {
                                    final int scrubMinutes =
                                        (progress * dataDurationMinutes)
                                            .round();
                                    final DateTime timeAtPoint = startTime.add(
                                      Duration(minutes: scrubMinutes),
                                    );
                                    _scrubbedTime = DateFormat(
                                      'HH:mm',
                                    ).format(timeAtPoint);
                                  } else if (_selectedPeriod == "W") {
                                    final int dayOffset = (progress * 6)
                                        .round();
                                    final DateTime dateAtPoint = startTime.add(
                                      Duration(days: dayOffset),
                                    );
                                    _scrubbedTime = DateFormat(
                                      'EEEE',
                                    ).format(dateAtPoint);
                                  } else if (_selectedPeriod == "M") {
                                    final int dayOffset =
                                        (progress * (dataDurationMinutes - 1))
                                            .round();
                                    final DateTime dateAtPoint = startTime.add(
                                      Duration(days: dayOffset),
                                    );
                                    _scrubbedTime = DateFormat(
                                      'MMM d',
                                    ).format(dateAtPoint);
                                  } else if (_selectedPeriod == "Y") {
                                    final int monthOffset = (progress * 11)
                                        .round();
                                    final DateTime dateAtPoint = DateTime(
                                      startTime.year,
                                      monthOffset + 1,
                                    );
                                    _scrubbedTime = DateFormat(
                                      'MMMM',
                                    ).format(dateAtPoint);
                                  }
                                }
                              });
                            },
                          ),
                        ),

                        if (widget.title == "Sleep" &&
                            !chartViewModel.isTrend) ...[
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: SleepStageSummary(
                              sleepHistory: service.getSleepDataForDate(
                                _selectedDate,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),

                Text(
                  _getDateLabel(),
                  style: AppTextStyles.subtitle.copyWith(
                    color: _scrubbedTime != null ? Colors.white : Colors.grey,
                    fontWeight: _scrubbedTime != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatScrubbedValue(double val) {
    if (widget.title == "HR" ||
        widget.title == "Stress" ||
        widget.title == "Steps") {
      return val.round().toString();
    } else if (widget.title == "Oxygen") {
      return val.round().toString();
    } else if (widget.title == "Distance") {
      return _selectedPeriod == "D"
          ? (val / 1000).toStringAsFixed(2)
          : val.toStringAsFixed(2);
    } else {
      return val.toStringAsFixed(1);
    }
  }

  void _showCalendarPicker(BuildContext context, BleService service) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.mainColor,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.background,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      service.setSelectedDate(picked);
      service.triggerSmartSync(force: true);
    }
  }

  (double minY, double maxY) _calculateYRange(List<double> data) {
    final valid = data.where((d) => !d.isNaN && d > 0.0).toList();

    if (valid.isEmpty) return (0.0, 100.0);

    final double minVal = valid.reduce((a, b) => a < b ? a : b);
    final double maxVal = valid.reduce((a, b) => a > b ? a : b);

    if (minVal == maxVal) {
      double min = minVal == 0 ? 0.0 : minVal - 10;
      if (min < 0) min = 0.0;
      return (min, maxVal + 10);
    }

    final double padding = (maxVal - minVal) * 0.1;
    double calculatedMin = minVal - padding;
    final double calculatedMax = maxVal + padding;

    const zeroBottomTypes = ["Steps", "Sleep", "Distance", "Oxygen", "Stress"];

    if (zeroBottomTypes.contains(widget.title)) {
      calculatedMin = 0.0;
    }

    if (calculatedMin < 0) {
      calculatedMin = 0.0;
    }

    return (calculatedMin, calculatedMax);
  }

  _ChartViewModel _prepareChartData(
    BleService service,
    VitalsStorageService storage,
  ) {
    if (widget.title == "Sleep") {
      if (_selectedPeriod == "M" || _selectedPeriod == "W") {
        DateTime start = _selectedDate;
        if (_selectedPeriod == "M") {
          start = DateTime(_selectedDate.year, _selectedDate.month, 1);
        } else {
          start = _selectedDate.subtract(
            Duration(days: _selectedDate.weekday - 1),
          );
        }
        final DateTime end = _selectedPeriod == "W"
            ? start.add(const Duration(days: 6))
            : DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

        final List<double> dailyTotals = [];
        int totalDays = end.difference(start).inDays + 1;
        if (totalDays < 1) totalDays = 1;

        for (int i = 0; i < totalDays; i++) {
          final DateTime day = start.add(Duration(days: i));
          final cached = storage.getVitalsForDate(day);
          if (cached != null) {
            dailyTotals.add(cached.totalSleepMinutes / 60.0);
          } else {
            final List<SleepData> daysSleep = service.getSleepDataForDate(day);
            final int minutes = daysSleep.fold(
              0,
              (sum, item) =>
                  (item.stage != 5) ? sum + item.durationMinutes : sum,
            );
            dailyTotals.add(minutes / 60.0);
          }
        }
        return _ChartViewModel(
          dailyTotals,
          start,
          totalDays * 24 * 60,
          1,
          isTrend: true,
        );
      } else if (_selectedPeriod == "Y") {
        final int year = _selectedDate.year;
        final List<double> monthlyAverages = [];

        for (int m = 1; m <= 12; m++) {
          final List<SleepData> monthSleep = service.sleepHistory
              .where((s) => s.timestamp.year == year && s.timestamp.month == m)
              .toList();
          if (monthSleep.isEmpty) {
            monthlyAverages.add(0.0);
          } else {
            final Set<int> days = monthSleep
                .map((e) => e.timestamp.day)
                .toSet();
            double totalHours = 0;
            for (int d in days) {
              final int dayMinutes = monthSleep
                  .where((e) => e.timestamp.day == d)
                  .fold(
                    0,
                    (sum, i) => (i.stage != 5) ? sum + i.durationMinutes : sum,
                  );
              totalHours += (dayMinutes / 60.0);
            }
            monthlyAverages.add(totalHours / days.length);
          }
        }
        return _ChartViewModel(
          monthlyAverages,
          DateTime(year, 1, 1),
          12 * 30 * 24 * 60,
          1,
          isTrend: true,
        );
      } else {
        final vm = _prepareDailyData(service);
        return _ChartViewModel(
          vm.dataPoints,
          vm.startTime,
          vm.durationMinutes,
          vm.labelIntervalMinutes,
          isTrend: false,
        );
      }
    }

    if (_selectedPeriod == "D") {
      return _prepareDailyData(service);
    } else if (_selectedPeriod == "W") {
      return _prepareWeeklyData(service, storage);
    } else if (_selectedPeriod == "M") {
      return _prepareMonthlyData(service, storage);
    } else if (_selectedPeriod == "Y") {
      return _prepareYearlyData(service);
    }

    return _ChartViewModel([], _selectedDate, 24 * 60, 360);
  }

  _ChartViewModel _prepareDailyData(BleService service) {
    if (widget.title == "Sleep") {
      final List<SleepData> relevantSleep = service.getSleepDataForDate(
        _selectedDate,
      );

      if (relevantSleep.isEmpty) {
        return _ChartViewModel(
          List.filled(96, 0.0),
          _selectedDate,
          1440,
          360,
          isTrend: false,
        );
      }

      final DateTime minTime = relevantSleep.first.timestamp.subtract(
        const Duration(minutes: 30),
      );
      final DateTime maxTime = relevantSleep.last.timestamp.add(
        Duration(minutes: relevantSleep.last.durationMinutes + 30),
      );

      final DateTime snappedStart = DateTime(
        minTime.year,
        minTime.month,
        minTime.day,
        minTime.hour,
      );
      int rawDuration = maxTime.difference(snappedStart).inMinutes;
      if (rawDuration < 60) rawDuration = 60;
      final int interval = _calculateLabelInterval(rawDuration);
      final int paddedDuration = (rawDuration % interval == 0)
          ? rawDuration
          : rawDuration + (interval - (rawDuration % interval));

      final int newBins = (paddedDuration / 15).ceil();
      final List<double> data = List.filled(newBins, 0.0);

      for (var s in relevantSleep) {
        final int offset = s.timestamp.difference(snappedStart).inMinutes;
        final int startBin = offset ~/ 15;
        final int durationBins = (s.durationMinutes / 15).ceil();
        double val = 0;
        if (s.stage == 0x05)
          val = 3; // Awake
        else if (s.stage == 0x04)
          val = 2.5; // REM
        else if (s.stage == 0x02)
          val = 2; // Light
        else if (s.stage == 0x03)
          val = 1; // Deep

        for (int i = 0; i < durationBins; i++) {
          if (startBin + i >= 0 && startBin + i < newBins)
            data[startBin + i] = val;
        }
      }
      return _ChartViewModel(
        data,
        snappedStart,
        paddedDuration,
        interval,
        isTrend: false,
      );
    } else {
      List<double> fullDayData = [];
      if (widget.title == "HR") {
        fullDayData = _binTimePoints(service.hrHistory, 96, interpolate: true);
      } else if (widget.title == "Oxygen") {
        fullDayData = _binTimePoints(
          service.spo2History,
          96,
          interpolate: true,
        );
      } else if (widget.title == "Stress") {
        fullDayData = _binTimePoints(
          service.stressHistory,
          96,
          interpolate: true,
        );
      } else if (widget.title == "Steps" || widget.title == "Distance") {
        fullDayData = List.filled(96, 0.0);
        double currentTotal = 0;
        for (var p in service.stepsHistory) {
          final int idx = p.x.toInt();
          if (idx >= 0 && idx < 96) fullDayData[idx] = p.y.toDouble();
        }
        for (int i = 0; i < 96; i++) {
          currentTotal += fullDayData[i];
          fullDayData[i] = currentTotal;
        }
        if (_isToday(_selectedDate)) {
          final now = DateTime.now();
          final int currentBin = (now.hour * 60 + now.minute) ~/ 15;
          for (int i = currentBin + 1; i < 96; i++) fullDayData[i] = double.nan;
        }
      }

      return _ChartViewModel(
        fullDayData,
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        1440,
        360,
      );
    }
  }

  _ChartViewModel _prepareWeeklyData(
    BleService service,
    VitalsStorageService storage,
  ) {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final List<double> weekData = List.generate(7, (index) => 0.0);

    for (int i = 0; i < 7; i++) {
      final targetDate = startOfWeek.add(Duration(days: i));
      final dayData = storage.getVitalsForDate(targetDate);

      if (dayData != null) {
        if (widget.title == "Steps")
          weekData[i] = dayData.steps.toDouble();
        else if (widget.title == "HR")
          weekData[i] = dayData.avgHr.toDouble();
        else if (widget.title == "Sleep")
          weekData[i] = dayData.totalSleepMinutes.toDouble();
        else if (widget.title == "Stress")
          weekData[i] = dayData.avgStress.toDouble();
        else if (widget.title == "Oxygen")
          weekData[i] = dayData.avgSpo2.toDouble();
        else if (widget.title == "Distance")
          weekData[i] = (dayData.distance / 1000.0);
      } else {
        weekData[i] = 0.0;
      }
    }
    return _ChartViewModel(weekData, startOfWeek, 7, 1);
  }

  _ChartViewModel _prepareMonthlyData(
    BleService service,
    VitalsStorageService storage,
  ) {
    final int daysInMonth = _getDaysInMonth(_selectedDate);
    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final List<double> monthData = List.filled(daysInMonth, 0.0);

    for (int i = 0; i < daysInMonth; i++) {
      final targetDate = startOfMonth.add(Duration(days: i));
      final cached = storage.getVitalsForDate(targetDate);

      if (cached != null) {
        if (widget.title == "Steps")
          monthData[i] = cached.steps.toDouble();
        else if (widget.title == "HR")
          monthData[i] = cached.avgHr.toDouble();
        else if (widget.title == "Sleep")
          monthData[i] = cached.totalSleepMinutes.toDouble();
        else if (widget.title == "Stress")
          monthData[i] = cached.avgStress.toDouble();
        else if (widget.title == "Oxygen")
          monthData[i] = cached.avgSpo2.toDouble();
        else if (widget.title == "Distance")
          monthData[i] = (cached.distance / 1000.0);
      } else {
        monthData[i] = 0.0;
      }
    }
    return _ChartViewModel(monthData, startOfMonth, daysInMonth, 5);
  }

  _ChartViewModel _prepareYearlyData(BleService service) {
    final startOfYear = DateTime(_selectedDate.year, 1, 1);
    final List<double> yearData = List.generate(12, (index) {
      if (index == DateTime.now().month - 1) return service.steps.toDouble();
      return 4000.0 + (sin(index) * 2000.0).abs();
    });
    return _ChartViewModel(yearData, startOfYear, 12, 1);
  }

  List<double> _binTimePoints(
    List<Point> points,
    int bins, {
    bool interpolate = false,
  }) {
    final List<double> sumData = List.filled(bins, 0.0);
    final List<int> counts = List.filled(bins, 0);

    for (var p in points) {
      final int minute = p.x.toInt();
      final int idx = minute ~/ 15;
      if (idx >= 0 && idx < bins) {
        sumData[idx] += p.y;
        counts[idx]++;
      }
    }

    final List<double> result = List.generate(bins, (i) {
      if (counts[i] > 0)
        return sumData[i] / counts[i];
      else
        return double.nan;
    });

    if (interpolate) {
      final int firstValid = result.indexWhere((d) => !d.isNaN);
      if (firstValid == -1) return result;

      final int lastValid = result.lastIndexWhere((d) => !d.isNaN);
      for (int i = firstValid + 1; i < lastValid; i++) {
        if (result[i].isNaN) {
          int nextValid = -1;
          for (int j = i + 1; j <= lastValid; j++) {
            if (!result[j].isNaN) {
              nextValid = j;
              break;
            }
          }
          if (nextValid != -1) {
            final double startVal = result[i - 1];
            final double endVal = result[nextValid];
            final int gapSize = nextValid - (i - 1);
            for (int k = 1; k < gapSize; k++) {
              final double fraction = k / gapSize;
              result[i - 1 + k] = startVal + (endVal - startVal) * fraction;
            }
            i = nextValid - 1;
          }
        }
      }
    }
    return result;
  }

  int _calculateLabelInterval(int totalMinutes) {
    if (totalMinutes <= 300) return 60;
    if (totalMinutes <= 600) return 120;
    if (totalMinutes <= 900) return 180;
    if (totalMinutes <= 1200) return 240;
    return 360;
  }

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  Widget _buildChartLabels(
    DateTime startTime,
    int durationMinutes,
    int intervalMinutes,
  ) {
    List<String> labels = [];

    switch (_selectedPeriod) {
      case "D":
        for (int i = 0; i * intervalMinutes <= durationMinutes; i++) {
          final int offset = i * intervalMinutes;
          if (offset > durationMinutes) break;
          final DateTime t = startTime.add(Duration(minutes: offset));
          labels.add(
            "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}",
          );
        }
        break;
      case "W":
        labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
        break;
      case "M":
        final int days = _getDaysInMonth(_selectedDate);
        labels = ["1", "5", "10", "15", "20", "25", "$days"];
        break;
      case "Y":
        labels = [
          "Jan",
          "Feb",
          "Mar",
          "Apr",
          "May",
          "Jun",
          "Jul",
          "Aug",
          "Sep",
          "Oct",
          "Nov",
          "Dec",
        ];
        break;
    }

    return Row(
      mainAxisAlignment: labels.length > 4
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.spaceAround,
      children: labels
          .map(
            (text) => Text(
              text,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          )
          .toList(),
    );
  }

  String _getDateLabel() {
    if (_scrubbedTime != null) {
      return _scrubbedTime!;
    }

    switch (_selectedPeriod) {
      case "D":
        if (_isToday(_selectedDate)) return "Today";
        return DateFormat('MMMM d, y').format(_selectedDate);
      case "W":
        final startOfWeek = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return "${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}";
      case "M":
        return DateFormat('MMMM y').format(_selectedDate);
      case "Y":
        return DateFormat('y').format(_selectedDate);
      default:
        return "";
    }
  }
}

class _ChartViewModel {
  final List<double> dataPoints;
  final DateTime startTime;
  final int durationMinutes;
  final int labelIntervalMinutes;
  final bool isTrend;

  _ChartViewModel(
    this.dataPoints,
    this.startTime,
    this.durationMinutes,
    this.labelIntervalMinutes, {
    this.isTrend = false,
  });
}
