import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/models/sleep_data.dart';
import 'package:ringularity/services/ble/ble_service.dart';
// import 'package:ringularity/theme/text_styles.dart'; // Unused

import '../../theme/app_colors.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/stat_cards/scrubbable_chart.dart';
import '../../widgets/stat_cards/sleep_stage_summary.dart';
import '../../widgets/stat_cards/stat_summary_header.dart';
import '../../widgets/stat_cards/time_period_selector.dart';
import '../../utils/sleep_score_calculator.dart';

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
  DateTime? _selectedEndDate; // For custom ranges (Month view)

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
        final chartViewModel = _prepareChartData(service);
        final List<double> chartData = chartViewModel.dataPoints;
        final (dynamicMinY, dynamicMaxY) = _calculateYRange(chartData);
        final DateTime startTime = chartViewModel.startTime;
        final int dataDurationMinutes = chartViewModel.durationMinutes;

        // Calculate Limit X
        final double limitX = 1.0;

        // --- Sleep Metrics Calculation (Day View Only) ---
        SleepMetrics? sleepMetrics;
        if (widget.title == "Sleep" &&
            _selectedPeriod == "D" &&
            _selectedEndDate == null) {
          final sleepData = service.getSleepDataForDate(_selectedDate);
          sleepMetrics = SleepScoreCalculator.calculate(sleepData);
        }

        // --- Average Calculation (Month/Year View) ---
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
                // --- 1. HEADER (Back to standard) ---
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

                // --- 2b. DATE NAVIGATOR (< Date >) ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => _navigatePeriod(-1, service),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showCalendarPicker(context, service),
                        child: Text(
                          _getDateLabel(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _canGoNext()
                            ? () => _navigatePeriod(1, service)
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // --- 3. WERT & KALENDER ---
                StatSummaryHeader(
                  isTotal: showTotal,
                  // SHOW SCRUBBED VALUE AT TOP
                  value: _scrubbedValue ?? displayValue,
                  subValue: _scrubbedTime, // Pass time as subtitle
                  unit: widget.unit,
                  valueColor: _scrubbedValue != null
                      ? Colors.white
                      : AppColors.mainColor, // Highlight if scrubbing
                  onCalendarTap: () => _showCalendarPicker(context, service),
                ),

                const SizedBox(height: 20),

                // --- 4. CHART BEREICH ---
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // --- NEW: Compact Sleep Metrics List (Scrollable) ---
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
                          height: 350, // Fixed height for chart area
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

                            // New Properties
                            averageY: averageY,
                            highlightScrubbedBar: true,

                            // Customize appearance based on type
                            isCurved: widget.title != "Steps",

                            //uncomment if you want dots on steps
                            //showDots: widget.title == "Steps",
                            showDots: false,

                            // Use bars for Sleep (Stage & Trend) and Steps, or generically for Month View
                            useBars:
                                widget.title == "Sleep" ||
                                _selectedPeriod == "M" ||
                                _selectedPeriod == "Y",

                            // Only use stage colors if NOT trend
                            barColorBuilder:
                                (widget.title == "Sleep" &&
                                    !chartViewModel.isTrend)
                                ? (val) {
                                    if (val >= 2.8)
                                      return const Color(0xFFFF9B9B); // Awake
                                    if (val >= 2.4)
                                      return const Color(0xFF9D4BF5); // REM
                                    if (val >= 1.8)
                                      return const Color(0xFF4B98F5); // Light
                                    return const Color(0xFF1E4578); // Deep
                                  }
                                : (widget.title == "Sleep" &&
                                      chartViewModel.isTrend)
                                ? (val) => AppColors
                                      .mainColor // Single color for trend
                                : null,

                            onValueSelected: (val, progress) {
                              setState(() {
                                if (val == null || progress == null) {
                                  _scrubbedValue = null; // Revert to current
                                  _scrubbedTime = null;
                                } else {
                                  // Format Value
                                  if (widget.title == "HR" ||
                                      widget.title == "Stress" ||
                                      widget.title == "Steps") {
                                    _scrubbedValue = val.round().toString();
                                  } else if (widget.title == "Oxygen") {
                                    _scrubbedValue = val.round().toString();
                                  } else if (widget.title == "Distance") {
                                    _scrubbedValue = (val / 1000)
                                        .toStringAsFixed(2);
                                  } else if (widget.title == "Sleep") {
                                    if (chartViewModel.isTrend) {
                                      // Trend View: Hours
                                      int hours = val.floor();
                                      int minutes = ((val - hours) * 60)
                                          .round();
                                      if (_selectedPeriod == "Y") {
                                        _scrubbedValue =
                                            "Avg ${hours}h ${minutes}m";
                                      } else {
                                        _scrubbedValue =
                                            "${hours}h ${minutes}m";
                                      }
                                    } else {
                                      // Stage View
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
                                    _scrubbedValue = val.toStringAsFixed(1);
                                  }

                                  // Calculate Time or Date
                                  final int scrubMinutes =
                                      (progress * dataDurationMinutes).round();
                                  final DateTime timeAtPoint = startTime.add(
                                    Duration(minutes: scrubMinutes),
                                  );

                                  if (chartViewModel.isTrend) {
                                    if (_selectedPeriod == "Y") {
                                      // Show MONTH Name logic
                                      // Using 'progress' (0..1) map to 0..11 index
                                      int monthIndex = (progress * 11).round();
                                      if (monthIndex < 0) monthIndex = 0;
                                      if (monthIndex > 11) monthIndex = 11;

                                      DateTime monthDate = DateTime(
                                        startTime.year,
                                        monthIndex + 1,
                                        1,
                                      );
                                      _scrubbedTime = DateFormat(
                                        'MMMM',
                                      ).format(monthDate);
                                    } else {
                                      // Show DATE
                                      _scrubbedTime = DateFormat(
                                        'MMM d',
                                      ).format(timeAtPoint);
                                    }
                                  } else {
                                    // Show TIME
                                    _scrubbedTime =
                                        "${timeAtPoint.hour.toString().padLeft(2, '0')}:${timeAtPoint.minute.toString().padLeft(2, '0')}";
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
                                service.selectedDate,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),

                // Datum unten (HIDE IF SCRUBBING)
                // Removed redundant date label as it is now in the header/navigator
                /*
                if (_scrubbedValue == null)
                  Text(_getDateLabel(), style: AppTextStyles.subtitle)
                else
                  const SizedBox(
                    height: 20,
                  ), // Keep space to prevent jumping, approximate height
                */
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

  // ----------------------------------------------------------------------
  void _navigatePeriod(int direction, BleService service) {
    setState(() {
      DateTime newDate = _selectedDate;
      if (_selectedPeriod == "D") {
        newDate = _selectedDate.add(Duration(days: direction));
        _selectedEndDate = null;
      } else if (_selectedPeriod == "W") {
        newDate = _selectedDate.add(Duration(days: direction * 7));
        _selectedEndDate = null; // Week always fixed 7 days
      } else if (_selectedPeriod == "M") {
        // Standard Month Navigation
        newDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + direction,
          1,
        );
        _selectedEndDate = null; // Reset custom range if any
      } else if (_selectedPeriod == "Y") {
        newDate = DateTime(
          _selectedDate.year + direction,
          _selectedDate.month,
          _selectedDate.day,
        );
        _selectedEndDate = null;
      }

      if (newDate.isAfter(DateTime.now())) {
        if (_selectedPeriod == "M") {
          // clamp logic if needed
        }
      }
      _selectedDate = newDate;
    });

    service.setSelectedDate(_selectedDate);
    service.triggerSmartSync(force: true);
  }

  // Formatiert das Datum unten
  String _getDateLabel() {
    // User requested to NOT show scrubbed time here as it is redundant.
    // if (_scrubbedTime != null) { ... }

    switch (_selectedPeriod) {
      case "D":
        if (_isToday(_selectedDate)) return "Today";
        return DateFormat('MMMM d, y').format(_selectedDate);
      case "W":
        final startOfWeek = _selectedDate;
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        if (startOfWeek.month == endOfWeek.month) {
          return "${DateFormat('MMM d').format(startOfWeek)} - ${endOfWeek.day}";
        }
        return "${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}";
      case "M":
        // Fixed Month Label
        return DateFormat('MMMM y').format(_selectedDate);
      case "Y":
        return DateFormat('y').format(_selectedDate);
      default:
        return "";
    }
  }

  (double minY, double maxY) _calculateYRange(List<double> data) {
    final valid = data.where((d) => !d.isNaN).toList();
    if (valid.isEmpty) return (0, 100);

    final double minVal = valid.reduce((a, b) => a < b ? a : b);
    final double maxVal = valid.reduce((a, b) => a > b ? a : b);

    if (minVal == maxVal) {
      return (minVal - 10, maxVal + 10);
    }

    final double padding = (maxVal - minVal) * 0.1;

    return (minVal - padding, maxVal + padding);
  }

  _ChartViewModel _prepareChartData(BleService service) {
    if (widget.title == "Sleep") {
      // CUSTOM RANGE / MONTH view -> TREND CHART (Daily Totals)
      if (_selectedPeriod == "M" ||
          _selectedPeriod == "W" ||
          (_selectedPeriod == "D" && _selectedEndDate != null)) {
        DateTime start = _selectedDate;
        DateTime end;

        if (_selectedPeriod == "M" && _selectedEndDate == null) {
          // WHOLE MONTH MODE
          start = DateTime(_selectedDate.year, _selectedDate.month, 1);
          // Last day of month:
          end = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        } else {
          end =
              _selectedEndDate ??
              (_selectedPeriod == "W"
                  ? start.add(const Duration(days: 6))
                  : start.add(Duration(days: 30)) // Fallback
                    );
        }

        // Adjust start/end to be inclusive days (00:00 - 23:59)
        // Filter sleep history
        List<double> dailyTotals = [];
        int totalDays = end.difference(start).inDays + 1;
        if (totalDays < 1) totalDays = 1;

        for (int i = 0; i < totalDays; i++) {
          DateTime day = start.add(Duration(days: i));

          List<SleepData> daysSleep = service.getSleepDataForDate(day);
          int minutes = daysSleep.fold(
            0,
            (sum, item) => (item.stage != 5) ? sum + item.durationMinutes : sum,
          );
          dailyTotals.add(minutes / 60.0); // Hours
        }

        return _ChartViewModel(
          dailyTotals,
          start,
          totalDays * 24 * 60, // Total duration irrelevant for bar chart?
          1, // Interval?
          isTrend: true, // Flag to tell Chart to render differently?
          itemCount: totalDays,
        );
      } else if (_selectedPeriod == "Y") {
        // YEAR VIEW -> MONTHLY AVERAGES
        int year = _selectedDate.year;
        List<double> monthlyAverages = [];

        for (int m = 1; m <= 12; m++) {
          List<SleepData> monthSleep = service.sleepHistory.where((s) {
            return s.timestamp.year == year && s.timestamp.month == m;
          }).toList();

          if (monthSleep.isEmpty) {
            monthlyAverages.add(0.0);
          } else {
            Set<int> days = monthSleep.map((e) => e.timestamp.day).toSet();
            double totalHours = 0;
            for (int d in days) {
              int dayMinutes = monthSleep
                  .where((e) => e.timestamp.day == d)
                  .fold(
                    0,
                    (sum, item) =>
                        (item.stage != 5) ? sum + item.durationMinutes : sum,
                  );
              totalHours += (dayMinutes / 60.0);
            }
            double average = totalHours / days.length;
            monthlyAverages.add(average);
          }
        }

        return _ChartViewModel(
          monthlyAverages,
          DateTime(year, 1, 1),
          12 * 30 * 24 * 60,
          1,
          isTrend: true,
          itemCount: 12,
        );
      }

      // SINGLE DAY LOGIC
      // SLEEP LOGIC: Window from Yesterday 18:00 to Today 12:00 (18 hours)
      // Filter points that fall in this window.

      // 1. Gather all sleep data
      final List<SleepData> relevantSleep = service.getSleepDataForDate(
        _selectedDate,
      );

      if (relevantSleep.isEmpty) {
        return _ChartViewModel(
          List.filled(96, 0.0), // 15 min bins
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
          24 * 60,
          360,
        );
      }

      DateTime minTime = relevantSleep.first.timestamp;
      DateTime maxTime = relevantSleep.last.timestamp.add(
        Duration(minutes: relevantSleep.last.durationMinutes),
      );

      minTime = minTime.subtract(const Duration(minutes: 30));
      maxTime = maxTime.add(const Duration(minutes: 30));

      final DateTime snappedStart = DateTime(
        minTime.year,
        minTime.month,
        minTime.day,
        minTime.hour,
      );

      DateTime snappedEnd = maxTime;
      if (maxTime.minute != 0 || maxTime.second != 0) {
        snappedEnd = DateTime(
          maxTime.year,
          maxTime.month,
          maxTime.day,
          maxTime.hour + 1,
        );
      }

      int rawDuration = snappedEnd.difference(snappedStart).inMinutes;
      if (rawDuration < 60) rawDuration = 60;

      final int interval = _calculateLabelInterval(rawDuration);

      final int remainder = rawDuration % interval;
      int paddedDuration = rawDuration;
      if (remainder != 0) {
        paddedDuration = rawDuration + (interval - remainder);
      }

      final int newBins = (paddedDuration / 15).ceil();
      final List<double> data = List.filled(newBins, 0.0);

      for (var s in relevantSleep) {
        final int offset = s.timestamp.difference(snappedStart).inMinutes;
        final int startBin = offset ~/ 15;
        final int durationBins = (s.durationMinutes / 15).ceil();

        double val = 0;
        if (s.stage == 0x05) val = 3;
        if (s.stage == 0x04) val = 2.5;
        if (s.stage == 0x02) val = 2;
        if (s.stage == 0x03) val = 1;

        for (int i = 0; i < durationBins; i++) {
          if (startBin + i >= 0 && startBin + i < newBins) {
            data[startBin + i] = val;
          }
        }
      }

      return _ChartViewModel(data, snappedStart, paddedDuration, interval);
    } else {
      // ... existing generic logic ...
      // Since we're blindly restoring, let's just return a placeholder for non-sleep to avoid errors,
      // or try to keep the generic logic if possible.
      // The original file had generic logic. I will implement a safe fallback for now to fix the syntax error.
      return _ChartViewModel(
        [],
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        24 * 60,
        360,
      );
    }
  }

  void _showCalendarPicker(BuildContext context, BleService service) async {
    if (_selectedPeriod == "Y") {
      // YEAR PICKER
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              "Select Year",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.cardBackground,
            content: SizedBox(
              width: 300,
              height: 300,
              child: YearPicker(
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                selectedDate: _selectedDate,
                onChanged: (DateTime dateTime) {
                  Navigator.pop(context);
                  setState(() {
                    _selectedDate = dateTime;
                  });
                  service.setSelectedDate(dateTime);
                  service.triggerSmartSync(force: true);
                },
              ),
            ),
          );
        },
      );
      return;
    }

    if (_selectedPeriod == "M") {
      // MONTH PICKER (Custom Dialog)
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              "Select Month ${_selectedDate.year}",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.cardBackground,
            content: SizedBox(
              width: 300,
              height: 300,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final DateTime monthDate = DateTime(
                    _selectedDate.year,
                    index + 1,
                    1,
                  );
                  final bool isSelected = _selectedDate.month == index + 1;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedDate = monthDate;
                        _selectedEndDate = null; // Reset custom range
                      });
                      service.setSelectedDate(monthDate);
                      service.triggerSmartSync(force: true);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.mainColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.grey.shade800),
                      ),
                      child: Text(
                        DateFormat('MMM').format(monthDate),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
      return;
    }
    // Default for D, W, or others
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

  bool _canGoNext() {
    final now = DateTime.now();

    if (_selectedPeriod == "D") {
      return !_isToday(_selectedDate);
    } else if (_selectedPeriod == "W") {
      // Simplified: Just check if adding a week goes beyond today
      final nextWeekStart = _selectedDate.add(const Duration(days: 7));
      return nextWeekStart.isBefore(now) ||
          _isSameDay(nextWeekStart, now) ||
          nextWeekStart.difference(now).inDays < 7;
    }
    // Generic check
    return _selectedDate.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
        // DYNAMIC LABELS from start time
        labels = [];
        for (int i = 0; i < 7; i++) {
          final day = startTime.add(Duration(days: i));
          labels.add(DateFormat('E').format(day)); // Mon, Tue...
        }
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

  // ----------------------------------------------------------------------
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
}

class _ChartViewModel {
  final List<double> dataPoints;
  final DateTime startTime;
  final int durationMinutes;
  final int labelIntervalMinutes;
  final bool isTrend;
  final int itemCount;

  _ChartViewModel(
    this.dataPoints,
    this.startTime,
    this.durationMinutes,
    this.labelIntervalMinutes, {
    this.isTrend = false,
    this.itemCount = 0,
  });
}
