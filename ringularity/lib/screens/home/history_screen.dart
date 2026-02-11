import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/theme/text_styles.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/stat_cards/scrubbable_chart.dart';
import '../../widgets/stat_cards/time_period_selector.dart';
import '../../widgets/stat_cards/stat_summary_header.dart';

//TODO: DONE add real data from the ring
//TODO: maybe add possibility to start manual measurement (HR, HRV, Spo2, Stress)
//TODO: sleep might need a different view (sleep stages instead of just time)
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
        const cumulativeTypes = ["Steps", "Sleep", "Activity", "Run"];

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
          if (widget.title == "Run")
            baseValue = (service.distance / 1000).toStringAsFixed(2);
          if (widget.title == "Sleep")
            baseValue = service.totalSleepTimeFormatted;
        }

        // Use scrubbed value if active, otherwise base value
        String displayValue = _scrubbedValue ?? baseValue;

        final List<double> chartData = _generateRealDataPoints(service);
        final double dynamicMaxY = _calculateMaxY(chartData);

        // Calculate Limit X
        // If "Today", limit to current time fraction.
        // 96 bins = 24h.
        double? limitX;
        if (_selectedPeriod == "D" && _isToday(_selectedDate)) {
          final now = DateTime.now();
          final currentMinutes = now.hour * 60 + now.minute;
          limitX = currentMinutes / (24 * 60).toDouble();
          // Adding a small buffer?
          limitX = limitX.clamp(0.0, 1.0);
        }

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
                  value: displayValue,
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
                    maxY: dynamicMaxY,

                    // Die unterschiedlichen Daten
                    dataPoints: chartData,

                    chartLabels: _buildChartLabels(),
                    limitX: limitX,

                    // Customize appearance based on type
                    isCurved: widget.title != "Steps",

                    //uncomment if you want dots on steps
                    //showDots: widget.title == "Steps",
                    showDots: false,

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
                          } else if (widget.title == "Run") {
                            _scrubbedValue = (val / 1000).toStringAsFixed(2);
                          } else if (widget.title == "Sleep") {
                            if (val >= 2.5)
                              _scrubbedValue = "Awake";
                            else if (val >= 1.5)
                              _scrubbedValue = "Light";
                            else if (val >= 0.5)
                              _scrubbedValue = "Deep";
                            else
                              _scrubbedValue = "-";
                          } else {
                            _scrubbedValue = val.toStringAsFixed(1);
                          }

                          int totalMinutes = (progress * 24 * 60).round();
                          int hour = totalMinutes ~/ 60;
                          int minute = totalMinutes % 60;
                          final timeStr =
                              "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

                          _scrubbedTime = timeStr;
                        }
                      });
                    },
                  ),
                ),

                // Datum unten
                Text(_getDateLabel(), style: AppTextStyles.subtitle),
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
            dialogBackgroundColor: AppColors.background,
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

  double _calculateMaxY(List<double> data) {
    // Filter out NaNs and find max
    var validData = data.where((d) => !d.isNaN);
    if (validData.isEmpty) return 100;

    double maxVal = validData.reduce((curr, next) => curr > next ? curr : next);

    if (maxVal == 0) return 10;
    return maxVal * 1.2;
  }

  // --- Real Data Generation ---
  List<double> _generateRealDataPoints(BleService service) {
    if (_selectedPeriod != "D") {
      return [];
    }

    const int bins = 96;
    // Default to NaN for everything initially?
    // For Steps/Activity, usually 0 is better.
    // But for HR/SpO2, NaN is better.

    if (widget.title == "Steps" || widget.title == "Run") {
      List<double> data = List.filled(bins, 0.0);
      double currentTotal = 0;

      // First, populate the bins with raw interval data
      for (var p in service.stepsHistory) {
        int idx = p.x.toInt();
        if (idx >= 0 && idx < bins) {
          data[idx] = p.y.toDouble();
        }
      }

      // Then, accumulate
      for (int i = 0; i < bins; i++) {
        currentTotal += data[i];
        data[i] = currentTotal;
      }
      return data;
    }

    if (widget.title == "HR") {
      return _binTimePoints(service.hrHistory, bins, interpolate: true);
    }
    if (widget.title == "Oxygen") {
      return _binTimePoints(service.spo2History, bins, interpolate: true);
    }
    if (widget.title == "Stress") {
      return _binTimePoints(service.stressHistory, bins, interpolate: true);
    }

    if (widget.title == "Sleep") {
      // Sleep usually covers a span, so 0 (awake/none) vs NaN (no data)
      // Let's keep 0 for "No Sleep Processed" or explicit stages.
      // But actually, if no sleep data, maybe NaN is fine?
      // For now, let's init with 0 as it was.
      List<double> data = List.filled(bins, 0.0);
      for (var s in service.sleepHistory) {
        int startMin = s.timestamp.hour * 60 + s.timestamp.minute;
        int startIdx = startMin ~/ 15;
        int durationIdx = (s.durationMinutes / 15).ceil();

        double val = 0;
        if (s.stage == 0x05) val = 3; // Awake
        if (s.stage == 0x02) val = 2; // Light
        if (s.stage == 0x03) val = 1; // Deep

        for (int i = 0; i < durationIdx; i++) {
          if (startIdx + i < bins) {
            data[startIdx + i] = val;
          }
        }
      }
      return data;
    }

    return [];
  }

  List<double> _binTimePoints(
    List<Point> points,
    int bins, {
    bool interpolate = false,
  }) {
    // Initialize with 0 for summing, but track counts to decide NaN
    List<double> sumData = List.filled(bins, 0.0);
    List<int> counts = List.filled(bins, 0);

    for (var p in points) {
      int minute = p.x.toInt();
      int idx = minute ~/ 15;
      if (idx >= 0 && idx < bins) {
        sumData[idx] += p.y;
        counts[idx]++;
      }
    }

    // Result list
    List<double> result = List.generate(bins, (i) {
      if (counts[i] > 0) {
        return sumData[i] / counts[i];
      } else {
        return double.nan; // Return NaN for empty bins
      }
    });

    if (interpolate) {
      int firstValid = result.indexWhere((d) => !d.isNaN);
      if (firstValid == -1) return result; // No data at all

      int lastValid = result.lastIndexWhere((d) => !d.isNaN);

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
            double startVal = result[i - 1]; // Guaranteed valid by loop logic
            double endVal = result[nextValid];
            int gapSize = nextValid - (i - 1);

            // Fill the gap
            for (int k = 1; k < gapSize; k++) {
              double fraction = k / gapSize;
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

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  Widget _buildChartLabels() {
    List<String> labels = [];

    switch (_selectedPeriod) {
      case "D":
        labels = ["06:00", "09:00", "12:00", "15:00", "18:00", "21:00"];
        break;
      case "W":
        labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
        break;
      case "M":
        int days = _getDaysInMonth(_selectedDate);
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
