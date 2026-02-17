import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/theme/text_styles.dart';

import '../../models/sleep_data.dart';
import '../../services/vitals_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/stat_cards/scrubbable_chart.dart';
import '../../widgets/stat_cards/stat_summary_header.dart';
import '../../widgets/stat_cards/time_period_selector.dart';

//TODO: DONE add real data from the ring
//TODO: maybe add possibility to start manual measurement (HR, HRV, Spo2, Stress)
//TODO: DONE sleep might need a different view (sleep stages instead of just time)
//TODO: DONE steps might need different view since its cumulative (steps at this time not steps in this hour)

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

  // State for scrubbed value
  String? _scrubbedValue;
  String? _scrubbedTime;

  @override
  void initState() {
    super.initState();
    // Sync local date with service date on startup
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

        // Determine Base Display Value (if not scrubbing)
        String baseValue = widget.currentValue;
        // If "D", we might want the live value from service for consistency?
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

        // Use scrubbed value if active, otherwise base value
        final String displayValue = _scrubbedValue ?? baseValue;

        // --- Data Preparation for Dynamic Scaling ---
        final chartViewModel = _prepareChartData(service, storageService);
        final List<double> chartData = chartViewModel.dataPoints;
        final (dynamicMinY, dynamicMaxY) = _calculateYRange(chartData);
        final DateTime startTime = chartViewModel.startTime;
        final int dataDurationMinutes = chartViewModel.durationMinutes;

        // Calculate Limit X
        final double limitX = 1.0;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // --- 1. HEADER ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: ScreenHeader(title: widget.title),
                ),

                // --- 2. TABS (Ausgelagert) ---
                TimePeriodSelector(
                  selectedPeriod: _selectedPeriod,
                  onPeriodChanged: (newPeriod) {
                    setState(() {
                      _selectedPeriod = newPeriod;
                      _scrubbedValue = null; // Reset scrub state
                    });
                  },
                ),

                const SizedBox(height: 20),

                // --- 3. WERT & KALENDER (Ausgelagert) ---
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

                // --- 4. CHART BEREICH ---
                Expanded(
                  child: ScrubbableChart(
                    // Hier übergeben wir das dynamisch berechnete Maximum
                    minY: dynamicMinY,
                    maxY: dynamicMaxY,

                    // Die unterschiedlichen Daten
                    dataPoints: chartData,

                    chartLabels: _buildChartLabels(
                      startTime,
                      dataDurationMinutes,
                      chartViewModel.labelIntervalMinutes,
                    ),
                    limitX: limitX,

                    // Customize appearance based on type
                    isCurved: widget.title != "Steps",

                    //uncomment if you want dots on steps
                    //showDots: widget.title == "Steps",
                    showDots: false,
                    useBars:
                        widget.title == "Sleep" ||
                        _selectedPeriod == "Y" ||
                        _selectedPeriod == "M",

                    barColorBuilder: (val) {
                      if (widget.title == "Sleep") {
                        if (val >= 2.8) return const Color(0xFFFF9B9B); // Awake
                        if (val >= 2.4) return const Color(0xFF9D4BF5); // REM
                        if (val >= 1.8) return const Color(0xFF4B98F5); // Light
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
                          _scrubbedValue = _formatScrubbedValue(val);

                          if (_selectedPeriod == "D") {
                            final int scrubMinutes =
                                (progress * dataDurationMinutes).round();
                            final DateTime timeAtPoint = startTime.add(
                              Duration(minutes: scrubMinutes),
                            );
                            _scrubbedTime = DateFormat(
                              'HH:mm',
                            ).format(timeAtPoint);
                          } else if (_selectedPeriod == "W") {
                            final int dayOffset = (progress * 6).round();
                            final DateTime dateAtPoint = startTime.add(
                              Duration(days: dayOffset),
                            );
                            _scrubbedTime = DateFormat(
                              'EEEE',
                            ).format(dateAtPoint);
                          } else if (_selectedPeriod == "M") {
                            final int dayOffset =
                                (progress * (dataDurationMinutes - 1)).round();
                            final DateTime dateAtPoint = startTime.add(
                              Duration(days: dayOffset),
                            );
                            _scrubbedTime = DateFormat(
                              'MMM d',
                            ).format(dateAtPoint);
                          } else if (_selectedPeriod == "Y") {
                            final int monthOffset = (progress * 11).round();
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

  // ----------------------------------------------------------------------
  // HELPER METHODEN
  // ----------------------------------------------------------------------

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
    } else if (widget.title == "Sleep") {
      if (_selectedPeriod == "D") {
        if (val >= 2.8) return "Awake";
        if (val >= 2.4) return "REM";
        if (val >= 1.8) return "Light";
        if (val >= 0.5) return "Deep";
        return "-";
      } else {
        return "${(val / 60).toStringAsFixed(1)}h";
      }
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
      // Notify Service to load data for this date
      service.setSelectedDate(picked);
      service.triggerSmartSync(force: true); // Try to sync/fetch
    }
  }

  (double minY, double maxY) _calculateYRange(List<double> data) {
    final valid = data.where((d) => !d.isNaN).toList();

    if (valid.isEmpty) return (0.0, 100.0);

    final double minVal = valid.reduce((a, b) => a < b ? a : b);
    final double maxVal = valid.reduce((a, b) => a > b ? a : b);

    if (minVal == maxVal) {
      return (minVal == 0 ? 0.0 : minVal - 10, maxVal + 10);
    }

    final double padding = (maxVal - minVal) * 0.1;
    double calculatedMin = minVal - padding;
    final double calculatedMax = maxVal + padding;

    const zeroBottomTypes = ["Steps", "Sleep", "Distance", "Oxygen", "Stress"];

    if (zeroBottomTypes.contains(widget.title)) {
      calculatedMin = 0.0;
    }

    return (calculatedMin, calculatedMax);
  }

  _ChartViewModel _prepareChartData(
    BleService service,
    VitalsStorageService storage,
  ) {
    if (_selectedPeriod == "D") {
      return _prepareDailyData(service);
    } else if (_selectedPeriod == "W") {
      return _prepareWeeklyData(service, storage);
    } else if (_selectedPeriod == "M") {
      return _prepareMonthlyData(service, storage);
    } else if (_selectedPeriod == "Y") {
      return _prepareYearlyData(service);
    }

    // Fallback
    return _ChartViewModel([], _selectedDate, 24 * 60, 360);
  }

  _ChartViewModel _prepareDailyData(BleService service) {
    if (widget.title == "Sleep") {
      final List<SleepData> relevantSleep = service.sleepHistory;
      if (relevantSleep.isEmpty) {
        return _ChartViewModel(List.filled(96, 0.0), _selectedDate, 1440, 360);
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
      return _ChartViewModel(data, snappedStart, paddedDuration, interval);
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
        if (widget.title == "Steps") {
          weekData[i] = dayData.steps.toDouble();
        } else if (widget.title == "HR") {
          weekData[i] = dayData.avgHr.toDouble();
        } else if (widget.title == "Sleep") {
          weekData[i] = dayData.totalSleepMinutes.toDouble();
        } else if (widget.title == "Stress") {
          weekData[i] = dayData.avgStress.toDouble();
        } else if (widget.title == "Oxygen") {
          weekData[i] = dayData.avgSpo2.toDouble();
        } else if (widget.title == "Distance") {
          weekData[i] = (dayData.distance / 1000.0);
        }
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
        if (widget.title == "Steps") {
          monthData[i] = cached.steps.toDouble();
        } else if (widget.title == "HR") {
          monthData[i] = cached.avgHr.toDouble();
        } else if (widget.title == "Sleep") {
          monthData[i] = cached.totalSleepMinutes.toDouble();
        } else if (widget.title == "Stress") {
          monthData[i] = cached.avgStress.toDouble();
        } else if (widget.title == "Oxygen") {
          monthData[i] = cached.avgSpo2.toDouble();
        } else if (widget.title == "Distance") {
          monthData[i] = (cached.distance / 1000.0);
        }
      } else {
        monthData[i] = 0.0;
      }
    }

    return _ChartViewModel(monthData, startOfMonth, daysInMonth, 5);
  }

  //Mock Werte für UI Test
  _ChartViewModel _prepareYearlyData(BleService service) {
    final startOfYear = DateTime(_selectedDate.year, 1, 1);

    final List<double> yearData = List.generate(12, (index) {
      if (index == DateTime.now().month - 1) {
        return service.steps.toDouble();
      }
      return 4000.0 + (sin(index) * 2000.0).abs();
    });

    return _ChartViewModel(yearData, startOfYear, 12, 1);
  }
  /*_ChartViewModel _prepareYearlyData(BleService service) {
    final startOfYear = DateTime(_selectedDate.year, 1, 1);

    final List<double> yearData = List.generate(12, (index) => 0.0);

    // TODO: Backend-Anbindung
    // Sobald das Backend fertig ist:
    final backendData = await service.apiService.getYearlySummary(_selectedDate.year);
    for(var data in backendData) { yearData[data.month - 1] = data.value; }

    return _ChartViewModel(yearData, startOfYear, 12, 1);
  }*/

  List<double> _binTimePoints(
    List<Point> points,
    int bins, {
    bool interpolate = false,
  }) {
    // Initialize with 0 for summing, but track counts to decide NaN
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

    // Result list
    final List<double> result = List.generate(bins, (i) {
      if (counts[i] > 0) {
        return sumData[i] / counts[i];
      } else {
        return double.nan; // Return NaN for empty bins
      }
    });

    if (interpolate) {
      final int firstValid = result.indexWhere((d) => !d.isNaN);
      if (firstValid == -1) return result; // No data at all

      final int lastValid = result.lastIndexWhere((d) => !d.isNaN);

      // Fill gaps between firstValid and lastValid
      for (int i = firstValid + 1; i < lastValid; i++) {
        if (result[i].isNaN) {
          // Found a gap starting at i
          // Find next valid point
          int nextValid = -1;
          for (int j = i + 1; j <= lastValid; j++) {
            if (!result[j].isNaN) {
              nextValid = j;
              break;
            }
          }

          if (nextValid != -1) {
            final double startVal =
                result[i - 1]; // Guaranteed valid by loop logic
            final double endVal = result[nextValid];
            final int gapSize = nextValid - (i - 1);

            // Fill the gap
            for (int k = 1; k < gapSize; k++) {
              final double fraction = k / gapSize;
              result[i - 1 + k] = startVal + (endVal - startVal) * fraction;
            }
            // Skip the iterator to the end of this gap
            i = nextValid - 1;
          }
        }
      }
    }

    return result;
  }

  /// Calculates a nice interval for labels (in minutes)
  /// e.g. 60 (1h), 120 (2h), 180 (3h), 240 (4h), 360 (6h)
  int _calculateLabelInterval(int totalMinutes) {
    if (totalMinutes <= 300) return 60; // Up to 5h -> every 1h
    if (totalMinutes <= 600) return 120; // Up to 10h -> every 2h
    if (totalMinutes <= 900) return 180; // Up to 15h -> every 3h
    if (totalMinutes <= 1200) return 240; // Up to 20h -> every 4h
    return 360; // Else every 6h
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
        // Generate flexible labels based on Start Time + Interval
        // We iterate until we exceed durationMinutes.
        // We want at least start and end, and steps in between.
        for (int i = 0; i * intervalMinutes <= durationMinutes; i++) {
          final int offset = i * intervalMinutes;
          // Avoid drawing a label at the very end edge if it might clip?
          // But usually we want the last one too if it fits exactly.
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

  _ChartViewModel(
    this.dataPoints,
    this.startTime,
    this.durationMinutes,
    this.labelIntervalMinutes,
  );
}
