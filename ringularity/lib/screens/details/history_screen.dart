import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/theme/text_styles.dart';
import 'package:ringularity/utils/history_data_processor.dart';
import 'package:ringularity/utils/sleep_score_calculator.dart';

import '../../services/health/vitals_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/stat_cards/metric_info_sheet.dart';
import '../../widgets/stat_cards/scrubbable_chart.dart';
import '../../widgets/stat_cards/sleep_metrics_summary.dart';
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

    if (widget.title == "Sleep") {
      _selectedPeriod = "D";
    }
  }

  bool _getIsCurved(String title) {
    if (title == "Steps" || title == "Stress") return false;
    return true;
  }

  Color _getBarColor(double value) {
    if (value < 25) return Colors.blue;
    if (value < 50) return Colors.green;
    if (value < 75) return Colors.orange;
    return Colors.red;
  }

  bool _shouldUseBars(String title, String period) {
    if (title == "Sleep" || title == "Stress") return true;
    if (title == "Steps" && period != "D") return true;
    if (period == "Y" || period == "M") return true;
    return false;
  }

  String _getBaseValue(BleService service) {
    if (_selectedPeriod != "D") return widget.currentValue;

    switch (widget.title) {
      case "Steps":
        return service.steps.toString();
      case "HR":
        return service.heartRate.toString();
      case "Stress":
        return service.stress.toString();
      case "Oxygen":
        return "${service.spo2}";
      case "Distance":
        return (service.distance / 1000).toStringAsFixed(2);
      case "Sleep":
        return service.totalSleepTimeFormatted;
      default:
        return widget.currentValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storageService = Provider.of<VitalsStorageService>(context);

    return Consumer<BleService>(
      builder: (context, service, child) {
        const cumulativeTypes = ["Steps", "Sleep", "Activity", "Distance"];

        final bool showTotal =
            _selectedPeriod == "D" && cumulativeTypes.contains(widget.title);
        final String displayValue = _scrubbedValue ?? _getBaseValue(service);

        final processor = HistoryDataProcessor(
          service: service,
          storage: storageService,
        );

        final chartViewModel = processor.prepareChartData(
          title: widget.title,
          selectedPeriod: _selectedPeriod,
          selectedDate: _selectedDate,
        );

        final List<Point> chartPoints = chartViewModel.points;
        final (dynamicMinY, dynamicMaxY) = processor.calculateYRange(
          chartPoints,
          widget.title,
        );
        final DateTime startTime = chartViewModel.startTime;

        SleepMetrics? sleepMetrics;
        if (widget.title == "Sleep" && _selectedPeriod == "D") {
          final sleepData = service.getSleepDataForDate(_selectedDate);
          if (sleepData.isNotEmpty) {
            sleepMetrics = SleepScoreCalculator.calculate(sleepData);
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

                if (widget.title != "Sleep")
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

                if (widget.title == "Sleep") const SizedBox(height: 10),
                if (widget.title != "Sleep") const SizedBox(height: 20),

                StatSummaryHeader(
                  isTotal: showTotal,
                  value: displayValue,
                  subValue: _scrubbedTime,
                  unit: widget.unit,
                  valueColor: _scrubbedValue != null
                      ? Colors.white
                      : AppColors.mainColor,
                  onCalendarTap: () => _showCalendarPicker(context, service),
                ),
                const SizedBox(height: 5),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (sleepMetrics != null)
                          SleepMetricsSummary(sleepMetrics: sleepMetrics),

                        SizedBox(
                          height: 350,
                          child: chartPoints.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No data for this period",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ScrubbableChart(
                                  minY: dynamicMinY,
                                  maxY: dynamicMaxY,
                                  minX: chartViewModel.minX,
                                  maxX: chartViewModel.maxX,
                                  dataPoints: chartPoints,
                                  chartLabels: chartViewModel.labels,
                                  limitX: 1.0,
                                  averageY: chartViewModel.averageY,
                                  highlightScrubbedBar: true,
                                  isCurved: _getIsCurved(widget.title),
                                  showDots: false,
                                  useBars: _shouldUseBars(
                                    widget.title,
                                    _selectedPeriod,
                                  ),
                                  isTrend: chartViewModel.isTrend,
                                  barColorBuilder: (val) {
                                    if (widget.title == "Sleep") {
                                      if (val >= 2.8)
                                        return AppColors.awake; // Awake
                                      if (val >= 2.4)
                                        return AppColors.remSleep; // REM
                                      if (val >= 1.8)
                                        return AppColors.lightSleep; // Light
                                      return AppColors.deepSleep; // Deep
                                    }
                                    if (widget.title == "Stress" ||
                                        widget.title == "SpO2") {
                                      return _getBarColor(val);
                                    }
                                    return AppColors.mainColor.withValues(
                                      alpha: 0.8,
                                    );
                                  },
                                  onValueSelected: (val, x, progress) {
                                    setState(() {
                                      if (val == null || x == null) {
                                        _scrubbedValue = null;
                                        _scrubbedTime = null;
                                      } else {
                                        _updateScrubbedValues(
                                          val,
                                          x,
                                          chartViewModel.isTrend,
                                          startTime,
                                        );
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
                        ],

                        if ((widget.title == "Sleep" ||
                                widget.title == "Stress") &&
                            !chartViewModel.isTrend) ...[
                          const SizedBox(height: 20),
                          Center(
                            child: TextButton.icon(
                              onPressed: () =>
                                  _showDynamicInfoSheet(context, widget.title),
                              icon: const Icon(
                                Icons.info_outline,
                                color: Colors.grey,
                                size: 20,
                              ),
                              label: Text(
                                "About ${widget.title} Metrics",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
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
                    color: Colors.grey,
                    fontWeight: FontWeight.normal,
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

  void _updateScrubbedValues(
    double val,
    double x,
    bool isTrend,
    DateTime startTime,
  ) {
    if (widget.title == "Sleep") {
      if (isTrend) {
        final int hours = val.floor();
        final int minutes = ((val - hours) * 60).round();
        _scrubbedValue = _selectedPeriod == "Y"
            ? "Avg ${hours}h ${minutes}m"
            : "${hours}h ${minutes}m";
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
      final timeAtPoint = startTime.add(Duration(minutes: x.round()));
      _scrubbedTime = DateFormat('HH:mm').format(timeAtPoint);
    } else if (_selectedPeriod == "W") {
      final dateAtPoint = startTime.add(Duration(days: x.round()));
      _scrubbedTime = DateFormat('EEEE').format(dateAtPoint);
    } else if (_selectedPeriod == "M") {
      final dateAtPoint = startTime.add(Duration(days: x.round()));
      _scrubbedTime = DateFormat('MMM d').format(dateAtPoint);
    } else if (_selectedPeriod == "Y") {
      final dateAtPoint = DateTime(startTime.year, x.round() + 1);
      _scrubbedTime = DateFormat('MMMM').format(dateAtPoint);
    }
  }

  String _formatScrubbedValue(double val) {
    if (["HR", "Stress", "Steps", "HRV", "Oxygen"].contains(widget.title)) {
      return val.round().toString();
    } else if (widget.title == "Distance") {
      return _selectedPeriod == "D"
          ? (val / 1000).toStringAsFixed(2)
          : val.toStringAsFixed(2);
    } else {
      return val.toStringAsFixed(1);
    }
  }

  String _getDateLabel() {
    if (_selectedPeriod == "D") {
      if (_isToday(_selectedDate)) return "Today";
      return DateFormat('EEEE, MMM d').format(_selectedDate);
    } else if (_selectedPeriod == "W") {
      final start = _selectedDate.subtract(
        Duration(days: _selectedDate.weekday - 1),
      );
      final end = start.add(const Duration(days: 6));
      return "${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)}";
    } else if (_selectedPeriod == "M") {
      return DateFormat('MMMM yyyy').format(_selectedDate);
    } else if (_selectedPeriod == "Y") {
      return DateFormat('yyyy').format(_selectedDate);
    }
    return "";
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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

  void _showDynamicInfoSheet(BuildContext context, String metricType) {
    if (metricType == "Sleep") {
      showMetricInfoSheet(
        context,
        sheetTitle: "About Sleep Metrics",
        sections: [
          InfoSectionData(
            title: "Sleep Stages",
            items: [
              InfoItemData(
                title: "Deep Sleep",
                description:
                    "The physically restorative phase where your body heals and recovers.",
                color: AppColors.deepSleep,
              ),
              InfoItemData(
                title: "Light Sleep",
                description:
                    "The transition phase between wakefulness and deeper sleep stages.",
                color: AppColors.lightSleep,
              ),
              InfoItemData(
                title: "REM",
                description:
                    "The dreaming phase, crucial for mental restoration and memory consolidation.",
                color: AppColors.remSleep,
              ),
              InfoItemData(
                title: "Awake",
                description:
                    "Brief moments of wakefulness or disturbances during the night.",
                color: AppColors.awake,
              ),
            ],
          ),
          InfoSectionData(
            title: "Sleep Metrics",
            items: [
              InfoItemData(
                title: "Sleep Score",
                description:
                    "An overall assessment of your rest, combining how long and how well you slept.",
                icon: Icons.speed,
              ),
              InfoItemData(
                title: "Efficiency",
                description:
                    "The percentage of time you were actually asleep while in bed.",
                icon: Icons.rocket_launch,
              ),
              InfoItemData(
                title: "Quality",
                description:
                    "A general rating of your sleep's restorative value, influenced by your sleep stages and interruptions.",
                icon: Icons.shield_moon,
              ),
            ],
          ),
        ],
      );
    } else if (metricType == "Stress") {
      showMetricInfoSheet(
        context,
        sheetTitle: "About Stress Metrics",
        sections: [
          InfoSectionData(
            title: "Stress Zones (0-100)",
            items: [
              InfoItemData(
                title: "Rest & Recovery (0-25)",
                description:
                    "Parasympathetic dominance. Your body is resting, digesting, and restoring energy. Usually occurs during sleep or deep relaxation.",
                color: Colors.blue,
              ),
              InfoItemData(
                title: "Low Stress (26-50)",
                description:
                    "Mild physiological arousal. This is your normal, healthy state during light focus, routine tasks, and daily waking activities.",
                color: Colors.green,
              ),
              InfoItemData(
                title: "Medium Stress (51-75)",
                description:
                    "Elevated physical or mental demand. The sympathetic nervous system is active. Typical during busy work or challenging tasks.",
                color: Colors.orange,
              ),
              InfoItemData(
                title: "High Stress (76-100)",
                description:
                    "Strong 'Fight or Flight' response. Your body is under significant strain, typical during intense pressure, illness, or heavy physical exertion.",
                color: Colors.red,
              ),
            ],
          ),
          InfoSectionData(
            title: "The Science Behind It",
            items: [
              InfoItemData(
                title: "Heart Rate Variability (HRV)",
                description:
                    "Your stress score is calculated by analyzing your Autonomic Nervous System via HRV. A higher variation between heartbeats means you are relaxed (low score), while a very steady, rigid heartbeat indicates stress (high score).",
                icon: Icons.monitor_heart,
              ),
            ],
          ),
        ],
      );
    }
  }
}
