import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/models/sleep_data.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/theme/text_styles.dart';

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
                  // SHOW SCRUBBED VALUE AT TOP
                  value: _scrubbedValue != null && _scrubbedTime != null
                      ? "$_scrubbedValue\n$_scrubbedTime" // Show Value AND Time
                      : displayValue,
                  unit: widget.unit,
                  valueColor: _scrubbedValue != null
                      ? Colors.white
                      : AppColors.mainColor, // Highlight if scrubbing
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

                    useBars: widget.title == "Sleep",
                    barColorBuilder: widget.title == "Sleep"
                        ? (val) {
                            if (val >= 2.8)
                              return const Color(0xFFFF9B9B); // Awake
                            if (val >= 2.4)
                              return const Color(0xFF9D4BF5); // REM
                            if (val >= 1.8)
                              return const Color(0xFF4B98F5); // Light
                            return const Color(0xFF1E4578); // Deep
                          }
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
                            _scrubbedValue = (val / 1000).toStringAsFixed(2);
                          } else if (widget.title == "Sleep") {
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
                          } else {
                            _scrubbedValue = val.toStringAsFixed(1);
                          }

                          // Calculate Time based on Dynamic Start
                          final int scrubMinutes =
                              (progress * dataDurationMinutes).round();
                          final DateTime timeAtPoint = startTime.add(
                            Duration(minutes: scrubMinutes),
                          );

                          final timeStr =
                              "${timeAtPoint.hour.toString().padLeft(2, '0')}:${timeAtPoint.minute.toString().padLeft(2, '0')}";

                          _scrubbedTime = timeStr;
                        }
                      });
                    },
                  ),
                ),

                // Datum unten (HIDE IF SCRUBBING)
                if (_scrubbedValue == null)
                  Text(_getDateLabel(), style: AppTextStyles.subtitle)
                else
                  const SizedBox(
                    height: 20,
                  ), // Keep space to prevent jumping, approximate height
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
    if (valid.isEmpty) return (0, 100);

    final double minVal = valid.reduce((a, b) => a < b ? a : b);
    final double maxVal = valid.reduce((a, b) => a > b ? a : b);

    if (minVal == maxVal) {
      return (minVal - 10, maxVal + 10);
    }

    final padding = (maxVal - minVal) * 0.1;

    return (minVal - padding, maxVal + padding);
  }

  // --- Real Data Generation (Dynamic Scaling) ---
  _ChartViewModel _prepareChartData(BleService service) {
    if (_selectedPeriod != "D") {
      // Default / Placeholder for non-daily
      return _ChartViewModel(
        [],
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        24 * 60,
        360, // Default 6h
      );
    }

    if (widget.title == "Sleep") {
      // SLEEP LOGIC: Window from Yesterday 18:00 to Today 12:00 (18 hours)
      // Filter points that fall in this window.

      // 1. Gather all sleep data
      // BleDataManager now allows yesterday's data.
      final List<SleepData> relevantSleep =
          service.sleepHistory; // Already sorted?

      if (relevantSleep.isEmpty) {
        // Return empty 24h
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

      // Pad start/end by 30 mins
      minTime = minTime.subtract(const Duration(minutes: 30));
      maxTime = maxTime.add(const Duration(minutes: 30));

      // SNAP SLEEP TO HOURS
      // Current minTime/maxTime are exact timestamps from sleep data +/- 30 mins

      // Snap Start DOWN to Hour
      final DateTime snappedStart = DateTime(
        minTime.year,
        minTime.month,
        minTime.day,
        minTime.hour,
      );

      // Snap End UP to Hour
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

      // Pad Duration
      final int remainder = rawDuration % interval;
      int paddedDuration = rawDuration;
      if (remainder != 0) {
        paddedDuration = rawDuration + (interval - remainder);
      }

      // Re-map sleep data to new snapped grid
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
      // --- UPDATED GENERIC TRIM LOGIC WITH SNAP ---

      // 1. Get Daily Data (00:00 - 24:00) 96 bins
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

        // Mask Future if Today
        if (_isToday(_selectedDate)) {
          final now = DateTime.now();
          final int currentBin = (now.hour * 60 + now.minute) ~/ 15;
          for (int i = currentBin + 1; i < 96; i++) {
            fullDayData[i] = double.nan;
          }
        }
      }

      // 2. Find Valid Range
      int firstValid = -1;
      int lastValid = -1;

      for (int i = 0; i < fullDayData.length; i++) {
        final bool isValid = !fullDayData[i].isNaN;

        if (isValid) {
          if (firstValid == -1) firstValid = i;
          lastValid = i;
        }
      }

      // FORCE 00:00 START FOR STEPS/RUN
      if (widget.title == "Steps" || widget.title == "Distance") {
        firstValid = 0; // Always start at 00:00
        if (lastValid == -1) {
          lastValid = 95; // Should not happen with 0.0 init, but safe fallback
        }
      }

      // 3. Defaults
      final DateTime dayStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      if (firstValid == -1) {
        return _ChartViewModel(
          List.filled(96, double.nan),
          dayStart,
          24 * 60,
          360, // 6h interval default
        );
      }

      // 4. Determine Actual Times from Bins
      final DateTime actualStart = dayStart.add(
        Duration(minutes: firstValid * 15),
      );
      final DateTime actualEnd = dayStart.add(
        Duration(minutes: (lastValid + 1) * 15),
      );

      // 5. Snap Start DOWN to nearest Hour
      final DateTime snappedStart = DateTime(
        actualStart.year,
        actualStart.month,
        actualStart.day,
        actualStart.hour,
      );

      // 6. Snap End UP to nearest Hour
      DateTime snappedEnd = actualEnd;
      if (actualEnd.minute != 0 || actualEnd.second != 0) {
        snappedEnd = DateTime(
          actualEnd.year,
          actualEnd.month,
          actualEnd.day,
          actualEnd.hour + 1,
        );
      }

      // 7. Calculate Raw Duration & Interval
      int rawDuration = snappedEnd.difference(snappedStart).inMinutes;
      // Enforce Min Duration of 1h
      if (rawDuration < 60) rawDuration = 60;

      final int interval = _calculateLabelInterval(rawDuration);

      // 8. Pad Duration to be Multiple of Interval
      // e.g. duration 130m, interval 60m => target 180m (3h)
      final int remainder = rawDuration % interval;
      int paddedDuration = rawDuration;
      if (remainder != 0) {
        paddedDuration = rawDuration + (interval - remainder);
      }

      // Update EndTime based on padded duration
      snappedEnd = snappedStart.add(Duration(minutes: paddedDuration));

      // 9. Re-Fill Data for snappy window
      // We need to map bins from fullDayData (0..95) to our new window.
      // New window starts at snappedStart.
      // 1 bin = 15 min.
      final int newBins = (paddedDuration / 15).ceil();
      final List<double> finalData = List.filled(newBins, double.nan);

      // Map old bins to new bins
      final int offsetMinutes = snappedStart.difference(dayStart).inMinutes;
      final int offsetBins = offsetMinutes ~/ 15;

      for (int i = 0; i < newBins; i++) {
        final int originalBinIndex = offsetBins + i;
        if (originalBinIndex >= 0 && originalBinIndex < 96) {
          finalData[i] = fullDayData[originalBinIndex];
        } else {
          // Out of day bounds (e.g. tomorrow morning if padded?)
          // Keep default (NaN or 0)
        }
      }

      return _ChartViewModel(finalData, snappedStart, paddedDuration, interval);
    }
  }

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

  // Formatiert das Datum unten
  String _getDateLabel() {
    if (_scrubbedTime != null) {
      if (_isToday(_selectedDate)) {
        return "Today at $_scrubbedTime";
      } else {
        return "${DateFormat('MMMM d, y').format(_selectedDate)} at $_scrubbedTime";
      }
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
