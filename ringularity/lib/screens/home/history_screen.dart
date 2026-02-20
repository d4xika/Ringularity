import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringularity/services/ble/ble_service.dart';
import 'package:ringularity/theme/text_styles.dart';
import 'package:ringularity/utils/history_data_processor.dart';
import 'package:ringularity/utils/sleep_score_calculator.dart';

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

    // Helper to check curve
    bool getIsCurved(String title) {
      if (title == "Steps") return false;
      if (title == "Stress") return true;
      if (title == "HR") return true;
      return true;
    }

    // Helper for Bar Color
    Color getBarColor(double value) {
      if (value < 30) return Colors.green;
      if (value < 60) return Colors.yellow;
      return Colors.red;
    }

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
          if (widget.title == "Distance") {
            baseValue = (service.distance / 1000).toStringAsFixed(2);
          }
          if (widget.title == "Sleep") {
            baseValue = service.totalSleepTimeFormatted;
          }
        }

        final String displayValue = _scrubbedValue ?? baseValue;

        // Use Processor
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

        final double limitX = 1.0;

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
                  subValue: _scrubbedTime, // Pass the time here
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
                                  limitX: limitX,
                                  averageY: chartViewModel.averageY,
                                  highlightScrubbedBar: true,
                                  isCurved: getIsCurved(widget.title),
                                  showDots: false,
                                  useBars:
                                      widget.title == "Sleep" ||
                                      (widget.title == "Steps" &&
                                          _selectedPeriod != "D") ||
                                      _selectedPeriod == "Y" ||
                                      _selectedPeriod == "M",
                                  barColorBuilder: (val) {
                                    if (widget.title == "Sleep") {
                                      if (val >= 2.8) {
                                        return const Color(0xFFFF9B9B); // Awake
                                      }
                                      if (val >= 2.4) {
                                        return const Color(0xFF9D4BF5); // REM
                                      }
                                      if (val >= 1.8) {
                                        return const Color(0xFF4B98F5); // Light
                                      }
                                      return const Color(0xFF1E4578); // Deep
                                    }
                                    if (widget.title == "Stress" ||
                                        widget.title == "SpO2") {
                                      return getBarColor(val);
                                    }
                                    return AppColors.mainColor.withOpacity(0.8);
                                  },
                                  onValueSelected: (val, x, progress) {
                                    setState(() {
                                      if (val == null || x == null) {
                                        _scrubbedValue = null;
                                        _scrubbedTime = null;
                                      } else {
                                        if (widget.title == "Sleep") {
                                          if (chartViewModel.isTrend) {
                                            final int hours = val.floor();
                                            final int minutes =
                                                ((val - hours) * 60).round();
                                            if (_selectedPeriod == "Y") {
                                              _scrubbedValue =
                                                  "Avg ${hours}h ${minutes}m";
                                            } else {
                                              _scrubbedValue =
                                                  "${hours}h ${minutes}m";
                                            }
                                          } else {
                                            if (val >= 2.8) {
                                              _scrubbedValue = "Awake";
                                            } else if (val >= 2.4) {
                                              _scrubbedValue = "REM";
                                            } else if (val >= 1.8) {
                                              _scrubbedValue = "Light";
                                            } else if (val >= 0.5) {
                                              _scrubbedValue = "Deep";
                                            } else {
                                              _scrubbedValue = "-";
                                            }
                                          }
                                        } else {
                                          _scrubbedValue = _formatScrubbedValue(
                                            val,
                                          );
                                        }

                                        if (_selectedPeriod == "D") {
                                          final int scrubMinutes = x.round();
                                          final DateTime timeAtPoint = startTime
                                              .add(
                                                Duration(minutes: scrubMinutes),
                                              );
                                          _scrubbedTime = DateFormat(
                                            'HH:mm',
                                          ).format(timeAtPoint);
                                        } else if (_selectedPeriod == "W") {
                                          final int dayOffset = x.round();
                                          final DateTime dateAtPoint = startTime
                                              .add(Duration(days: dayOffset));
                                          _scrubbedTime = DateFormat(
                                            'EEEE',
                                          ).format(dateAtPoint);
                                        } else if (_selectedPeriod == "M") {
                                          final int dayOffset = x.round();
                                          final DateTime dateAtPoint = startTime
                                              .add(Duration(days: dayOffset));
                                          _scrubbedTime = DateFormat(
                                            'MMM d',
                                          ).format(dateAtPoint);
                                        } else if (_selectedPeriod == "Y") {
                                          final int monthOffset = x.round();
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
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => _showSleepInfoDialog(context),
                              icon: const Icon(
                                Icons.info_outline,
                                color: Colors.grey,
                                size: 20,
                              ),
                              label: const Text(
                                "About Sleep Metrics",
                                style: TextStyle(
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
        widget.title == "Steps" ||
        widget.title == "HRV") {
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

  void _showSleepInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          "Sleep Stages",
          style: TextStyle(color: Colors.white),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Deep Sleep: Restorative phase.",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              "Light Sleep: Transition phase.",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text("REM: Dreaming phase.", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text("Awake: Disturbances.", style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              "Close",
              style: TextStyle(color: AppColors.mainColor),
            ),
          ),
        ],
      ),
    );
  }
}
